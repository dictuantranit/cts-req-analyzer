/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Common_CustomerClass_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Common_CustomerClass_Get`(
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230912@Casey.Huynh
		Task:		Get Customer List
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20230912@Casey.Huynh: Created [Redmine ID: #193029]
            - 20240318@Casey.Huynh: Classify Danger Score [Redmine ID: #201358]
			- 20240425@Thomas.Nguyen: Classify Initial Group Betting - Add ParentID = 150 [Redmine ID: #200854]
			- 20240628@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode ParentID [Redmine ID: #205317]
            - 20240923@Jonas.Huynh: Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]
			- 20240930@Adam.Tran: Return Agency CC [Redmine ID: #185799]

		Param's Explanation (filtered by):
        Example:
			- CALL CTS_DC_Common_CustomerClass_Get();
	*/
    DECLARE	CONST_GROUPNAME_PA 				VARCHAR(100) DEFAULT 'PA';
	DECLARE	CONST_GROUPNAME_NORMAL 			VARCHAR(100) DEFAULT 'Normal';
	DECLARE	CONST_GROUPNAME_ASSOCIATEDPA 	VARCHAR(100) DEFAULT 'Associated PA';
	DECLARE	CONST_GROUPNAME_OTHERS			VARCHAR(100) DEFAULT 'Others';
    
	DECLARE CONST_PARENTID_VVIP					INT;
	DECLARE CONST_PARENTID_WRAPPER				INT;
	DECLARE CONST_AGENCY_PARENTID_VVIP      	INT;
    
    DECLARE	CONST_BIZCATEGROUPID_PA 			INT;
	DECLARE	CONST_BIZCATEGROUPID_PAASSOCIATED 	INT;
	DECLARE	CONST_BIZCATEGROUPID_NORMAL 		INT;
	DECLARE CONST_BIZCATEGROUPID_OTHERS			INT;

	SET CONST_PARENTID_VVIP 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_VVIP');
    SET CONST_PARENTID_WRAPPER 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');   
	SET CONST_AGENCY_PARENTID_VVIP 			= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP'); 
	SET CONST_BIZCATEGROUPID_PA 			= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_PA');
    SET CONST_BIZCATEGROUPID_PAASSOCIATED 	= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_PAASSOCIATED');
	SET CONST_BIZCATEGROUPID_NORMAL 		= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_NORMAL');
	SET CONST_BIZCATEGROUPID_OTHERS 		= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_OTHERS');

    DROP TEMPORARY TABLE IF EXISTS Temp_CustomerClass;
    CREATE TEMPORARY TABLE Temp_CustomerClass(
		  	CustomerClass 		INT UNSIGNED
        ,  	CustomerClassGroup 	VARCHAR(50)
        ,	CategoryIDs			TEXT
        ,  	OrderID 			SMALLINT DEFAULT 0
        
        ,	PRIMARY KEY PK_Temp_CustomerClass(CustomerClassGroup ASC , CustomerClass ASC)
        ,	INDEX IX_Temp_CustomerClass_OrderID( CustomerClass, OrderID)
    );
    
    INSERT IGNORE INTO Temp_CustomerClass (CustomerClassGroup, CustomerClass, CategoryIDs)
    SELECT 	CASE 
				WHEN cat.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_PA THEN CONST_GROUPNAME_PA 
                WHEN cat.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_NORMAL THEN CONST_GROUPNAME_NORMAL 
                WHEN cat.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_PAASSOCIATED THEN CONST_GROUPNAME_ASSOCIATEDPA 
                WHEN cat.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_OTHERS THEN CONST_GROUPNAME_OTHERS 
			END AS CustomerClassGroup		    
		,	cat.CustomerClass
		,	GROUP_CONCAT(cat.CategoryID SEPARATOR ',')  AS CategoryIDs  
	FROM	CTS_DataCenter.CustomerCategory AS cat
	WHERE 	cat.IsActive = 1
        AND cat.CustomerClass IS NOT NULL
        AND cat.ParentID NOT IN (CONST_PARENTID_VVIP, CONST_PARENTID_WRAPPER)
	GROUP BY cat.CustomerClass, cat.CategoryGroupID, cat.BusinessCategoryGroupID;

	INSERT IGNORE INTO Temp_CustomerClass (CustomerClassGroup, CustomerClass, CategoryIDs)
    SELECT 	CASE 
				WHEN catA.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_PA THEN CONST_GROUPNAME_PA 
                WHEN catA.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_NORMAL THEN CONST_GROUPNAME_NORMAL 
                WHEN catA.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_OTHERS THEN CONST_GROUPNAME_OTHERS 
			END AS CustomerClassGroup		    
		,	catA.CustomerClass
		,	GROUP_CONCAT(catA.CategoryID SEPARATOR ',')  AS CategoryIDs  
	FROM	CTS_DataCenter.CustomerCategoryAgency AS catA
	WHERE 	catA.IsActive = 1
        AND catA.CustomerClass IS NOT NULL      
		AND catA.ParentID <> CONST_AGENCY_PARENTID_VVIP
	GROUP BY catA.CustomerClass, catA.CategoryGroupID, catA.BusinessCategoryGroupID;
    	
   UPDATE Temp_CustomerClass
   SET OrderID = CASE WHEN CustomerClassGroup = CONST_GROUPNAME_PA THEN 1
                 WHEN CustomerClassGroup = CONST_GROUPNAME_ASSOCIATEDPA THEN 2
                 WHEN CustomerClassGroup = CONST_GROUPNAME_NORMAL THEN 3
                 ELSE 4
			END;
	
   SELECT	OrderID
		,	CustomerClassGroup
        ,	CustomerClass
        ,	CategoryIDs 
   FROM Temp_CustomerClass 
   ORDER BY OrderID ASC, CustomerClass ASC; 

END$$
DELIMITER ;