/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="tgrWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_TGRS_Category_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_TGRS_Category_Get`()
    SQL SECURITY INVOKER
BEGIN
/*
	Created:	20230608@Victoria.Le
	Task:		Get Category List - TGRS FOR Member Only
	DB:			CTS_DataCenter
	Original:
	Revisions:
		- 20230608@Victoria.Le:		Initial Writing [Redmine ID: #187083]
		- 20240410@Long.Luu:		Add special rule for CC2800/2801: considered as Normal by User but has been arranged as a PA in DB [Redmine ID: #201358]
		- 20240426@Thomas.Nguyen:	Classify Initial Group Betting - Add ParentID = 150 [Redmine ID: #200854]
        - 20240620@Jonas.Huynh: 	Renovate CC [RedmineID: #205317]
        - 20240923@Jonas.Huynh:		Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]
        - 20241018@Casey.Huynh: 	Update Syntax [Redmine ID: #185799]
        
	Param's Explanation (filtered by):
	Example:
		- CALL CTS_DC_TGRS_Category_Get;
*/
    
    DECLARE	CONST_PARENTID_PA				INT;
    DECLARE CONST_PARENTID_NORMAL			INT;
    DECLARE CONST_CATEGROUPID_INACTIVE		INT;
    DECLARE CONST_BIZCATEGROUPID_NORMAL		INT;
    
	DECLARE CONST_CCGROUPID_NORMAL 			SMALLINT DEFAULT 1;
	DECLARE CONST_CCGROUPID_NORMALLINKED 	SMALLINT DEFAULT 2;
	DECLARE CONST_CCGROUPID_PA 				SMALLINT DEFAULT 3;
	DECLARE CONST_CCGROUPID_OTHER 			SMALLINT DEFAULT 4;

	DROP TEMPORARY TABLE IF EXISTS Temp_CustomerCategory;
    CREATE TEMPORARY TABLE Temp_CustomerCategory(
			CustomerClass 			INT UNSIGNED PRIMARY KEY
        ,  	CategoryName 			VARCHAR(50)
        ,	CustomerClassGroupID	SMALLINT
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_SpecialCustomerClass;
    CREATE TEMPORARY TABLE Temp_SpecialCustomerClass(
			CustomerClass 			INT UNSIGNED PRIMARY KEY
		,	CategoryName			VARCHAR(50)
    );
    
    SET CONST_PARENTID_PA 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
    SET CONST_PARENTID_NORMAL 		= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_CATEGROUPID_INACTIVE 	= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_INACTIVE');
	SET CONST_BIZCATEGROUPID_NORMAL = CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_NORMAL');
	
	INSERT INTO Temp_CustomerCategory (CustomerClassGroupID,CustomerClass,CategoryName)
	WITH CTE_CC AS
	(	SELECT 	cc.ParentID
			,	cc.CustomerClass
            ,	cc.CategoryName
            ,	cc.TaggingType
            ,	cc.CategoryGroupID
            ,	cc.BusinessCategoryGroupID
            ,	ROW_NUMBER() OVER (PARTITION BY cc.CustomerClass ORDER BY cc.CategoryID) AS RowNumber
		FROM CTS_DataCenter.CustomerCategory AS cc
		WHERE cc.CustomerClass IS NOT NULL
			AND cc.IsActive = 1
	)
	SELECT 	CASE WHEN (c.ParentID = CONST_PARENTID_NORMAL AND TaggingType = 0 AND CategoryGroupID <> CONST_CATEGROUPID_INACTIVE) 
					OR (c.ParentID = CONST_PARENTID_PA AND c.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_NORMAL) THEN CONST_CCGROUPID_NORMAL -- Normal
				 WHEN c.ParentID = CONST_PARENTID_NORMAL AND TaggingType <> 0  THEN CONST_CCGROUPID_NORMALLINKED -- Normal linked Problem
				 WHEN c.ParentID = CONST_PARENTID_PA THEN CONST_CCGROUPID_PA  -- Problem Account
				 ELSE CONST_CCGROUPID_OTHER -- Other
			END AS CustomerClassGroupID
		,	c.CustomerClass
		,	c.CategoryName
	FROM CTE_CC AS c
	WHERE c.RowNumber = 1;
    
    INSERT INTO Temp_SpecialCustomerClass (CustomerClass, CategoryName)
    WITH CTE_Special AS
    (
		SELECT DISTINCT s.CustomerClass
        FROM CTS_DataCenter.SpecialCustomerClass AS s
			INNER JOIN CTS_DataCenter.CTSCustomer AS c ON s.CTSCustID = c.CTSCustID
		WHERE c.CurrencyID NOT IN (20,27,28) 
			AND IFNULL(s.CustomerClass,0) <> 0
			AND c.Site NOT IN ('Athena000')
    )
    SELECT 	s.CustomerClass
		,	CASE WHEN s.CustomerClass = 951 THEN 'Under / Underdog Group'
				 WHEN s.CustomerClass = 952 THEN 'Price Difference Group'
                 WHEN s.CustomerClass = 953 THEN 'Long Term Winning'
                 ELSE 'N/A'
			END AS CategoryName
    FROM CTE_Special AS s
    ;
    
    INSERT IGNORE Temp_CustomerCategory (CustomerClassGroupID,CustomerClass,CategoryName)
    SELECT 	4 AS CustomerClassGroupID
		,	s.CustomerClass
        ,	s.CategoryName
    FROM Temp_SpecialCustomerClass AS s
    ;
    
    SELECT 	CustomerClassGroupID
		,	CASE WHEN CustomerClassGroupID = CONST_CCGROUPID_NORMAL THEN 'Normal'
				 WHEN CustomerClassGroupID = CONST_CCGROUPID_NORMALLINKED THEN 'Normal Linked Problem'
                 WHEN CustomerClassGroupID = CONST_CCGROUPID_PA THEN 'Problem Account'
                 WHEN CustomerClassGroupID = CONST_CCGROUPID_OTHER THEN 'Others'
			END AS CustomerClassGroupName
		,	CustomerClass
        ,	CategoryName
    FROM Temp_CustomerCategory
    ORDER BY CustomerClassGroupID,CAST(CustomerClass AS CHAR(8));

END$$
DELIMITER ;