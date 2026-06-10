
DROP PROCEDURE IF EXISTS `SPU_AIML_RD_GetRobotUserMatch`;

DELIMITER $$
CREATE DEFINER=`AIMLOwner`@`%` PROCEDURE `SPU_AIML_RD_GetRobotUserMatch`(		
		IN 	ip_CustID			BIGINT
    ,	IN	ip_PeriodRangeType	SMALLINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN  
	/*  
		Created:	20230404@Casey.Huynh
		Task:		GET OCRD Match of Customer
		DB:			CTS_DataCenter
        
		Revisions:
			- 20230404@Casey.Huynh: Created [Redmine ID: #185777]
			- 20230512@Casey.Huynh: Support by input PeriordRangeType [Redmine ID: #186992]
		Param's Explanation (filtered by): 
        
        Example:
			CALL SPU_AIML_RD_GetRobotUserMatch(@ip_PeriodRangeType:=200, @ip_CustID:=2211693);
	*/       
    SELECT	rs.MatchID
		, 	LENGTH(TRIM(rs.SuspiciousTransList)) - LENGTH(REPLACE(TRIM(rs.SuspiciousTransList),',','')) + 1 AS TotalTickets
    FROM SPU_AIML.RD_RobotUsers AS rs
    WHERE 	rs.CustID = ip_CustID
		AND rs.PeriodRangeType = ip_PeriodRangeType;
END$$

DELIMITER ;
