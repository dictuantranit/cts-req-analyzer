
DROP PROCEDURE IF EXISTS `SPU_AIML_RD_GetRobotUsersDetails`;

DELIMITER $$
CREATE DEFINER=`AIMLOwner`@`%` PROCEDURE `SPU_AIML_RD_GetRobotUsersDetails`(
	IN 	ip_CustID 				BIGINT UNSIGNED,
	IN 	ip_PeriodRangeType		SMALLINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20211109@Long.Luu
		Task:		Insert Robot Users [Redmine ID: #162341]
		DB:			SPU_AIML
		Original: 

		Revisions:
			- 20211109@Long.Luu: Created [Redmine ID: #162341]
            
		Example:
			call SPU_AIML.SPU_AIML_RD_GetRobotUsersDetails (1,1);     
	*/ 
    
    SELECT CustID, PeriodRangeType, GROUP_CONCAT(SuspiciousTransList) AS SuspiciousTransList
	FROM SPU_AIML.RD_RobotUsers
	WHERE CustID = ip_CustID 
		AND PeriodRangeType = ip_PeriodRangeType
	GROUP BY CustID, PeriodRangeType;
END$$

DELIMITER ;
