/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_Normal_GetCurrentCategory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Normal_GetCurrentCategory`(
		IN ip_CustInfo	JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20221110@Casey.Huynh	
		Task :		Get Existing Category (Normal Flow)
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20200423@Casey.Huynh: Created [Redmine ID: #178022]
			- 20230120@Long.Luu: Support special case for Inactive (return CategoryID instead of CategoryGroup) [Redmine ID: #182997]
            - 20230427@Jonas.Huynh: Renovate normal classification [Redmine ID: #186678]
            - 20230605@Jonas.Huynh: Renovate normal classification (phase2) [Redmine ID: #186684]
            - 20230915@Jonas.Huynh: HF Wrong Inactive Category for New and Realtime flow exclude S/R/P with not latest category [Redmine ID: #193050]
            - 20231024@Jonas.Huynh: Rollback code [Redmine ID: #193050]
			- 20240619@Jonas.Huynh: Renovate CC [Redmine ID: #205317]
            - 20240912@Jonas.Huynh: HF Inconsistent classification [Redmine ID: #214058]
			- 20250515@Thomas.Nguyen: Return more Haifa Lic Sub CC [Redmine ID: #226847]
            
		Param's Explanation:
        
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_Normal_GetCurrentCategory(@ip_CustInfo := '[{"CustID":4526651,"ScanSpecialLicSubType": 1}]');
	 */ 	
	DECLARE	CONST_GROUP_PROBATION 					INT ;
	DECLARE	CONST_GROUP_INACTIVE 					INT ;
	DECLARE	CONST_PARENTID_NORMAL 					INT ;
    DECLARE CONST_PARENTID_WRAPPER					INT	;
	DECLARE CONST_CATEGORYID_NEW_LICSUB 			INT DEFAULT 40106;
	DECLARE CONST_CATEGORYID_PROB_LICSUB 			INT DEFAULT 40406;
	DECLARE CONST_CATEGORYID_SMART_LICSUB 			INT DEFAULT 40506;
	DECLARE CONST_CATEGORYID_RISKY_LICSUB 			INT DEFAULT 40606;  
	DECLARE CONST_SCANSPECIALLICSUBTYPE_EXIST		TINYINT DEFAULT 1;

	DECLARE lv_CurrentTime 							DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE lv_CurrentDate 							DATE DEFAULT CURRENT_DATE();
    DECLARE lv_LastDayProbation 					DATE DEFAULT DATE_SUB(lv_CurrentDate, INTERVAL 14 DAY); /*Up to 15 Last Day*/
       
	SET CONST_PARENTID_NORMAL 		= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_PARENTID_WRAPPER 		= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
    SET CONST_GROUP_INACTIVE 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_INACTIVE');
    SET CONST_GROUP_PROBATION 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_PROBATION');
        
    DROP TEMPORARY TABLE IF EXISTS Temp_InputCust;
    CREATE TEMPORARY TABLE Temp_InputCust(
			CustID						BIGINT UNSIGNED PRIMARY KEY
		,	ScanSpecialLicSubType		TINYINT
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			CustID 					BIGINT UNSIGNED PRIMARY KEY
		,	CreatedDate				DATETIME
		,	ScanSpecialLicSubType	TINYINT
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory;
    CREATE TEMPORARY TABLE Temp_CustCategory (
			CustID 				BIGINT UNSIGNED PRIMARY KEY
        ,	CategoryID			INT UNSIGNED
        ,	CategoryGroupID		INT UNSIGNED
        ,	ParentID			INT UNSIGNED
		,	CreatedDate			DATETIME
		,	INDEX IX_Temp_CustCategory_CategoryGroup(CategoryGroupID)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ReactiveCust;
	CREATE TEMPORARY TABLE Temp_ReactiveCust(
			CustID 			BIGINT UNSIGNED PRIMARY KEY
	);  
    
    #1. Get valid customers
    IF ip_CustInfo IS NOT NULL THEN

		INSERT IGNORE INTO Temp_InputCust(CustID, ScanSpecialLicSubType)
		SELECT  js.CustID
			,	js.ScanSpecialLicSubType
		FROM JSON_TABLE(ip_CustInfo,
						"$[*]" COLUMNS(
									CustID					BIGINT UNSIGNED		PATH "$.CustID"
								,	ScanSpecialLicSubType	TINYINT				PATH "$.ScanSpecialLicSubType"
							)
					) AS js;  
		
        INSERT INTO Temp_Cust(CustID, CreatedDate, ScanSpecialLicSubType)
		SELECT tmpIc.CustID, cus.CreatedDate, tmpIc.ScanSpecialLicSubType
        FROM Temp_InputCust AS tmpIc
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpIc.CustID = cus.CustID AND cus.CustSubID = 0;
    END IF;	
	
    #2. Get latest normal category
	INSERT INTO Temp_CustCategory(CustID, CategoryID, CategoryGroupID, ParentID, CreatedDate)
	SELECT 	tmpc.CustID
		,	tmplc.CategoryID
        ,	tmplc.CategoryGroupID
        ,	tmplc.ParentID
        , 	tmplc.CreatedDate
	FROM Temp_Cust AS tmpc
		, LATERAL	
			(	SELECT cc.CustID, cc.CategoryID, ca.CategoryGroupID, cc.CreatedDate, cc.ParentID
				FROM CTS_DataCenter.CTSCustomerClassification AS cc 
					INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
				WHERE tmpc.CustID = cc.CustID
					AND ca.IsActive = 1
                    AND cc.ParentID <> CONST_PARENTID_WRAPPER 
				ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
				LIMIT 1
		   ) tmplc;
   
    #3. Return data set
	SELECT	DISTINCT tmpCust.CustID
		,	CASE
				WHEN tmpCc.CategoryGroupID IS NULL OR (tmpCust.ScanSpecialLicSubType = CONST_SCANSPECIALLICSUBTYPE_EXIST AND tmpCc.ParentID <> CONST_PARENTID_NORMAL) THEN 0
                WHEN tmpCc.CategoryGroupID = CONST_GROUP_INACTIVE THEN tmpCc.CategoryID
                ELSE tmpCc.CategoryGroupID
			END AS CategoryID
		,   CASE WHEN tmpCust.CreatedDate >= DATE_SUB(lv_CurrentTime, INTERVAL 29 DAY) THEN 1 ELSE 0 END AS IsNewCreated
        ,	CASE WHEN tmpCc.CategoryGroupID IS NOT NULL AND tmpCc.CategoryGroupID = CONST_GROUP_PROBATION AND tmpCc.CreatedDate <= lv_LastDayProbation THEN 1 ELSE 0 END AS IsProbationLastDay /*Up to Smart, Risky*/
		,   CASE WHEN tmpCc.CategoryID IN (CONST_CATEGORYID_NEW_LICSUB, CONST_CATEGORYID_PROB_LICSUB, CONST_CATEGORYID_SMART_LICSUB, CONST_CATEGORYID_RISKY_LICSUB) THEN 1 ELSE 0 END AS IsSpecialLicSubCC
	FROM Temp_Cust AS tmpCust
		LEFT JOIN Temp_CustCategory AS tmpCc ON tmpCc.CustID = tmpCust.CustID
	WHERE tmpCc.CategoryGroupID IS NULL 
	 	OR tmpCc.ParentID = CONST_PARENTID_NORMAL
		OR tmpCust.ScanSpecialLicSubType = CONST_SCANSPECIALLICSUBTYPE_EXIST;
END$$
DELIMITER ;