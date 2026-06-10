/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_Normal_GetCurrentCategory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_Normal_GetCurrentCategory`(
		IN ip_CustIDList	TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20241008@@Jonas.Huynh	
		Task :		Get Existing Category (Normal Flow)
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20241008@@Jonas.Huynh: Created [Redmine ID: #185799]
            
		Param's Explanation:
        
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Normal_GetCurrentCategory('5941,5942,100,7681925');
	 */ 	
	DECLARE	CONST_AGENCY_PARENTID_NORMAL	INT ; 
	DECLARE lv_CurrentTime 					DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE lv_CurrentDate 					DATE DEFAULT CURRENT_DATE();
       
	SET CONST_AGENCY_PARENTID_NORMAL 	= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_NORMAL');
        
    DROP TEMPORARY TABLE IF EXISTS Temp_InputCust;
    CREATE TEMPORARY TABLE Temp_InputCust(
			CustID 		BIGINT UNSIGNED PRIMARY KEY
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			CustID 			BIGINT UNSIGNED PRIMARY KEY
		,	RoleID			TINYINT
		,	CreatedDate		DATETIME
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory;
    CREATE TEMPORARY TABLE Temp_CustCategory (
			CustID 				BIGINT UNSIGNED PRIMARY KEY
        ,	CategoryID			INT UNSIGNED
        ,	CategoryGroupID		INT UNSIGNED
		,	INDEX IX_Temp_CustCategory_CategoryGroup(CategoryGroupID)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ReactiveCust;
	CREATE TEMPORARY TABLE Temp_ReactiveCust(
			CustID 			BIGINT UNSIGNED PRIMARY KEY
	);  
    
    #1. Get valid customers
    IF ip_CustIDList IS NOT NULL THEN        
		SET @sql = CONCAT("INSERT INTO Temp_InputCust(CustID) VALUES ('", REPLACE(ip_CustIDList, ",", "'),('"),"');");
		PREPARE stmt1 FROM @sql;
		EXECUTE stmt1;
		
        INSERT INTO Temp_Cust(CustID, RoleID, CreatedDate)
		SELECT tmpIc.CustID, cus.RoleID, cus.CreatedDate
        FROM Temp_InputCust AS tmpIc
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpIc.CustID = cus.CustID AND cus.CustSubID = 0;
    END IF;	
	
    #2. Get latest normal category
	INSERT INTO Temp_CustCategory(CustID, CategoryID, CategoryGroupID)
	SELECT 	tmpc.CustID
		,	tmplc.CategoryID
        ,	tmplc.CategoryGroupID
	FROM Temp_Cust AS tmpc
		, LATERAL	
			(	SELECT cc.CustID, cc.CategoryID, ca.CategoryGroupID, cc.CreatedDate, cc.ParentID
				FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cc 
					INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS ca ON ca.CategoryID = cc.CategoryID
				WHERE tmpc.CustID = cc.CustID
					AND ca.IsActive = 1
				ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
				LIMIT 1
		   ) tmplc 
	WHERE tmplc.ParentID = CONST_AGENCY_PARENTID_NORMAL;
   
    #3. Return data set
	SELECT	DISTINCT tmpCust.CustID
		,	tmpCust.RoleID
		,	CASE WHEN tmpCc.CategoryGroupID IS NULL THEN 0 ELSE tmpCc.CategoryGroupID END AS CategoryID
		,   CASE WHEN tmpCust.CreatedDate >= DATE_SUB(lv_CurrentTime, INTERVAL 29 DAY) THEN 1 ELSE 0 END AS IsNewCreated
	FROM Temp_Cust AS tmpCust
		LEFT JOIN Temp_CustCategory AS tmpCc ON tmpCc.CustID = tmpCust.CustID;
END$$
DELIMITER ;