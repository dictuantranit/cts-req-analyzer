/*<info serverAlias="DBAIML-SPU_AIML" databaseType="2" executers="aimlServiceAdmin" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `SPU_AIML_RD_LP_GetRobotDetails`;

DELIMITER $$
CREATE DEFINER=`AIMLOwner`@`%` PROCEDURE `SPU_AIML_RD_LP_GetRobotDetails`(
			IN 	ip_CustID				BIGINT   
        ,	IN	ip_PeriodRangeType		SMALLINT
)
    SQL SECURITY INVOKER
BEGIN  
	/*  
		Created:	20241211@Casey.Huynh
		Task:		Get Bot Login Pattern Details
		DB:			SPU_AIML
        
		Revisions:
			- 20241211@Casey.Huynh: Created [Redmine ID: #214655]

		Param's Explanation (filtered by): 
        
        Example:
			CALL SPU_AIML.SPU_AIML_RD_LP_GetRobotDetails(@ip_CustID:=2211693, 100);
	*/   
    
	SELECT	bl.TransTime
		,	bl.FirstDeviceCode AS Device
        ,	bl.RobotTracking
        ,	bl.DeviceType
        ,	bl.BrowserName
        ,	bl.IP
        ,	URLDetails  AS Domain
    FROM SPU_AIML.LIC_BDLB_SuspiciousTransInfo AS bl
    WHERE	bl.CustID = ip_CustID
		AND bl.BehaviorID = ip_PeriodRangeType;
    
END$$

DELIMITER ;
