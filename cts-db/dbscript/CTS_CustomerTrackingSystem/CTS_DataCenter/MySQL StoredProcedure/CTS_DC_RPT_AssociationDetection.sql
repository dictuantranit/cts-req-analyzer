/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService,ctsWeb" isFunction="0" isNested="1"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_RPT_AssociationDetection`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RPT_AssociationDetection`(
		IN ip_CTSCustIDs LONGTEXT
)
    SQL SECURITY INVOKER
sp:BEGIN
	/* 
		Created:	20210629@Casey.Huynh
		Task:		Get Report Association Detection
		DB:			CTS_DataCenter
        
		Revisions:
			- 20210629@Casey.Huynh: Created [Redmine ID: #157086]
            - 20210818@Aries.Nguyen: Exclude Unlink association [Redmine ID: #159708]
            - 20211026@Aries.Nguyen: Bug Exclude Unlink association [Redmine ID: #163706]
            - 20220328@Aries.Nguyen: Add new category/class for PA Probation [Redmine ID: #170468]
            - 20220705@Aries.Nguyen:  Tuning performance of Association Detection [Redmine ID: #175086]

		Param's Explanation (filtered by):

        Example:
			- CALL CTS_DataCenter.CTS_DC_RPT_AssociationDetection('257861,11436');
	*/
    DECLARE lv_CTSCustIDValidated LONGTEXT;
    
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustID;
	CREATE TEMPORARY TABLE 		Temp_CTSCustID (
		CTSCustID	BIGINT UNSIGNED PRIMARY KEY
	);
	
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationInfo;
	CREATE TEMPORARY TABLE 		Temp_AssociationInfo (
			CTSCustID			BIGINT UNSIGNED PRIMARY KEY
        ,	CustID 				BIGINT UNSIGNED 
        ,	UserName			VARCHAR(50)
        ,	CustSubID			INT UNSIGNED
		,	CustStatus			VARCHAR(50)
        ,	INDEX 				IX_Temp_CustInfo_CustID(CustID)
	);
    
     
    SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_CTSCustID(CTSCustID) VALUES ('", REPLACE(ip_CTSCustIDs, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1; 
    
    INSERT INTO Temp_AssociationInfo(CTSCustID, CustID, UserName, CustSubID, CustStatus)
    SELECT 	cust.CTSCustID
		,	cust.CustID
        ,	cust.UserName
        ,	cust.CustSubID
        ,	sta.ItemName AS CustStatus
	FROM CTS_DataCenter.CTSCustomer AS cust 
		INNER JOIN CTS_DataCenter.StaticList AS sta ON sta.ListID = 1 AND sta.ItemID = cust.CustStatusID
    WHERE EXISTS (SELECT 1 FROM Temp_CTSCustID AS temp WHERE temp.CTSCustID = cust.CTSCustID AND cust.IsInternal = 0);
	
    SELECT GROUP_CONCAT(CTSCustID) 
    INTO lv_CTSCustIDValidated
    FROM Temp_AssociationInfo;
    
    IF lv_CTSCustIDValidated IS NULL THEN
		SET lv_CTSCustIDValidated = '';
	END IF;
    
    CALL CTS_DC_AssociationDetection_GetGroup(lv_CTSCustIDValidated);
    
    SELECT 	grp.GroupID
		,	cus.CTSCustID
        ,	cus.CustID
		,	cus.UserName
        ,	cus.CustSubID 
        ,	cus.CustStatus
		, 	(SELECT GROUP_CONCAT(DISTINCT ' ',ev.EvidenceCode) 
			 FROM CTS_DataCenter.CustEvidence AS ce  
             LEFT JOIN CTS_DataCenter.Evidence AS ev ON ev.EvidenceID = ce.EvidenceID
             WHERE cus.CTSCustID = ce.CTSCustID) AS Evidence
        , 	TRIM(GROUP_CONCAT(DISTINCT ' ',cat.CategoryName)) AS CustomerCategory
        ,	TRIM(GROUP_CONCAT(DISTINCT cat.CategoryID)) AS CategoryIDs
        ,	TRIM(GROUP_CONCAT(DISTINCT cat.ParentID)) AS ParentIDs
        ,   MAX(cat.IsPAProbation) AS IsPAProbation
    FROM Temp_Group AS grp
		INNER JOIN Temp_AssociationInfo AS cus ON cus.CTSCustID = grp.CTSCustID
        LEFT JOIN CTS_DataCenter.CTSCustomerClassification AS ccl ON cus.CustID = ccl.CustID
        LEFT JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = ccl.CategoryID
	GROUP BY grp.GroupID
        , 	 cus.UserName
        ,    cus.CTSCustID
		, 	 cus.CustID  
        , 	 cus.CustStatus
        , 	 cus.CustSubID;            
END$$

DELIMITER ;
