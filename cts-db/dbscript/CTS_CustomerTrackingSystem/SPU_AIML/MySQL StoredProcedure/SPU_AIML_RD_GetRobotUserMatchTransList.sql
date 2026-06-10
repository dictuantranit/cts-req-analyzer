
DROP PROCEDURE IF EXISTS `SPU_AIML_RD_GetRobotUserMatchTransList`;

DELIMITER $$
CREATE DEFINER=`AIMLOwner`@`%` PROCEDURE `SPU_AIML_RD_GetRobotUserMatchTransList`(
		IN 	ip_CustID			BIGINT	
    ,	IN	ip_PeriodRangeType	SMALLINT UNSIGNED
    ,	IN 	ip_MatchID			BIGINT
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
			CALL SPU_AIML_RD_GetRobotUserMatchTransList(@ip_PeriodRangeType:=200, @ip_CustID:=2211693, @ip_MatchID:=70087424);
	*/   
    
    SELECT	rs.MatchID
		, 	js.TransID
    FROM SPU_AIML.RD_RobotUsers AS rs
		JOIN JSON_TABLE(REPLACE(JSON_ARRAY(rs.SuspiciousTransList), ',', '","'), 
							'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
							) js
    WHERE	rs.CustID = ip_CustID	
		AND rs.PeriodRangeType = ip_PeriodRangeType 
        AND rs.MatchID = ip_MatchID;		
END$$

DELIMITER ;
