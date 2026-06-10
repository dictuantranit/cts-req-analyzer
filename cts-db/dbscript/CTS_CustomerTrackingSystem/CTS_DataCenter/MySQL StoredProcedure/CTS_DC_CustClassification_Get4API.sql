/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsAPI" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustClassification_Get4API`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Get4API`(
        IN ip_CustIDs			VARCHAR(2000)
    ,   IN ip_ParentCateIDs		VARCHAR(500)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200914@Harvey.Nguyen
		Task :		Get CTSCustomer Category
		DB:			CTS_DataCenter.
		Original: 

		Revisions:
            - 20200910@Harvey.Nguyen: init sp [Redmine ID: #140971]
            - 20200929@Lex.Khuat: Support return problem account categories by [Redmine ID: #141962]
            - 20201130@Aries.Nguyen: Update metadata for goSQL. Remove transaction isolation level REPEATABLE READ and READ UNCOMMITTED. Remove logic detail category. [Redmine ID: #145954]
            - 20201216@Harvey.Nguyen: grouping category [Redmine ID: #147299]
            - 20210622@Aries.Nguyen: Update coding convention  [Redmine ID: #157203]
            - 20220331@Harvey.Nguyen: refactor code [Redmine ID: #170802]
			- 20220426@Harvey.Nguyen: fix bug return duplicate category [Redmine ID: #170802]
			- 20240320@Casey.Huynh: Classify Danger Score [Redmine ID: #201358]
            - 20240425@Thomas.Nguyen: Classify Initial Group Betting - Add ParentID = 150 [Redmine ID: #200854]
			- 20240628@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode ParentID [Redmine ID: #205317]
			- 20240923@Jonas.Huynh:	Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]	
            - 20241017@Casey.Huynh: Return Agency Category [Redmine ID: #185799]
			- 20250731@Adam.Tran: Agent CC, Considerable Danger - Return ParentCategoryName [Redmine ID: #219679]
            
		Param's Explanation:
        
		Example:
        
			CALL CTS_DC_CustClassification_Get4API_xpre(@ip_CustIDs:='1299,1302, 1229841,1142015,1136640, 3752852, 3712587', @ip_ParentCateIDs:='1000,10000,40000,101000,120000,140000');
    
    */ 
    
	DECLARE	CONST_PARENTID_PA 				INT;
	DECLARE	CONST_PARENTID_POTENTIALPA 		INT;
	DECLARE	CONST_PARENTID_NORMAL 			INT;
	DECLARE	CONST_PARENTID_WRAPPER			INT;
	DECLARE CONST_PARENTID_VVIP      		INT;
	DECLARE CONST_BIZCATEGROUPID_NORMAL     INT;
    
	DECLARE CONST_AGENCY_PARENTID_PA 			INT;
	DECLARE CONST_AGENCY_PARENTID_NORMAL 		INT;
	DECLARE CONST_AGENCY_PARENTID_VVIP      	INT;
	DECLARE CONST_AGENCY_PARENTID_CONSIDERABLEDANGER	INT;
    
	DECLARE CONST_PARENTNAME_PA 			VARCHAR(50);
	DECLARE CONST_PARENTNAME_POTENTIALPA 	VARCHAR(50);
	DECLARE CONST_PARENTNAME_NORMAL			VARCHAR(50);
	DECLARE CONST_PARENTNAME_CONSIDERABLEDANGER	VARCHAR(50);

  	DECLARE CONST_ROLEID_MEMBER				    TINYINT DEFAULT 1;
  	DECLARE CONST_ROLEID_AGENT            		TINYINT DEFAULT 2;
  	DECLARE CONST_ROLEID_MASTER            		TINYINT DEFAULT 3;
  	DECLARE CONST_ROLEID_SUPER            		TINYINT DEFAULT 4;

	SET CONST_PARENTID_PA 					= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_PARENTID_POTENTIALPA 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_POTENTIALPA');
	SET CONST_PARENTID_NORMAL 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
	SET CONST_PARENTID_WRAPPER 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_PARENTID_VVIP 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_VVIP');
    SET CONST_BIZCATEGROUPID_NORMAL 		= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_NORMAL');
    
	SET CONST_AGENCY_PARENTID_PA 				= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
	SET CONST_AGENCY_PARENTID_NORMAL 			= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_NORMAL');
	SET CONST_AGENCY_PARENTID_VVIP 				= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
	SET CONST_AGENCY_PARENTID_CONSIDERABLEDANGER	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_CONSIDERABLEDANGER');
    
	SET CONST_PARENTNAME_PA 				= 'Problem Account';
	SET CONST_PARENTNAME_POTENTIALPA 		= 'General Normal Account';
	SET CONST_PARENTNAME_NORMAL 			= 'General Normal Account';
	SET CONST_PARENTNAME_CONSIDERABLEDANGER = 'Others'; 

    DROP TEMPORARY TABLE IF EXISTS Temp_CustID;
    CREATE TEMPORARY TABLE Temp_CustID (
		CustID 			BIGINT UNSIGNED PRIMARY KEY
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Member;
    CREATE TEMPORARY TABLE Temp_Member (
		CustID 			BIGINT UNSIGNED PRIMARY KEY
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Agency;
    CREATE TEMPORARY TABLE Temp_Agency (
		CustID 			BIGINT UNSIGNED PRIMARY KEY
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ParentID;
    CREATE TEMPORARY TABLE Temp_ParentID (
		ParentID 		INT UNSIGNED PRIMARY KEY
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_MemberParentID;
    CREATE TEMPORARY TABLE Temp_MemberParentID (
		ParentID 		INT UNSIGNED PRIMARY KEY
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AgencyParentID;
    CREATE TEMPORARY TABLE Temp_AgencyParentID (
		ParentID 		INT UNSIGNED PRIMARY KEY
    );
    
    IF IFNULL(ip_CustIDs, '') <> '' THEN
		SET @sql = CONCAT("INSERT INTO Temp_CustID (CustID) VALUES ('", REPLACE(ip_CustIDs, ",", "'),('"),"');");
		PREPARE stmt1 FROM @sql;
		EXECUTE stmt1;
    END IF;
    
    IF IFNULL(ip_ParentCateIDs, '') <> '' THEN
		SET @sql = CONCAT("INSERT INTO Temp_ParentID (ParentID) VALUES ('", REPLACE(ip_ParentCateIDs, ",", "'),('"),"');");
		PREPARE stmt2 FROM @sql;
		EXECUTE stmt2;
	END IF;

    INSERT INTO Temp_Member(CustID)
    SELECT tmp.CustID
    FROM Temp_CustID AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmp.CustID = cus.CustID AND RoleID = CONST_ROLEID_MEMBER;
	
    INSERT INTO Temp_Agency(CustID)
    SELECT tmp.CustID
    FROM Temp_CustID AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmp.CustID = cus.CustID AND RoleID IN (CONST_ROLEID_AGENT,CONST_ROLEID_MASTER,CONST_ROLEID_SUPER) AND CustSubID = 0;
        
	INSERT INTO Temp_MemberParentID(ParentID)
    SELECT tmp.ParentID
    FROM Temp_ParentID AS tmp
	WHERE tmp.ParentID IN (SELECT DISTINCT ParentID FROM CTS_DataCenter.CustomerCategory AS cat WHERE tmp.ParentID = cat.ParentID);
        
	INSERT INTO Temp_AgencyParentID(ParentID)
    SELECT tmp.ParentID
    FROM Temp_ParentID AS tmp
	WHERE tmp.ParentID IN (SELECT DISTINCT ParentID FROM CTS_DataCenter.CustomerCategoryAgency AS cat WHERE tmp.ParentID = cat.ParentID);
        
    # SELECT Member Union Agency
    SELECT DISTINCT cls.CustID
		,	(CASE	WHEN cls.ParentID = CONST_PARENTID_PA AND cat.BusinessCategoryGroupID <> CONST_BIZCATEGROUPID_NORMAL THEN CONST_PARENTNAME_PA 
					WHEN cls.ParentID = CONST_PARENTID_POTENTIALPA
						OR (cls.ParentID = CONST_PARENTID_PA AND cat.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_NORMAL) THEN CONST_PARENTNAME_POTENTIALPA
					WHEN cls.ParentID IN (CONST_PARENTID_NORMAL, CONST_PARENTID_VVIP) THEN CONST_PARENTNAME_NORMAL END
			) AS ParentCategoryName
		,	cat.CategoryName
    FROM	Temp_Member AS cust	
			, LATERAL (
				SELECT cls.CustID, cls.ParentID
				FROM CTS_DataCenter.CTSCustomerClassification AS cls
					INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cls.CategoryID = cat.CategoryID AND cat.IsActive = 1
				WHERE cls.CustID = cust.CustID AND cls.ParentID <> CONST_PARENTID_WRAPPER
				ORDER BY cat.CustomerClassPriority ASC, cls.LastModifiedDate DESC
				LIMIT 1) AS clss
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON cls.CustID = clss.CustID AND cls.ParentID = clss.ParentID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cls.CategoryID = cat.CategoryID AND cat.IsActive = 1
    WHERE IFNULL(ip_ParentCateIDs, '') = ''
			OR clss.ParentID IN (SELECT ParentID FROM Temp_MemberParentID)
	UNION # Get for Agency
	SELECT DISTINCT cls.CustID
	,	(CASE	WHEN cls.ParentID = CONST_AGENCY_PARENTID_PA THEN CONST_PARENTNAME_PA 
				WHEN cls.ParentID IN (CONST_AGENCY_PARENTID_NORMAL, CONST_AGENCY_PARENTID_VVIP) THEN CONST_PARENTNAME_NORMAL 
				WHEN cls.ParentID = CONST_AGENCY_PARENTID_CONSIDERABLEDANGER THEN CONST_PARENTNAME_CONSIDERABLEDANGER 
				END
		) AS ParentCategoryName
	,	cat.CategoryName
    FROM	Temp_Agency AS cust	
			, LATERAL (
				SELECT cls.CustID, cls.ParentID
				FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
					INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cls.CategoryID = cat.CategoryID AND cat.IsActive = 1
				WHERE cls.CustID = cust.CustID
				ORDER BY cat.CustomerClassPriority ASC, cls.LastModifiedDate DESC
				LIMIT 1) AS clss
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cls ON cls.CustID = clss.CustID AND cls.ParentID = clss.ParentID
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cls.CategoryID = cat.CategoryID AND cat.IsActive = 1
    WHERE IFNULL(ip_ParentCateIDs, '') = ''
			OR clss.ParentID IN (SELECT ParentID FROM Temp_AgencyParentID);
END$$

DELIMITER ;
