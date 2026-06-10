/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_RobotClassificationAgency_GetRobotStatus`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RobotClassificationAgency_GetRobotStatus`(
		IN ip_CustID 			BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20241017@Thomas.Nguyen
		Task:		Get lastest robot classification for Agency
		DB:			CTS_DataCenter
        
		Revisions:
            - 20241017@Thomas.Nguyen:			Created [Redmine ID: #185799]

		Explanation:
			- RobotType: 2-Bad | 1-Good | 0-Observed | -1-No classification | -2-Not Robot
            
        Example:
			- CALL CTS_DataCenter.CTS_DC_RobotClassificationAgency_GetRobotStatus(2550565);
	*/
    
    DECLARE CONST_ROBOTTYPE_NOTROBOT 		        INT DEFAULT 0;
    DECLARE CONST_ROBOTTYPE_BAD 			        INT DEFAULT 2;
	DECLARE	CONST_ROBOTTYPE_GOOD 			        INT DEFAULT 1;
    
	DECLARE CONST_AGENCY_PARENTID_VVIP 				INT;
    DECLARE	CONST_AGENCY_CATEID_ROBOT 			    INT;
    DECLARE	CONST_AGENCY_CATEID_ROBOTLOSING         INT;  
    
	SET CONST_AGENCY_PARENTID_VVIP 					= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
	SET CONST_AGENCY_CATEID_ROBOT 				    = CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOT');
    SET CONST_AGENCY_CATEID_ROBOTLOSING 		    = CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOTLOSING');
    
    SET @IsRobot = 0;
    
    SELECT CASE WHEN cls.ParentID = CONST_AGENCY_PARENTID_VVIP THEN 0 ELSE cls.CategoryID END
	INTO @IsRobot
	FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
	WHERE cls.CustID = ip_CustID
		AND (cls.ParentID = CONST_AGENCY_PARENTID_VVIP OR CategoryID IN (CONST_AGENCY_CATEID_ROBOT, CONST_AGENCY_CATEID_ROBOTLOSING))
	LIMIT 1;
    
    SELECT 	ip_CustID AS CustID
		, 	CASE 
				WHEN @IsRobot = CONST_AGENCY_CATEID_ROBOT THEN CONST_ROBOTTYPE_BAD
                WHEN @IsRobot = CONST_AGENCY_CATEID_ROBOTLOSING THEN CONST_ROBOTTYPE_GOOD
                ELSE CONST_ROBOTTYPE_NOTROBOT END AS RobotType;

END$$

DELIMITER ;