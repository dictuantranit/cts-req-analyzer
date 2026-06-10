/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_RobotClassification_GetRobotStatusByTransList`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RobotClassification_GetRobotStatusByTransList`(
		IN ip_TransList JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210818@Harvey.Nguyen
		Task:		Get lastest robot classification
		DB:			CTS_DataCenter
        
		Revisions:
			- 20210818@Harvey.Nguyen: 	Created [Redmine ID: #160382]
			- 20210907@Long.Luu: 		Update Robot Users rules  [Redmine ID: #161232]
			- 20220214@Long.Luu: 		Support new category for Good & Bad Robot User [Redmine ID: #167726]
			- 20220603@Long.Luu: 		Merge Robot AI & Robot TW [Redmine ID: #172561]
			- 20230119@Victoria.Le		Change to check IsRobot from CTSCustomerClassification instead of RobotDetection [Redmine ID: #181995]
			- 20230517@Victoria.Le		New Category for Robot OCRD [Redmine ID: #186991]
            - 20230530@Victoria.Le		Hotfix to resolve duplicate primary key [Redmine ID: #188921]
            - 20240628@Thomas.Nguyen:	Renovate CC phase 2 - Remove hardcode CategoryID [Redmine ID: #205317]
            - 20241210@Casey.Huynh:		New Robot AI, Bot Login Pattern [Redmine ID: #214655]

		Explanation:
			- RobotType: 2-Bad | 1-Good | 0-Observed | -1-No classification | -2-Not Robot
            
        Example:
            CALL CTS_DC_RobotClassification_GetRobotStatusByTransList('[
						{"CustID":23264137, "TransDate": "2021-11-11", "TransID":"1"}
					,	{"CustID":23264137, "TransDate": "2021-11-24", "TransID":"2"}
					,	{"CustID":23264137, "TransDate": "2021-12-11", "TransID":"3"}
					,	{"CustID":23264137, "TransDate": "2022-12-14", "TransID":"4"}
					,	{"CustID":23264138, "TransDate": "2022-12-14", "TransID":"5"}
					]');

	*/    
	DECLARE CONST_ROBOTTYPE_NOTROBOT			TINYINT DEFAULT -2;
	DECLARE CONST_ROBOTTYPE_BAD 				INT 	DEFAULT 2;
	DECLARE	CONST_ROBOTTYPE_GOOD 				INT 	DEFAULT 1;

	DECLARE	CONST_CATEID_ROBOTUSER 				INT;
    DECLARE	CONST_CATEID_ROBOTUSERLOSING		INT;
	DECLARE	CONST_CATEID_ROBOTOCRD 				INT;
    DECLARE	CONST_CATEID_ROBOTOCRDLOSING		INT;
    DECLARE	CONST_CATEID_BOTLOGINPATTERN 		INT;
    DECLARE	CONST_CATEID_BOTLOGINPATTERNLOSING	INT;  
    
	SET CONST_CATEID_ROBOTUSER 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTUSER');
    SET CONST_CATEID_ROBOTUSERLOSING 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTUSERLOSING');
    SET CONST_CATEID_ROBOTOCRD 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTOCRD');
    SET CONST_CATEID_ROBOTOCRDLOSING 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTOCRDLOSING');
	SET CONST_CATEID_BOTLOGINPATTERN 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_BOTLOGINPATTERN');
    SET CONST_CATEID_BOTLOGINPATTERNLOSING 		= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_BOTLOGINPATTERNLOSING');

    DROP TEMPORARY TABLE IF EXISTS Temp_Trans;
    CREATE TEMPORARY TABLE Temp_Trans(
			CustID		BIGINT UNSIGNED
		,	TransDate	DATETIME(3)
        ,	TransID		BIGINT UNSIGNED
        
        ,	PRIMARY KEY PK_Temp_Trans(CustID,TransDate,TransID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Result;  
	CREATE TEMPORARY TABLE Temp_Result
    (
			CustID		BIGINT UNSIGNED
        ,	TransID		BIGINT UNSIGNED
		,	TransDate	DATETIME(3)
        , 	RobotType	TINYINT
		,	IsRobot		TINYINT
        ,	PRIMARY KEY 	PK_Temp_Result(CustID,TransDate,TransID)
    );
    
    #=========================================================================
    INSERT INTO Temp_Trans(CustID,TransDate,TransID)
	SELECT  js.CustID
		,	js.TransDate
		,	js.TransID
	FROM JSON_TABLE(ip_TransList,
					 "$[*]" COLUMNS(
								CustID			BIGINT UNSIGNED 	PATH "$.CustID" 
							,	TransDate		DATETIME(3) 		PATH "$.TransDate"                               
							,	TransID			BIGINT UNSIGNED 	PATH "$.TransID"
						)
				) AS js;
				
	INSERT IGNORE INTO Temp_Result(CustID, TransID, TransDate, RobotType, IsRobot)    
    SELECT	t.CustID
		,	t.TransID
        ,	t.TransDate
		,	CASE 
				WHEN cc.CategoryID IN (CONST_CATEID_ROBOTUSER,CONST_CATEID_ROBOTOCRD,CONST_CATEID_BOTLOGINPATTERN) 
					THEN CONST_ROBOTTYPE_BAD
				WHEN cc.CategoryID IN (CONST_CATEID_ROBOTUSERLOSING,CONST_CATEID_ROBOTOCRDLOSING,CONST_CATEID_BOTLOGINPATTERNLOSING) 
					THEN CONST_ROBOTTYPE_GOOD
				ELSE CONST_ROBOTTYPE_NOTROBOT
			END AS RobotType
		,	1 AS IsRobot
    FROM Temp_Trans AS t
		STRAIGHT_JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON clss.CustID = t.CustID
		STRAIGHT_JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = clss.CategoryID
	WHERE cc.CategoryID IN (CONST_CATEID_ROBOTUSER, CONST_CATEID_ROBOTUSERLOSING
							, CONST_CATEID_ROBOTOCRD, CONST_CATEID_ROBOTOCRDLOSING
							, CONST_CATEID_BOTLOGINPATTERN, CONST_CATEID_BOTLOGINPATTERNLOSING);    
    
    DELETE t
    FROM Temp_Trans AS t
		INNER JOIN Temp_Result AS r ON t.CustID = r.CustID;
    
    INSERT INTO Temp_Result(CustID, TransID, TransDate, RobotType, IsRobot)    
    SELECT	t.CustID
		,	t.TransID
        ,	t.TransDate
		,	CONST_ROBOTTYPE_NOTROBOT AS RobotType
		,	0 AS IsRobot
    FROM Temp_Trans AS t;
    
    SELECT 	r.TransID
		,	r.RobotType
		,	r.IsRobot
    FROM Temp_Result AS r
    ORDER BY r.TransID ASC;
    
 END$$
DELIMITER ;