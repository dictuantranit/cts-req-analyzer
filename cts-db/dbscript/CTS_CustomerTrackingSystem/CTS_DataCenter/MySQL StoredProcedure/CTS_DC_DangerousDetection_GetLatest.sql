/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_DangerousDetection_GetLatest`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_DangerousDetection_GetLatest`(
	ip_IsLicensee TINYINT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240315@Casey.Huynh
		Task:		Get Latest Cust Dangerous Score Info to push to CTS 
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20240321@Casey.Huynh: 	Created [Redmine ID: #201538]
			- 20240521@Victoria.Le: 	Danger Score - Deposit [Redmine ID: #205166]
            - 20240620@Jonas.Huynh: 	Renovate CC [RedmineID: #205317]
		
        Example:
			CALL CTS_DataCenter.CTS_DC_DangerousDetection_GetLatest(@ip_IsLicensee:=0);
	*/
    DECLARE	CONST_CATEID_EARLYWARNING			INT;
    DECLARE	CONST_CATEGROUPID_EARLYWARNING		INT;
        
	DECLARE lv_LastScannedDate DATETIME(3);	
	DECLARE lv_LastCustID BIGINT UNSIGNED;
    DECLARE lv_BatchSize SMALLINT;
    DECLARE lv_TotalRow SMALLINT;
	  
    SET CONST_CATEID_EARLYWARNING	 			= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_EARLYWARNING');
    SET CONST_CATEGROUPID_EARLYWARNING	 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_EARLYWARNING');
    
	IF (ip_IsLicensee = 0) THEN
		SELECT sys.ParameterValue
		INTO lv_LastScannedDate
		FROM CTS_DataCenter.SystemParameter AS sys
		WHERE sys.ParameterID = 153;
		
		SELECT sys.ParameterValue
		INTO lv_LastCustID
		FROM CTS_DataCenter.SystemParameter AS sys
		WHERE sys.ParameterID = 154;
		
		SELECT sys.ParameterValue
		INTO lv_BatchSize
		FROM CTS_DataCenter.SystemParameter AS sys
		WHERE sys.ParameterID = 155;
	END IF;
	
    IF (ip_IsLicensee = 1) THEN
		SELECT sys.ParameterValue
		INTO lv_LastScannedDate
		FROM CTS_DataCenter.SystemParameter AS sys
		WHERE sys.ParameterID = 156;
		
		SELECT sys.ParameterValue
		INTO lv_LastCustID
		FROM CTS_DataCenter.SystemParameter AS sys
		WHERE sys.ParameterID = 157;
		
		SELECT sys.ParameterValue
		INTO lv_BatchSize
		FROM CTS_DataCenter.SystemParameter AS sys
		WHERE sys.ParameterID = 158;
	END IF;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			CustID				BIGINT UNSIGNED PRIMARY KEY
		,	ClassifiedScore		DECIMAL(8,4)
		,	ClassifiedDate		DATETIME(3)
        ,	LastModifiedDate	DATETIME(3)
    );
    
    INSERT INTO Temp_Cust(CustID, ClassifiedScore, ClassifiedDate, LastModifiedDate)
    SELECT	cd.CustID
		, 	cd.ClassifiedScore
        ,	cd.ClassifiedDate
		,	cd.LastModifiedDate
    FROM CTS_DataCenter.Customer_DangerousScore AS cd
    WHERE cd.IsLicensee = ip_IsLicensee
		AND cd.LastModifiedDate = lv_LastScannedDate
		AND cd.CustID > lv_LastCustID
        AND cd.ClassifiedScore IS NOT NULL
	ORDER BY cd.LastModifiedDate ASC, cd.CustID ASC
	LIMIT lv_BatchSize;
    
    SET lv_TotalRow = (SELECT COUNT(1) FROM Temp_Cust) ;
    
    IF lv_TotalRow < lv_BatchSize THEN    
        INSERT INTO Temp_Cust(CustID, ClassifiedScore, ClassifiedDate, LastModifiedDate)
		SELECT	cd.CustID
			, 	cd.ClassifiedScore
			,	cd.ClassifiedDate
            ,	cd.LastModifiedDate
		FROM CTS_DataCenter.Customer_DangerousScore AS cd
		WHERE cd.IsLicensee = ip_IsLicensee
			AND cd.LastModifiedDate > lv_LastScannedDate
            AND cd.ClassifiedScore IS NOT NULL
		ORDER BY cd.LastModifiedDate ASC, cd.CustID ASC
		LIMIT lv_BatchSize;
    
    END IF;
    
    SET lv_LastScannedDate = (SELECT MAX(LastModifiedDate) FROM Temp_Cust);
    SET lv_LastCustID = (SELECT MAX(CustID) FROM Temp_Cust WHERE LastModifiedDate = lv_LastScannedDate);
    
    SELECT lv_LastScannedDate AS LastScannedDate , lv_LastCustID AS LastCustID;
    
    SELECT	tmp.CustID
		, 	tmp.ClassifiedScore
        ,	tmp.ClassifiedDate
        ,	cus.CTSCustID
        ,	cus.SubscriberID
        ,	cus.RoleID
        ,	CONST_CATEID_EARLYWARNING AS CategoryID
        ,	CONST_CATEGROUPID_EARLYWARNING AS CategoryGroup
	FROM Temp_Cust AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmp.CustID = cus.CustID AND cus.CustSubID = 0;
    
END$$	
DELIMITER ;
