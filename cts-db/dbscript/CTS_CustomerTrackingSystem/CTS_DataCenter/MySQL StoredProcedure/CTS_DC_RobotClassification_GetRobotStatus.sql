/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_RobotClassification_GetRobotStatus`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RobotClassification_GetRobotStatus`(
		IN ip_CustID 			BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210818@Harvey.Nguyen
		Task:		Get lastest robot classification
		DB:			CTS_DataCenter
        
		Revisions:
			- 20210818@Harvey.Nguyen: Created [Redmine ID: #160382]
			- 20210907@Long.Luu: Update Robot Users rules  [Redmine ID: #161232]            
			- 20220211@Long.Luu: Remove detailed robot classification  [Redmine ID: #167726]
			- 20220603@Long.Luu: Merge Robot AI & Robot TW [Redmine ID: #172561]
			- 20230207@Long.Luu: Get robot classification [Redmine ID: #183281]
            - 20230517@Casey.Huynh:	New Category for Robot OCRD [Redmine ID: #186991]
            - 20240628@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode CategoryID [Redmine ID: #205317]
            - 20241210@Casey.Huynh: New Robot AI, Bot Login Pattern [Redmine ID: #214655]

		Explanation:
			- RobotType: 2-Bad | 1-Good | 0-Observed | -1-No classification | -2-Not Robot
            
        Example:
			- CALL CTS_DataCenter.CTS_DC_RobotClassification_GetRobotStatus(2550565);
	*/
    
    DECLARE CONST_ROBOTTYPE_BAD 			INT DEFAULT 2;
	DECLARE	CONST_ROBOTTYPE_GOOD 			INT DEFAULT 1;
    DECLARE CONST_ROBOTTYPE_NOTROBOT 		INT DEFAULT 0;
    
	DECLARE CONST_CATEID_VVIP 					INT;
    DECLARE	CONST_CATEID_ROBOTUSER 				INT;
    DECLARE	CONST_CATEID_ROBOTUSERLOSING		INT;
	DECLARE	CONST_CATEID_ROBOTOCRD 				INT;
    DECLARE	CONST_CATEID_ROBOTOCRDLOSING		INT;
    DECLARE	CONST_CATEID_BOTLOGINPATTERN 		INT;
    DECLARE	CONST_CATEID_BOTLOGINPATTERNLOSING	INT;  
    
	SET CONST_CATEID_VVIP 						= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');
	SET CONST_CATEID_ROBOTUSER 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTUSER');
    SET CONST_CATEID_ROBOTUSERLOSING 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTUSERLOSING');
	SET CONST_CATEID_ROBOTOCRD 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTOCRD');
    SET CONST_CATEID_ROBOTOCRDLOSING 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTOCRDLOSING');
    SET CONST_CATEID_BOTLOGINPATTERN 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_BOTLOGINPATTERN');
    SET CONST_CATEID_BOTLOGINPATTERNLOSING 		= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_BOTLOGINPATTERNLOSING');

    SET @IsRobot = 0;
    
    SELECT CASE WHEN cls.CategoryID = CONST_CATEID_VVIP THEN 0 ELSE cls.CategoryID END
	INTO @IsRobot
	FROM CTS_DataCenter.CTSCustomerClassification AS cls
	WHERE cls.CustID = ip_CustID
		AND CategoryID IN (CONST_CATEID_VVIP
							, CONST_CATEID_ROBOTUSER, CONST_CATEID_ROBOTUSERLOSING
							, CONST_CATEID_ROBOTOCRD, CONST_CATEID_ROBOTOCRDLOSING
							, CONST_CATEID_BOTLOGINPATTERN, CONST_CATEID_BOTLOGINPATTERNLOSING)
	LIMIT 1;
    
    SELECT 	ip_CustID
		, 	CASE 
				WHEN @IsRobot IN (CONST_CATEID_ROBOTUSER,CONST_CATEID_ROBOTOCRD,CONST_CATEID_BOTLOGINPATTERN) THEN CONST_ROBOTTYPE_BAD
                WHEN @IsRobot IN (CONST_CATEID_ROBOTUSERLOSING,CONST_CATEID_ROBOTOCRDLOSING,CONST_CATEID_BOTLOGINPATTERNLOSING) THEN CONST_ROBOTTYPE_GOOD
                ELSE CONST_ROBOTTYPE_NOTROBOT
			END AS 'RobotType';
    
END$$

DELIMITER ;