/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleArbitrage_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleArbitrage_Get`(
		IN	ip_LiveIndicator	BOOLEAN
	,	OUT	op_MaxSequenceID	BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	202212216@Casey.Huynh
		Task :		Match Monitor Arbitrage Rule
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	202212216@Casey.Huynh: Created [Redmine ID: 179502]
            - 	20240617@Casey.Huynh: Renovate Arbitrage Rule [Redmine ID: #203319]
            
		Param's Explanation (filtered by):	

		Example:
			CALL  CTS_DC_MatchMonitor_RuleArbitrage_Get_casey(@ip_LiveIndicator:=0,@op_MaxSequenceID);
            SELECT * FROM SystemParameter WHERE ParameterID = 128
            Create table MatchMonitorStagingArbitrageNonLive_Casey SELECT * FROM MatchMonitorStagingArbitrageNonLive
	*/
    DECLARE CONST_LOG					TINYINT DEFAULT 0; #0:LogOff, 1:LogOn
    DECLARE CONST_MMRULEGROUP_ARBITRAGE	INT DEFAULT 5;
    DECLARE CONST_SUBSCRIBERID_ALPHA	INT DEFAULT 168;
	DECLARE CONST_SUBSCRIBERID_MAXBET	INT DEFAULT 169;
    DECLARE CONST_MMREASON_ARBITRAGE	INT DEFAULT 2;
    
	DECLARE lv_LastSequenceID	BIGINT UNSIGNED DEFAULT 0;
    DECLARE lv_MaxSequenceID	BIGINT UNSIGNED DEFAULT 0;
	DECLARE lv_MaxTime			BIGINT;
    DECLARE lv_Rule_TimeStep	SMALLINT;
    DECLARE lv_NoOfRow			INT DEFAULT 5000;
    
    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_RuleArbitrage_Get';
    IF CONST_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), CONCAT('@ip_LiveIndicator:=',ip_LiveIndicator);
    END IF;
    #==================LOG======================================================= 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_OldGroup;
	CREATE TEMPORARY TABLE Temp_OldGroup(
			MatchID			INT NOT NULL		
		,	ScoreDiff		INT NOT NULL
		,	BettypeID		INT NOT NULL
		,	BetID			BIGINT NOT NULL
		,	HDP				DECIMAL(8,4) NOT NULL
		,	GroupID			INT NOT NULL
	
		,	PRIMARY KEY PK_Temp_OldGroup(MatchID, ScoreDiff, BettypeID, BetID, HDP, GroupID)
	);
    
    #===============================================================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_CustStake;
    CREATE TEMPORARY TABLE Temp_CustStake(
			IsMajorLeague BOOLEAN
		,	CustStake DECIMAL(20,4)
	);
    
	INSERT INTO Temp_CustStake(IsMajorLeague, CustStake)
    SELECT 	DISTINCT
			s.LeagueType
		,	s.CustStake
    FROM	CTS_DataCenter.MatchMonitorRuleSetting AS s
    WHERE	s.RuleGroupID = CONST_MMRULEGROUP_ARBITRAGE 
		AND s.Reason = CONST_MMREASON_ARBITRAGE 
        AND s.RuleStatus = 1;   

	SELECT	s.TimeStep
    INTO	lv_Rule_TimeStep
    FROM	CTS_DataCenter.MatchMonitorRuleSetting AS s
    WHERE	s.RuleGroupID = CONST_MMRULEGROUP_ARBITRAGE AND s.Reason = CONST_MMREASON_ARBITRAGE AND s.RuleStatus=1 
    LIMIT	1;
    
    SELECT s.ParameterValue
    INTO lv_NoOfRow
    FROM CTS_DataCenter.SystemParameter AS s
    WHERE s.ParameterID = 129;

	IF ip_LiveIndicator = 0 THEN #=============Live Trans==================

		SELECT sys.ParameterValue
        INTO lv_LastSequenceID
        FROM CTS_DataCenter.SystemParameter AS sys
        WHERE ParameterID = 128;      

		INSERT INTO Temp_OldGroup(MatchID, ScoreDiff, BettypeID, BetID, HDP, GroupID)
        SELECT	mms.MatchID
			,	mms.ScoreDiff
            ,	mms.BettypeID
            ,	mms.BetID
            ,	mms.HDP
            ,	mms.GroupID
        FROM CTS_DataCenter.MatchMonitorStagingArbitrageNonLive AS mms
		WHERE mms.SequenceID <= lv_LastSequenceID AND mms.GroupID > 0
        GROUP BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.HDP, mms.GroupID
        HAVING COUNT(DISTINCT mms.CustID) > 1 
					AND COUNT(DISTINCT mms.Betteam) = 2;
                      
        #==========Get Next Trans In TimeStep==================       
        SELECT mms.TransDateToSecond + lv_Rule_TimeStep
        INTO lv_MaxTime
        FROM CTS_DataCenter.MatchMonitorStagingArbitrageNonLive AS mms
        WHERE mms.SequenceID >= lv_LastSequenceID
        ORDER BY mms.SequenceID ASC
        LIMIT 1;        

		SELECT mms.SequenceID
        INTO lv_MaxSequenceID
		FROM CTS_DataCenter.MatchMonitorStagingArbitrageNonLive AS mms 
		WHERE mms.TransDateToSecond <= lv_MaxTime 
			AND mms.SequenceID > lv_LastSequenceID
		ORDER BY mms.SequenceID DESC
		LIMIT 1;

        IF(lv_LastSequenceID < lv_MaxSequenceID) THEN # If Has New Trans   
				            
            SELECT tmp.MatchID, MIN(tmp.SportType) AS SportType, MIN(tmp.IsMajorLeague) AS IsMajorLeague , tmp.ScoreDiff, tmp.BettypeID, tmp.BetID, tmp.HDP
				, GROUP_CONCAT(tmp.CTSCustID)  AS CTSCustIDList
				, CASE WHEN COUNT(DISTINCT tmp.Agent_CTSCustID) > 0 THEN GROUP_CONCAT(tmp.Agent_CTSCustID) ELSE NULL END AS AgentDetect_CTSCustIDList
				, GROUP_CONCAT(tmp.SequenceIDList)  AS SequenceIDList				
			FROM (SELECT	mms.MatchID
						,	MIN(mms.SportType) AS SportType
						,	MIN(mms.IsMajorLeague) AS IsMajorLeague
						,	mms.ScoreDiff
						,	mms.BettypeID
						,	mms.BetID
						,	mms.HDP
                        ,	tmpOg.GroupID
						,	MIN(mms.Betteam) AS MinBetteam
                        ,	MAX(mms.Betteam) AS MaxBetteam
						,	mms.CTSCustID
						,	CASE WHEN mms.SubscriberID IN (CONST_SUBSCRIBERID_ALPHA,CONST_SUBSCRIBERID_MAXBET) THEN mms.CTSCustID ELSE NULL END AS Agent_CTSCustID
						,	GROUP_CONCAT(mms.SequenceID) AS SequenceIDList
				FROM CTS_DataCenter.MatchMonitorStagingArbitrageNonLive AS mms
					INNER JOIN Temp_CustStake AS tmpTs ON tmpTs.IsMajorLeague = mms.IsMajorLeague
					LEFT JOIN Temp_OldGroup AS tmpOg ON mms.MatchID = tmpOg.MatchID AND mms.ScoreDiff = tmpOg.ScoreDiff AND mms.BettypeID = tmpOg.BettypeID
														AND mms.BetID = tmpOg.BetID AND mms.HDP = tmpOg.HDP	AND (mms.GroupID = tmpOg.GroupID OR mms.GroupID = 0)
				WHERE mms.SequenceID <= lv_MaxSequenceID 
				GROUP BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.HDP, tmpOg.GroupID, mms.CTSCustID, mms.SubscriberID, tmpTs.CustStake
                HAVING SUM(mms.Stake) >= tmpTs.CustStake
				) AS tmp
			GROUP BY tmp.MatchID, tmp.ScoreDiff, tmp.BettypeID, tmp.BetID, tmp.HDP, tmp.GroupID
            HAVING COUNT(DISTINCT tmp.CTSCustID) > 1 AND MIN(tmp.MinBetteam) <> MAX(tmp.MaxBetteam)
			ORDER BY tmp.MatchID, tmp.ScoreDiff, tmp.BettypeID, tmp.BetID, tmp.HDP, tmp.GroupID;
            
            SET op_MaxSequenceID = lv_MaxSequenceID ;
            
		ELSE # Get Next Trans > 1 minute to Clear Trans
			SET op_MaxSequenceID = (SELECT mms.SequenceID 
									FROM CTS_DataCenter.MatchMonitorStagingArbitrageNonLive AS mms
									WHERE mms.SequenceID > lv_LastSequenceID
									ORDER BY mms.SequenceID ASC
									LIMIT 1);
		END IF;
        
	END IF;
 
END$$
DELIMITER ;
