/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_InsertNormalAccount_NewCategory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_InsertNormalAccount_NewCategory`(
		IN ip_TableName VARCHAR(200)
	,	IN ip_IsNewCustomer	BOOLEAN
)
    SQL SECURITY INVOKER
BEGIN
/*
		Created:	20230921@Casey.Huynh
		Task:		Create New Category for New Member
		DB:			CTS_DataCenter
		Original:
		Revisions: 
				- 20230921@Casey.Huynh: Created [Redmine ID: #193050]
                - 20231024@Jonas.Huynh: HF wrong reactivated category [Redmine ID: #193050]
                - 20240502@Jonas.Huynh: Handle duplicate categories [Redmine ID: #203323]
                - 20240628@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode CategoryID, ParentID [Redmine ID: #205317]
				- 20241023@Jonas.Huynh:	Remove columns: SportGroupID_arc,CategoryID_arc [Redmine ID: #212240]
                - 20252703@Jonas.Huynh: Fixed duplicate new cateogry
                
		Param's Explanation (filtered by):
        
        Example:
				- CALL CTS_DataCenter.CTS_DC_CustClassification_InsertNormalAccount_NewCategory('Temp_CustNewCategory', true);
*/ 
	DECLARE	CONST_PARENTID_NORMAL 						INT;
    DECLARE CONST_CATEID_NEW							INT;
    DECLARE CONST_CATEID_INACTIVENORMAL					INT;
    DECLARE CONST_CATEID_INACTIVESMART					INT;
	DECLARE CONST_SOURCETYPE_LESSTHAN10TICKETS 			INT DEFAULT 1;
	DECLARE CONST_SOURCETYPE_INACTIVENORMAL 			INT DEFAULT 18;
    DECLARE CONST_SOURCETYPE_INACTIVEPROPUNTER			INT DEFAULT 19;
    DECLARE CONST_CREATEDBY								INT DEFAULT 10278938;
    
	DECLARE lv_CurrentDateTime 							DATETIME DEFAULT CURRENT_TIME();

	SET CONST_PARENTID_NORMAL							= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
	SET CONST_CATEID_NEW								= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_NEW');
	SET CONST_CATEID_INACTIVENORMAL						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INACTIVENORMAL');
	SET CONST_CATEID_INACTIVESMART						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INACTIVESMART');

    #=====================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
    CREATE TEMPORARY TABLE Temp_Customer(
			CustID			INT PRIMARY KEY
		,	IsInternal		BOOLEAN
        ,	SiteID			INT
        ,	CategoryID		INT DEFAULT NULL
        ,	CustomerClass	INT
        ,	INDEX			IX_Temp_Customer_CategoryID(CategoryID)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustomerHistory;
    CREATE TEMPORARY TABLE Temp_CustomerHistory(
			CustID			INT PRIMARY KEY
		,	CustomerClass	INT NOT NULL
        ,   CategoryID		INT NOT NULL
	);
    
    #=====================================================   

	SET @sql =CONCAT("	INSERT IGNORE INTO Temp_Customer (CustID, IsInternal, SiteID) 
						SELECT	ipTbl.CustID
							,	ipTbl.IsInternal
                            ,	ipTbl.SiteID
						FROM ",ip_TableName," AS ipTbl"
						);
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1; 

    CALL CTS_DataCenter.CTS_DC_ExcludeCustomer(2,'Temp_Customer');
    
     /* 0: INSERT CTSCustomerClassification */
     IF ip_IsNewCustomer = TRUE	THEN
		UPDATE Temp_Customer AS temp
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = CONST_CATEID_NEW
        SET 	temp.CategoryID = CONST_CATEID_NEW
			,	temp.CustomerClass = cc.CustomerClass;
     ELSE
		DELETE tmp
		FROM Temp_Customer AS tmp
		WHERE EXISTS (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassification AS clss WHERE clss.CustID = tmp.CustID);
		
		UPDATE Temp_Customer AS temp
			,	LATERAL
				(
					SELECT DISTINCT arc.CustID, arc.CategoryID, arc.ID
					FROM CTS_DataCenter.ArchiveCustomer_CTSCustomer AS arc
					WHERE arc.CustID = temp.CustID
						AND arc.CustSubID = 0
						AND arc.IsReactivated = TRUE
					ORDER BY arc.ID DESC
					LIMIT 1
				) AS arc
		SET temp.CategoryID = CASE
								WHEN arc.CategoryID = CONST_CATEID_INACTIVENORMAL THEN CONST_CATEID_INACTIVENORMAL
								WHEN arc.CategoryID = CONST_CATEID_INACTIVESMART THEN CONST_CATEID_INACTIVESMART
								ELSE NULL
							  END;
                              
		UPDATE Temp_Customer AS temp
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = temp.CategoryID
        SET temp.CustomerClass = cc.CustomerClass; 
        
	 END IF;
     
     DELETE tmp
     FROM Temp_Customer AS tmp
     WHERE tmp.CategoryID IS NULL;

    /* 1: INSERT CTSCustomerClassification */
    INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification(CustID, ParentID, CategoryID, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate)
	SELECT	tmp.CustID					AS CustID
		,	CONST_PARENTID_NORMAL		AS ParentID
		,	tmp.CategoryID				AS CategoryID
		,	lv_CurrentDateTime			AS CreatedDate
		,	CONST_CREATEDBY				AS CreatedBy
		,	lv_CurrentDateTime			AS LastModifiedDate
		,	CONST_CREATEDBY				AS LastModifiedBy
		,	DATE(lv_CurrentDateTime)	AS LastScannedDate
	FROM Temp_Customer AS tmp
    WHERE NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassification AS clss WHERE clss.CustID = tmp.CustID);
    
    /* 2: INSERT CTSCustomerClassification_History*/    
    INSERT INTO Temp_CustomerHistory(CustID, CustomerClass, CategoryID)
    SELECT tmp.CustID, tmp.CustomerClass, tmp.CategoryID
    FROM Temp_Customer AS tmp
		LEFT JOIN CTSCustomerClassification_History AS cls ON tmp.CustID = cls.CustID
	WHERE cls.CustID IS NULL;
    
	INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_History(CustID, ParentID, CategoryID, TargetCC, SourceTypeID, OldCategoryID, DWCategoryID, IsDataChanged, ActionType, IsAuto, LastModifiedDate, LastModifiedBy, InsertDate)
	SELECT	tmp.CustID							AS CustID
		,	CONST_PARENTID_NORMAL				AS ParentID
		,	tmp.CategoryID						AS CategoryID
		,	tmp.CustomerClass					AS TargetCC
		,	CASE 	WHEN tmp.CategoryID = CONST_CATEID_INACTIVENORMAL THEN CONST_SOURCETYPE_INACTIVENORMAL
					WHEN tmp.CategoryID = CONST_CATEID_INACTIVESMART THEN CONST_SOURCETYPE_INACTIVEPROPUNTER 
					ELSE CONST_SOURCETYPE_LESSTHAN10TICKETS END AS SourceTypeID
		,	tmp.CategoryID						AS OldCategoryID
		,	tmp.CategoryID						AS DWCategoryID
		,	1									AS IsDataChanged
		,	0									AS ActionType
		,	1									AS IsAuto
		,	lv_CurrentDateTime					AS LastModifiedDate
		,	CONST_CREATEDBY						AS LastModifiedBy
		,	DATE(lv_CurrentDateTime)			AS InsertDate
	FROM 	Temp_CustomerHistory AS tmp;

    /* 3: WRITE CTSCustomerClassification_Log(TRACE DATA) */
	INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_Log(CustID, ParentID, CategoryID, TargetCC, SourceTypeID, OldCategoryID, DWCategoryID, IsDataChanged, ActionType, IsAuto, LastModifiedDate, LastModifiedBy, InsertDate)
	SELECT	tmp.CustID							AS CustID
		,	CONST_PARENTID_NORMAL				AS ParentID
		,	tmp.CategoryID						AS CategoryID
		,	tmp.CustomerClass					AS TargetCC
		,	CASE 	WHEN tmp.CategoryID = CONST_CATEID_INACTIVENORMAL THEN CONST_SOURCETYPE_INACTIVENORMAL
					WHEN tmp.CategoryID = CONST_CATEID_INACTIVESMART THEN CONST_SOURCETYPE_INACTIVEPROPUNTER 
					ELSE CONST_SOURCETYPE_LESSTHAN10TICKETS END AS SourceTypeID
		,	tmp.CategoryID						AS OldCategoryID
		,	tmp.CategoryID						AS DWCategoryID
		,	1									AS IsDataChanged
		,	0									AS ActionType
		,	1									AS IsAuto
		,	lv_CurrentDateTime					AS LastModifiedDate
		,	CONST_CREATEDBY						AS LastModifiedBy
		,	DATE(lv_CurrentDateTime)			AS InsertDate
	FROM 	Temp_Customer AS tmp;
    
END$$
DELIMITER ;