/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsAPI" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_GetLatestRiskLevel`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_GetLatestRiskLevel`(
		IN ip_SubscriberID	INT
    ,	IN ip_LastID		BIGINT UNSIGNED
    ,	IN ip_BatchSize		INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240708@Casey.Huynh	
		Task :		Get the latest Risk Level 
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20240708@Casey.Huynh: Created [RedmineID: #206486]
      - 20240822@Thomas.Nguyen: Renovate CC phase 2 [Redmine ID: #205317]

        Param's Explanation:     
        Example:
			CALL CTS_DC_CustClassification_GetLatestRiskLevel(4400, 1016629001, 1000);
	*/ 

    DECLARE lv_LastModifiedDate         BIGINT UNSIGNED;
    DECLARE CONST_CATEID_SPECIALCC      INT;

    SET CONST_CATEID_SPECIALCC					= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_SPECIALCC');
        
    DROP TEMPORARY TABLE IF EXISTS Temp_ClassificationHistory;    
    CREATE TEMPORARY TABLE Temp_ClassificationHistory(
			ID 					BIGINT
        ,	CustID				BIGINT UNSIGNED
        ,	RegisterName		VARCHAR(50)       
       
	);     
    
    SET lv_LastModifiedDate = TIMESTAMPADD(MINUTE, -1, NOW());
 
    INSERT INTO Temp_ClassificationHistory(ID, CustID, RegisterName)
    SELECT DISTINCT
			clh.ID
		,	clh.CustID
        ,	cus.RegisterName
	FROM CTS_DataCenter.CTSCustomerClassification_History AS clh
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON  cls.SubscriberID = ip_SubscriberID AND cls.CustID = clh.CustID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = clh.CustID AND cus.CustSubID = 0 AND cus.RegisterName IS NOT NULL AND cus.RoleID = 1
	WHERE	clh.ID > ip_LastID
    AND clh.CategoryID <> CONST_CATEID_SPECIALCC
		AND clh.LastModifiedDate <= lv_LastModifiedDate
	ORDER BY clh.ID
	LIMIT ip_BatchSize;
	
    ALTER TABLE Temp_ClassificationHistory
		ADD PRIMARY KEY PK_Temp_ClassificationHistory_ID(ID)
    ,	ADD INDEX IX_Temp_ClassificationHistory_CustID(CustID);
    
    WITH CTE_History(ID, CustID, RegisterName) AS
    (
    SELECT 	MAX(tmpCls.ID) AS ID
		,	tmpCls.CustID
		,	tmpCls.RegisterName
    FROM Temp_ClassificationHistory AS tmpCls
    GROUP BY tmpCls.CustID, tmpCls.RegisterName)
    SELECT cte.ID AS ID		
        ,	cte.RegisterName 
        ,	ltr.Ext_SabaIntelligentRiskLevel AS RiskLevel       
		,	cte.CustID
        ,	ltr.CategoryName
        ,	ltr.CustomerClassName
        ,	ltr.CustomerClass
        ,	ltr.LastModifiedDate
    FROM 	CTE_History AS cte
		,	LATERAL(SELECT cat.CategoryName, cat.CustomerClassName, cat.CustomerClass, cat.Ext_SabaIntelligentRiskLevel, cls.LastModifiedDate
              FROM CTS_DataCenter.CTSCustomerClassification AS cls
                INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cls.CategoryID = cat.CategoryID AND cat.IsActive = 1 AND cat.CustomerClass IS NOT NULL
              WHERE cls.CustID = cte.CustID
              ORDER BY cat.CustomerClassPriority ASC, cls.LastModifiedDate DESC		
              LIMIT 1) AS ltr
	ORDER BY cte.ID ASC;
    
END$$
DELIMITER ;
