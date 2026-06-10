/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_Realtime_GetCategory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustClassification_Realtime_GetCategory`(
	  IN ip_CustIDs      	TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20200612@Casey.Huynh
		Task:  Return the auto tag customer list by ip_category
		DB: CTS_DataCenter
		Original:
		Revisions:
			- 20200701@Casey.Huynh: Chagne Flow and Store more Info [RedmineID: #135324]
            - 20200826@Casey.Huynh: Add Trace Performance [RedmineID: #137693]
            - 202012121@Irena.Vo: Enhance logic ignore Pin category & Probation List  [RedmineID: #145951]
            - 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
			- 20210525@Irena.Vo: Change col name PinCustomerCategory: CustID -> CTSCustID [Redmine ID: 152965]
            - 20210608@Casey.Huynh: Return Category Group AND Hardcode RealTime CategoryGroup List [Redmine ID: 156465]
			- 20210722@Irena.Vo: Refactor SP [Redmine ID: 157203]  
            - 20220826@Long.Luu: Fix issue leaving blank for should-not-be-classified customer [Redmine ID: 176782]  
            - 20221007@Harvey.Nguyen: Return CurrentCategoryID [Redmine ID: #178022]
			- 20230120@Long.Luu: Support special case for Inactive (return CategoryID instead of CategoryGroup)  [Redmine ID: #182997]
            - 20230120@Long.Luu: Support special case for Inactive (return CategoryID instead of CategoryGroup)  [Redmine ID: #182997]
            - 20230313@Jonas.Huynh: Get PA category for daily scan PA [Redmine ID: #184772]
            - 20230915@Jonas.Huynh: HF Wrong Inactive Category for New and Realtime flow exclude S/R/P with not latest category [Redmine ID: #193050]
            - 20240425@Thomas.Nguyen: Classify Initial Group Betting - Add SportGroupID = 150 [Redmine ID: #200854]
			- 20240619@Jonas.Huynh: Renovate CC [Redmine ID: #205317] 
			- 20241106@Jonas.Huynh: CC Agency [Redmine ID: #185799] 
            
		Param's Explanation (filtered by):    
			CALL CTS_DC_CustClassification_Realtime_GetCategory('761925')
	*/  
    DECLARE	CONST_PARENTID_NORMAL 		INT;
	DECLARE	CONST_PARENTID_PA 			INT;
	DECLARE	CONST_PARENTID_POTENTIALPA	INT;
   	DECLARE CONST_PARENTID_WRAPPER		INT;
    
    SET CONST_PARENTID_NORMAL 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_PARENTID_PA 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
    SET CONST_PARENTID_POTENTIALPA 		= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_POTENTIALPA');
   	SET CONST_PARENTID_WRAPPER 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Customers;
	CREATE TEMPORARY TABLE Temp_Customers(
			CustID					BIGINT UNSIGNED PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustomerCategory;
	CREATE TEMPORARY TABLE Temp_CustomerCategory(
			CustID					BIGINT UNSIGNED NOT NULL
		,   CTSCustID				BIGINT UNSIGNED NOT NULL
		,	ParentID				INT
        ,	CategoryID 				INT
        ,	RelevantCategoryID 		INT UNSIGNED
        , 	INDEX IX_Temp_CustomerCategory_CustID(CustID)
	);      
	
    INSERT INTO Temp_Customers (CustID)
    SELECT DISTINCT temp.CustID
    FROM JSON_TABLE(CONCAT('[',ip_CustIDs,']'),
			'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (
				CustID 		BIGINT UNSIGNED PATH '$'
			))) AS temp;
	
    -- #1: Get customer category
	INSERT INTO Temp_CustomerCategory(CustID, CTSCustID, ParentID, CategoryID, RelevantCategoryID)
	SELECT 		tmplc.CustID
			,	tmplc.CTSCustID
			, 	tmplc.ParentID
            ,	tmplc.CategoryID
            ,	tmplc.RelevantCategoryID
	FROM Temp_Customers AS temp
    	, LATERAL	
			(	SELECT cc.CustID, cc.CTSCustID, cc.CategoryID, ca.ParentID, ca.RelevantCategoryID
				FROM CTS_DataCenter.CTSCustomerClassification AS cc 
					INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID
				WHERE temp.CustID = cc.CustID 
					AND ca.IsActive = 1
                    AND ca.ParentID <> CONST_PARENTID_WRAPPER
				ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
                LIMIT 1
		   ) tmplc;
	
    -- #2: Return customer category for realtime classification
    SELECT DISTINCT temp.CustID AS CustID
	FROM Temp_Customers AS temp
		LEFT JOIN Temp_CustomerCategory AS cate ON cate.CustID = temp.CustID
	WHERE cate.CategoryID IS NULL 
		OR (cate.CategoryID IS NOT NULL AND cate.ParentID = CONST_PARENTID_NORMAL);
	
    -- #3: Return customer with problem category for PA daily scan
	SELECT DISTINCT CustID
    FROM Temp_CustomerCategory 
    WHERE ParentID IN (CONST_PARENTID_PA, CONST_PARENTID_POTENTIALPA)
		AND RelevantCategoryID IS NOT NULL;
	
END$$
DELIMITER ;