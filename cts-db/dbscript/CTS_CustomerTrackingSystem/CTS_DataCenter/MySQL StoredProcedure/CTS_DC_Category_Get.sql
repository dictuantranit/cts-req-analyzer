/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Category_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Category_Get`()
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210315@Casey.Huynh
		Task:		Get Category List
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20210316@Casey.Huynh: Created [Redmine ID: #150457]
            - 20210727@Irena.Vo: Enhance Category filter [Redmine ID: #159142]
			- 20210805@Irena.Vo: Update get Category filter [Redmine ID: #155956]
            - 20240318@Casey.Huynh: Classify Danger Score [Redmine ID: #201358]
			- 20240425@Thomas.Nguyen: Classify Initial Group Betting - Add ParentID = 150 [Redmine ID: #200854]
			- 20240626@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode ParentID [Redmine ID: #205317]
			- 20240930@Casey.Huynh: Agent CC [Redmine ID: #185799]
            
		Param's Explanation (filtered by):
        
        Example: "RoleGroup" : # 1:Member, 2:Agent, 3:Master, 4:Super, 0:SuperMasterAgent   
	*/
	DECLARE CONST_BIZCATEGROUPID_PA				INT;
	DECLARE CONST_BIZCATEGROUPID_PAASSOCIATED	INT;
	DECLARE CONST_BIZCATEGROUPID_NORMAL			INT;
	DECLARE CONST_BIZCATEGROUPID_OTHERS			INT;
    
    DECLARE CONST_AGENCY_BIZCATEGROUPID_PA				INT;
	DECLARE CONST_AGENCY_BIZCATEGROUPID_PAASSOCIATED	INT;
	DECLARE CONST_AGENCY_BIZCATEGROUPID_NORMAL			INT;
	DECLARE CONST_AGENCY_BIZCATEGROUPID_OTHERS			INT;
    
    DECLARE CONST_ROLEGROUP_MEMBER				SMALLINT DEFAULT 1; # MEmber Cust.RoleID IN (1)
    DECLARE CONST_ROLEGROUP_SUPERMASTER			SMALLINT DEFAULT 0; # Agency(SMA) Cust.RoleID IN (3,4)

	SET CONST_BIZCATEGROUPID_PA				= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_PA');
	SET CONST_BIZCATEGROUPID_PAASSOCIATED	= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_PAASSOCIATED');
	SET CONST_BIZCATEGROUPID_NORMAL			= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_NORMAL');
	SET CONST_BIZCATEGROUPID_OTHERS 		= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_OTHERS');    
    
    SET CONST_AGENCY_BIZCATEGROUPID_PA				= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_BIZCATEGROUPID_PA');
	SET CONST_AGENCY_BIZCATEGROUPID_PAASSOCIATED	= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_BIZCATEGROUPID_PAASSOCIATED');
	SET CONST_AGENCY_BIZCATEGROUPID_NORMAL			= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_BIZCATEGROUPID_NORMAL');
	SET CONST_AGENCY_BIZCATEGROUPID_OTHERS 			= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_BIZCATEGROUPID_OTHERS');  

	DROP TEMPORARY TABLE IF EXISTS Temp_CategoryFilter;
	CREATE TEMPORARY TABLE Temp_CategoryFilter(
			ID 				SMALLINT
		,  	CategoryGroup 	TEXT
		,  	CategoryName 	TEXT
		,  	CategoryIDs 	LONGTEXT
        ,	RoleGroup		SMALLINT	# 1:Member, 2:Agency
	);

	INSERT IGNORE INTO Temp_CategoryFilter (ID, CategoryGroup, CategoryName, CategoryIDs,RoleGroup)
	SELECT 	cat.BusinessCategoryGroupID AS ID
		,	'Problem Account Category' AS CategoryGroup		    
		,	cat.CategoryName
		,	GROUP_CONCAT(cat.CategoryID SEPARATOR ',')  AS CategoryIDs 
        ,	CONST_ROLEGROUP_MEMBER
	FROM	CTS_DataCenter.CustomerCategory AS cat
	WHERE 	cat.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_PA
		AND cat.IsActive = 1
	GROUP BY cat.CategoryName, cat.BusinessCategoryGroupID
	UNION
	SELECT 	cat.BusinessCategoryGroupID AS ID
		,	'PA Associated Category' AS CategoryGroup		    
		,	cat.CategoryName
		,	GROUP_CONCAT(cat.CategoryID SEPARATOR ',')  AS CategoryIDs
        ,	CONST_ROLEGROUP_MEMBER
	FROM	CTS_DataCenter.CustomerCategory AS cat
	WHERE 	cat.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_PAASSOCIATED
		AND cat.IsActive = 1
	GROUP BY cat.CategoryName, cat.BusinessCategoryGroupID
	UNION
	SELECT	cat.BusinessCategoryGroupID AS ID
		,	'Normal Account Category' AS CategoryGroup
		,	cat.CategoryName
		,	GROUP_CONCAT(cat.CategoryID SEPARATOR ',')  AS CategoryIDs
        ,	CONST_ROLEGROUP_MEMBER
	FROM	CTS_DataCenter.CustomerCategory AS cat
	WHERE 	cat.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_NORMAL
		AND cat.IsActive = 1
	GROUP BY cat.CategoryName, cat.BusinessCategoryGroupID
	UNION
	SELECT	cat.BusinessCategoryGroupID AS ID
		,	'Others' AS CategoryGroup
		,	cat.CategoryName
		,	GROUP_CONCAT(cat.CategoryID SEPARATOR ',')  AS CategoryIDs
        ,	CONST_ROLEGROUP_MEMBER
	FROM	CTS_DataCenter.CustomerCategory AS cat
	WHERE 	cat.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_OTHERS
		AND cat.IsActive = 1
	GROUP BY cat.CategoryName, cat.BusinessCategoryGroupID
	UNION
	SELECT CONST_BIZCATEGROUPID_OTHERS AS ID
		,	'Others'  AS CategoryGroup
		,	'No Category' AS CategoryName
		, 	0 AS CategoryIDs
        ,	CONST_ROLEGROUP_MEMBER;
        
	#=============================FOR AGENT===========================================================================================
    INSERT IGNORE INTO Temp_CategoryFilter (ID, CategoryGroup, CategoryName, CategoryIDs,RoleGroup)
	SELECT 	cat.BusinessCategoryGroupID AS ID
		,	'Problem Account Category' AS CategoryGroup		    
		,	cat.CategoryName
		,	GROUP_CONCAT(cat.CategoryID SEPARATOR ',')  AS CategoryIDs 
        ,	(CASE WHEN RoleID IS NULL THEN CONST_ROLEGROUP_SUPERMASTER ELSE RoleID END) AS RoleGroup
	FROM	CTS_DataCenter.CustomerCategoryAgency AS cat
	WHERE 	cat.BusinessCategoryGroupID = CONST_AGENCY_BIZCATEGROUPID_PA
		AND cat.IsActive = 1
	GROUP BY cat.RoleID, cat.CategoryName, cat.BusinessCategoryGroupID
	UNION
	SELECT 	cat.BusinessCategoryGroupID AS ID
		,	'PA Associated Category' AS CategoryGroup		    
		,	cat.CategoryName
		,	GROUP_CONCAT(cat.CategoryID SEPARATOR ',')  AS CategoryIDs
        ,	(CASE WHEN RoleID IS NULL THEN CONST_ROLEGROUP_SUPERMASTER ELSE RoleID END) AS RoleGroup
	FROM	CTS_DataCenter.CustomerCategoryAgency AS cat
	WHERE 	cat.BusinessCategoryGroupID = CONST_AGENCY_BIZCATEGROUPID_PAASSOCIATED
		AND cat.IsActive = 1
	GROUP BY cat.RoleID, cat.CategoryName, cat.BusinessCategoryGroupID
	UNION
	SELECT	cat.BusinessCategoryGroupID AS ID
		,	'Normal Account Category' AS CategoryGroup
		,	cat.CategoryName
		,	GROUP_CONCAT(cat.CategoryID SEPARATOR ',')  AS CategoryIDs
        ,	(CASE WHEN RoleID IS NULL THEN CONST_ROLEGROUP_SUPERMASTER ELSE RoleID END) AS RoleGroup
	FROM	CTS_DataCenter.CustomerCategoryAgency AS cat
	WHERE 	cat.BusinessCategoryGroupID = CONST_AGENCY_BIZCATEGROUPID_NORMAL
		AND cat.IsActive = 1
	GROUP BY cat.RoleID, cat.CategoryName, cat.BusinessCategoryGroupID
	UNION
	SELECT	cat.BusinessCategoryGroupID AS ID
		,	'Others' AS CategoryGroup
		,	cat.CategoryName
		,	GROUP_CONCAT(cat.CategoryID SEPARATOR ',')  AS CategoryIDs
        ,	(CASE WHEN RoleID IS NULL THEN CONST_ROLEGROUP_SUPERMASTER ELSE RoleID END) AS RoleGroup
	FROM	CTS_DataCenter.CustomerCategoryAgency AS cat
	WHERE 	cat.BusinessCategoryGroupID = CONST_AGENCY_BIZCATEGROUPID_OTHERS
		AND cat.IsActive = 1
	GROUP BY cat.RoleID, cat.CategoryName, cat.BusinessCategoryGroupID
	UNION
	SELECT	CONST_AGENCY_BIZCATEGROUPID_OTHERS AS ID
		,	'Others'  AS CategoryGroup
		,	'No Category' AS CategoryName
		, 	0 AS CategoryIDs
        ,	CONST_ROLEGROUP_SUPERMASTER;
        
	#===================================================================================================
	SELECT	tmp.RoleGroup # 1:Member, 2:Agent, 3:Master, 4:Super, 0:SuperMasterAgent
		,	tmp.CategoryGroup
		,	tmp.CategoryName
		,	tmp.CategoryIDs        
	FROM Temp_CategoryFilter AS tmp
	ORDER BY tmp.ID ASC, tmp.CategoryName ASC; 
    
END$$
DELIMITER ;