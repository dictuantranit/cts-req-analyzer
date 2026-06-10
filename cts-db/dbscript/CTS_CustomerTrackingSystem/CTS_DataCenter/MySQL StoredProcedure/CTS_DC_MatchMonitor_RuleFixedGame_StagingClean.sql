/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleFixedGame_StagingClean`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleFixedGame_StagingClean`(
		IN ip_LiveIndicator	BOOLEAN
	,	IN ip_MaxSequenceID	BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210526@Casey.Huynh
		Task :		Match Monitor Rule
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20220726@Casey.Huynh: Created [Redmine ID: #175700]
            - 20220815@Casey.Huynh: Scale Out DB [Redmine ID: #176472]
            - 20221205@Casey.Huynh: Rename Table [Redmine ID: #181205]
            
		Param's Explanation (filtered by):
			CALL CTS_DC_MatchMonitor_RuleFixedGame_StagingClean(1,2);
		Example:
			
	*/
    DECLARE CONS_LOG 						TINYINT DEFAULT 0; #0:LogOff, 1:LogOn
	DECLARE	CONST_RULE_GROUPID_FIXEDGAME 	TINYINT DEFAULT 2;
    
    DECLARE	lv_Rule_TimeStep 		INT;   
    DECLARE	lv_ClearTransDate 		DATETIME; 
    
	#============DEBUG LOG============================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_RuleFixedGame_StagingClean';
    IF CONS_LOG = 1 THEN
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(),CONCAT('ip_LiveIndicator:',ip_LiveIndicator,',ip_MaxSequenceID:',ip_MaxSequenceID); 
	END IF;
    #================================================================================
    
    SELECT MAX(mst.TimeStep)
	INTO lv_Rule_TimeStep 
	FROM CTS_DataCenter.MatchMonitorRuleSetting AS mst
	WHERE mst.RuleGroupID = CONST_RULE_GROUPID_FIXEDGAME AND mst.RuleStatus = 1;  
	
    #======Clean Staging=================================================
    IF (ip_LiveIndicator = 1) THEN
		
        SELECT  TIMESTAMPADD(SECOND,-lv_Rule_TimeStep, TransDate)
		INTO 	lv_ClearTransDate
		FROM	CTS_DataCenter.MatchMonitorStagingFixedGameLive AS mmt
		WHERE	mmt.SequenceID = ip_MaxSequenceID; 	
                    
		DELETE 	mmt
		FROM	CTS_DataCenter.MatchMonitorStagingFixedGameLive AS mmt
		WHERE	mmt.SequenceID <= ip_MaxSequenceID AND mmt.TransDate < lv_ClearTransDate;
		
		UPDATE 	CTS_DataCenter.SystemParameter AS sys
		SET 	sys.ParameterValue = ip_MaxSequenceID
		WHERE 	sys.ParameterID = 100;
    END IF;    
    
	IF (ip_LiveIndicator = 0) THEN		
		
		SELECT  TIMESTAMPADD(SECOND,-lv_Rule_TimeStep, TransDate)
		INTO 	lv_ClearTransDate
		FROM	CTS_DataCenter.MatchMonitorStagingFixedGameNonLive AS mmt
		WHERE	mmt.SequenceID = ip_MaxSequenceID; 	   
                    
		DELETE 	mmt
		FROM	CTS_DataCenter.MatchMonitorStagingFixedGameNonLive AS mmt
		WHERE	mmt.SequenceID <= ip_MaxSequenceID AND mmt.TransDate < lv_ClearTransDate;
		
		UPDATE 	CTS_DataCenter.SystemParameter AS sys
		SET 	sys.ParameterValue = ip_MaxSequenceID
		WHERE 	sys.ParameterID = 101;
    END IF;    
    
    
END$$
DELIMITER ;
