
DROP PROCEDURE IF EXISTS `SPU_AIML_RD_SCE_GetRobotUsersDetails`;

DELIMITER $$
CREATE DEFINER=`AIMLOwner`@`%` PROCEDURE `SPU_AIML_RD_SCE_GetRobotUsersDetails`(
		IN 	ip_CustID	 			BIGINT UNSIGNED    
    ,	IN 	ip_RobotTypeOrigin		SMALLINT UNSIGNED
    ,	IN 	ip_RobotTypeDisplay		SMALLINT UNSIGNED
    ,	IN 	ip_ClusterID			SMALLINT UNSIGNED
    ,	IN 	ip_ScannedDate			TIMESTAMP(3)    
    ,	IN 	ip_QueryType			SMALLINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20221027@Long.Luu
		Task:		Get SCE Robot Detection Detailed Info [Redmine ID: #179498]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20221027@Long.Luu: Created [Redmine ID: #179498]
        
        Param Explaination:
			- ip_QueryType: 1 - robot detailed info; 2 - robot tickets detailed
            
		Example:
			call SPU_AIML.SPU_AIML_RD_SCE_GetRobotUsersDetails (1,100,100,1,null,1);     
	*/ 
    
    DECLARE CONST_ROBOTTYPE_LONGBETDURATION 		SMALLINT DEFAULT 100;
	DECLARE	CONST_ROBOTTYPE_UGLYSTAKECHANGED 		SMALLINT DEFAULT 101;
    DECLARE lv_last30DaysFrom 	DATE;
    
    SET lv_last30DaysFrom = DATE_ADD(NOW(), INTERVAL -30 DAY);  
    
    IF (ip_RobotTypeOrigin = CONST_ROBOTTYPE_LONGBETDURATION) THEN
		IF (ip_QueryType = 1) THEN
			SELECT 	CustID
					, 	CONST_ROBOTTYPE_LONGBETDURATION AS RobotTypeOrigin                
					, 	CONST_ROBOTTYPE_LONGBETDURATION AS RobotTypeDisplay
					, 	FirstTransDate
					, 	LastTransDate
					,	BetDuration
					,	MIN(DoubtfulClusterID) AS ClusterID
					,	BetCount
					,	0 AS TotalBetCount
					,	MAX(CreatedDate) AS CreatedDate
				FROM SPU_AIML.RD_SCE_LongBetDurationStats
				WHERE CustID = ip_CustID 
					AND CreatedDate >= lv_last30DaysFrom
					AND RobotType = ip_RobotTypeOrigin
				GROUP BY CustID
					, 	FirstTransDate
					, 	LastTransDate
					,	BetDuration
					,	BetCount;
		ELSE
			SELECT 	CustID
				, 	RobotType AS RobotTypeDisplay
                ,	CreatedDate
                ,	TransList
			FROM SPU_AIML.RD_SCE_LongBetDurationStats
			WHERE CustID = ip_CustID 
                AND CreatedDate = ip_ScannedDate
                AND RobotType = ip_RobotTypeDisplay
                AND DoubtfulClusterID = ip_ClusterID;
        END IF;
    ELSEIF (ip_RobotTypeOrigin = CONST_ROBOTTYPE_UGLYSTAKECHANGED) THEN
		IF (ip_QueryType = 1) THEN
			WITH cte_UglyStakeChanged AS (  
				SELECT 	CustID
					,	UglyStakeCount AS BetCount
					,	BetCount AS TotalBetCount
					,	CreatedDate
				FROM SPU_AIML.RD_SCE_UglyStakeChangedStats            
				WHERE CustID = ip_CustID 
					AND CreatedDate >= lv_last30DaysFrom
			)  
			SELECT 	l.CustID
				, 	CONST_ROBOTTYPE_UGLYSTAKECHANGED AS RobotTypeOrigin                
				, 	CONST_ROBOTTYPE_LONGBETDURATION AS RobotTypeDisplay
				, 	l.FirstTransDate
				, 	l.LastTransDate
				,	l.BetDuration
                ,	MIN(l.DoubtfulClusterID) AS ClusterID
				,	l.BetCount
                ,	0 AS TotalBetCount
                ,	MAX(l.CreatedDate) AS CreatedDate
			FROM cte_UglyStakeChanged AS c
				INNER JOIN SPU_AIML.RD_SCE_LongBetDurationStats AS l ON c.CustID = l.CustID AND c.CreatedDate = l.CreatedDate
			WHERE l.RobotType = ip_RobotTypeOrigin
            GROUP BY l.CustID
				, 	l.FirstTransDate
				, 	l.LastTransDate
				,	l.BetDuration
				,	l.BetCount
            UNION
            SELECT 	CustID
				, 	CONST_ROBOTTYPE_UGLYSTAKECHANGED AS RobotTypeOrigin                
				, 	CONST_ROBOTTYPE_UGLYSTAKECHANGED AS RobotTypeDisplay
                ,	NULL AS FirstTransDate
                ,	NULL AS LastTransDate
                ,	0 AS BetDuration
                ,	0 AS ClusterID
                ,	BetCount
                ,	TotalBetCount
                ,	CreatedDate
            FROM cte_UglyStakeChanged;
		ELSE
			IF (ip_RobotTypeDisplay = CONST_ROBOTTYPE_UGLYSTAKECHANGED) THEN
				SELECT 	CustID
					, 	CONST_ROBOTTYPE_UGLYSTAKECHANGED AS RobotTypeDisplay
					,	CreatedDate
					,	TransList
				FROM SPU_AIML.RD_SCE_UglyStakeChangedStats
				WHERE CustID = ip_CustID 
					AND CreatedDate = ip_ScannedDate;
			ELSE #IF  (ip_RobotTypeDisplay = CONST_ROBOTTYPE_LONGBETDURATION) THEN
				SELECT 	CustID
					, 	CONST_ROBOTTYPE_LONGBETDURATION AS RobotTypeDisplay
					,	CreatedDate
					,	TransList
				FROM SPU_AIML.RD_SCE_LongBetDurationStats
				WHERE CustID = ip_CustID 
					AND CreatedDate = ip_ScannedDate
					AND RobotType = CONST_ROBOTTYPE_UGLYSTAKECHANGED
					AND DoubtfulClusterID = ip_ClusterID;
            END IF;
        END IF;
    END IF;
END$$

DELIMITER ;
