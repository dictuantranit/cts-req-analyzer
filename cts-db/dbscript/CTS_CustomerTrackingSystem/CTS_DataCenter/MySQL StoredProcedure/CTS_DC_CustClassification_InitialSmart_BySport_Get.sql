/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_InitialSmart_BySport_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_InitialSmart_BySport_Get`(
        IN 	ip_BatchSize            SMALLINT
    ,   OUT op_NextScannedDateTime  DATETIME(3)
	,   OUT op_NextScannedCustID    BIGINT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250908@Logan.Nguyen
		Task:	 	Get cust to classify 2900/2901
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250908@Logan.Nguyen:    Created [Redmine ID: #237405]
                - 20250922@Logan.Nguyen:    Adjust Performance Calculation Logic for Initial Smart - CC2700 - Initial Smart (Losing) - CC2701 [Redmine ID: #239118]
		Example:
			CALL CTS_DataCenter.CTS_DC_CustClassification_InitialSmart_BySport_Get(@BatchSize,@NextScannedDateTime,@NextScannedCustID);
            SELECT @NextScannedDateTime,@NextScannedCustID
	*/
    
	DECLARE lv_LastScannedDate      DATETIME(3);
	DECLARE lv_LastScannedCustID    BIGINT UNSIGNED;
    DECLARE lv_SecondBatchSize      SMALLINT;
    DECLARE lv_TotalRow             SMALLINT;
	
    SELECT sys.ParameterValue
    INTO lv_LastScannedCustID
    FROM CTS_DataCenter.SystemParameter AS sys
    WHERE sys.ParameterID = 196;

    SELECT sys.ParameterValue
    INTO lv_LastScannedDate
    FROM CTS_DataCenter.SystemParameter AS sys
    WHERE sys.ParameterID = 197;

    DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
    CREATE TEMPORARY TABLE Temp_Customer(
			CustID				BIGINT UNSIGNED
        ,   SportType           INT
		,	Probability		    DECIMAL(8,4)
        ,   SourceCreatedDate 	DATETIME(3)
        ,   InsertedTime        DATETIME(3)
        ,   PRIMARY KEY (CustID, SportType)
    );
    
    INSERT INTO Temp_Customer(CustID, SportType, Probability, SourceCreatedDate, InsertedTime)
    WITH cte_Cus AS (
        SELECT	cs.CustID
            ,   cs.SportType
		    , 	cs.Probability
            ,	cs.SourceCreatedDate
	    	,	cs.InsertedTime
        FROM CTS_DataCenter.Customer_InitialSmart_BySport AS cs
        INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON cs.SportType = ccs.SportType
        WHERE cs.InsertedTime = lv_LastScannedDate
		    AND cs.CustID > lv_LastScannedCustID
    	ORDER BY cs.InsertedTime ASC, cs.CustID ASC
	    LIMIT ip_BatchSize)
        SELECT DISTINCT CustID, SportType, Probability, SourceCreatedDate, InsertedTime
        FROM cte_Cus;
    
    SET lv_TotalRow = (SELECT COUNT(1) FROM Temp_Customer);
    
    IF lv_TotalRow < ip_BatchSize THEN   
        SET lv_SecondBatchSize = ip_BatchSize - lv_TotalRow;
        
        INSERT INTO Temp_Customer(CustID, SportType, Probability, SourceCreatedDate, InsertedTime)
        WITH cte_Cus_BatchSize AS ( 
		    SELECT	cs.CustID
                ,   cs.SportType
                , 	cs.Probability
                ,	cs.SourceCreatedDate
                ,	cs.InsertedTime
		    FROM CTS_DataCenter.Customer_InitialSmart_BySport AS cs
            INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON cs.SportType = ccs.SportType
		    WHERE cs.InsertedTime > lv_LastScannedDate
		    ORDER BY cs.InsertedTime ASC, cs.CustID ASC
		    LIMIT lv_SecondBatchSize)
	    SELECT DISTINCT CustID, SportType, Probability, SourceCreatedDate, InsertedTime
        FROM cte_Cus_BatchSize;
	
    END IF;
    
    SET op_NextScannedDateTime = IFNULL((SELECT MAX(InsertedTime) FROM Temp_Customer), lv_LastScannedDate);
    SET op_NextScannedCustID = IFNULL((SELECT MAX(CustID) FROM Temp_Customer WHERE InsertedTime = op_NextScannedDateTime), lv_LastScannedCustID);

    SELECT	tmp.CustID
        ,   tmp.SportType
        ,	cus.CTSCustID
        ,	cus.SubscriberID
        ,	cus.RoleID
        ,   cus.IsLicensee
        ,	ccs.CategoryID              AS CategoryID
        ,	ccs.CategoryGroupID         AS CategoryGroupID
        ,   tmp.Probability
        ,   tmp.SourceCreatedDate       AS DetectedDate
	FROM Temp_Customer AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmp.CustID = cus.CustID AND cus.CustSubID = 0 AND cus.IsInternal = 0
		INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.SportType = tmp.SportType
        INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON ccs.CategoryID = cate.CategoryID
    WHERE cate.IsPAProbation = 0;

END$$	
DELIMITER ;
