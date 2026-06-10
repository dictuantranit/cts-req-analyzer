/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleGroupBettingSaba_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleGroupBettingSaba_Get`(
		IN	ip_LiveIndicator	BOOLEAN
	,	OUT	op_MaxSequenceID	BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20240603@Casey.Huynh
		Task :		Match Monitor - Group Betting Saba - Get
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20240603@Casey.Huynh: Created [Redmine ID: #191972]
            -	20240704@Casey.Huynh: Saba Group Betting - Add Basketball and enhance Soccer [Redmine ID: #207523]
            
		Param's Explanation (filtered by):			
		
		Example:
			CALL CTS_DC_MatchMonitor_RuleGroupBettingSaba_Get(@ip_LiveIndicator:=1,@op_MaxSequenceID)
	*/
 
    DECLARE CONST_LOG							TINYINT DEFAULT 0; #0:LogOff, 1:LogOn
    DECLARE CONST_MMRULEGROUP_GROUPBETTINGSABA	INT DEFAULT 6;
    DECLARE CONST_MMREASON_GROUPBETTINGSABA		INT DEFAULT 0;
    
	DECLARE lv_LastSequenceID	BIGINT UNSIGNED DEFAULT 0;
    DECLARE lv_MaxSequenceID	BIGINT UNSIGNED DEFAULT 0;
	DECLARE lv_MaxTime			BIGINT;
    DECLARE lv_Rule_TimeStep	SMALLINT;
    DECLARE lv_NoOfRow			INT DEFAULT 5000;
    
    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_RuleGroupBettingSaba_Get';
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
		,	Betteam			VARCHAR(10) NOT NULL
		,	GroupID			INT NOT NULL
		
		,	PRIMARY KEY PK_Temp_OldGroup(MatchID,ScoreDiff,BettypeID,BetID,Betteam, GroupID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_RuleSetting;
	CREATE TEMPORARY TABLE Temp_RuleSetting(
			LeagueGroupID	INT NOT NULL
		,	Sporttype		INT NOT NULL		
		,	TotalStake		DECIMAL(20,4) NOT NULL
        ,	CustStake		DECIMAL(20,4) NOT NULL
        
		,	PRIMARY KEY PK_Sporttype_LeagueGroupIDSporttype(LeagueGroupID, Sporttype)
	);
    
    #===============================================================================================
	SELECT	s.TimeStep
    INTO	lv_Rule_TimeStep
    FROM	CTS_DataCenter.MatchMonitorRuleSetting AS s
    WHERE	s.RuleGroupID = CONST_MMRULEGROUP_GROUPBETTINGSABA AND s.Reason = CONST_MMREASON_GROUPBETTINGSABA AND s.RuleStatus=1 
    LIMIT	1;

    SELECT s.ParameterValue
    INTO lv_NoOfRow
    FROM CTS_DataCenter.SystemParameter AS s
    WHERE s.ParameterID = 164;
	
    INSERT INTO Temp_RuleSetting(LeagueGroupID, Sporttype, TotalStake, CustStake)
    SELECT	st.LeagueGroupID
		,	st.Sporttype
        ,	st.TotalStake
        ,	st.CustStake
    FROM CTS_DataCenter.MatchMonitorRuleSetting AS st
    WHERE	st.RuleGroupID = CONST_MMRULEGROUP_GROUPBETTINGSABA AND st.Reason = CONST_MMREASON_GROUPBETTINGSABA AND st.RuleStatus = 1;
    
	IF ip_LiveIndicator = 1 THEN #=============Live Trans==================
		
		SELECT sys.ParameterValue
        INTO lv_LastSequenceID
        FROM CTS_DataCenter.SystemParameter AS sys
        WHERE ParameterID = 162;      

		INSERT INTO Temp_OldGroup(MatchID, ScoreDiff, BettypeID, BetID, Betteam, GroupID)
        SELECT	mms.MatchID
			,	mms.ScoreDiff
            ,	mms.BettypeID
            ,	mms.BetID
            ,	mms.Betteam
            ,	mms.GroupID
        FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaLive AS mms
		WHERE mms.SequenceID <= lv_LastSequenceID AND mms.GroupID > 0
        GROUP BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.GroupID;  
                            
        #==========Get Next Trans In TimeStep==================       
        SELECT mms.TransDateToSecond + lv_Rule_TimeStep
        INTO lv_MaxTime
        FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaLive AS mms
        WHERE mms.SequenceID >= lv_LastSequenceID
        ORDER BY mms.SequenceID ASC
        LIMIT 1;        

		SELECT mms.SequenceID
        INTO lv_MaxSequenceID
		FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaLive AS mms 
		WHERE mms.TransDateToSecond <= lv_MaxTime 
			AND mms.SequenceID > lv_LastSequenceID
		ORDER BY mms.SequenceID DESC
		LIMIT 1;

        IF(lv_LastSequenceID < lv_MaxSequenceID) THEN # If Has New Trans   
		
			SELECT	tmp.MatchID
				,	tmp.SportType
				,	tmp.ScoreDiff
				,	tmp.BettypeID
				,	tmp.BetID
				,	tmp.Betteam                
                ,	GROUP_CONCAT(DISTINCT tmp.CustID) AS CustIDList
                ,	GROUP_CONCAT(DISTINCT tmp.CTSCustID) AS CTSCustIDList
				,	GROUP_CONCAT(tmp.CustSequenceIDList) AS SequenceIDList
            FROM (    
					SELECT	mms.MatchID
						,	mms.SportType
						,	mms.ScoreDiff
						,	mms.BettypeID
						,	mms.BetID
						,	mms.Betteam                
						,	mms.CustID
						,	mms.CTSCustID
						,	tmpOg.GroupID                        
						,	tmpSt.TotalStake
                        ,	SUM(mms.Stake) AS CustStake
						,	GROUP_CONCAT(mms.SequenceID) AS CustSequenceIDList
					FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaLive AS mms
						INNER JOIN Temp_RuleSetting AS tmpSt ON tmpSt.LeagueGroupID = mms.LeagueGroupID AND tmpSt.SportType = mms.SportType
						LEFT JOIN Temp_OldGroup AS tmpOg ON mms.MatchID = tmpOg.MatchID AND mms.ScoreDiff = tmpOg.ScoreDiff AND mms.BettypeID = tmpOg.BettypeID
															AND mms.BetID = tmpOg.BetID AND mms.Betteam = tmpOg.Betteam
															AND (mms.GroupID = tmpOg.GroupID OR mms.GroupID = 0)
					WHERE mms.SequenceID <= lv_MaxSequenceID
					GROUP BY mms.MatchID, mms.SportType, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.CustID, mms.CTSCustID, tmpOg.GroupID, tmpSt.TotalStake, tmpSt.CustStake
					HAVING SUM(mms.Stake) >= tmpSt.CustStake 
				) AS tmp
            GROUP BY tmp.MatchID, tmp.SportType, tmp.ScoreDiff, tmp.BettypeID, tmp.BetID, tmp.Betteam, tmp.GroupID, tmp.TotalStake              
			HAVING COUNT(DISTINCT tmp.CustID) > 1
				AND SUM(tmp.CustStake) >= tmp.TotalStake 
			ORDER BY tmp.MatchID, tmp.ScoreDiff, tmp.BettypeID, tmp.BetID, tmp.Betteam, tmp.GroupID;
			
            SELECT DISTINCT CustID, CTSCustID
            FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaLive AS mms
            WHERE mms.SequenceID <= lv_MaxSequenceID;
            
            SET op_MaxSequenceID = lv_MaxSequenceID ;
            
		ELSE # Get Next Trans > Steptime to Clear Trans
			SET op_MaxSequenceID = (SELECT mms.SequenceID 
									FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaLive AS mms
									WHERE mms.SequenceID > lv_LastSequenceID
									ORDER BY mms.SequenceID ASC
									LIMIT 1);
		END IF;      
        
	ELSE #=============NON Live Trans==================
    
		SELECT sys.ParameterValue
        INTO lv_LastSequenceID
        FROM CTS_DataCenter.SystemParameter AS sys
        WHERE ParameterID = 163;      

		INSERT INTO Temp_OldGroup(MatchID, ScoreDiff, BettypeID, BetID, Betteam, GroupID)
        SELECT	mms.MatchID
			,	mms.ScoreDiff
            ,	mms.BettypeID
            ,	mms.BetID
            ,	mms.Betteam
            ,	mms.GroupID
        FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaNonLive AS mms
		WHERE mms.SequenceID <= lv_LastSequenceID AND mms.GroupID > 0
        GROUP BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.GroupID;  
                            
        #==========Get Next Trans In TimeStep==================       
        SELECT mms.TransDateToSecond + lv_Rule_TimeStep
        INTO lv_MaxTime
        FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaNonLive AS mms
        WHERE mms.SequenceID >= lv_LastSequenceID
        ORDER BY mms.SequenceID ASC
        LIMIT 1;        

		SELECT mms.SequenceID
        INTO lv_MaxSequenceID
		FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaNonLive AS mms 
		WHERE mms.TransDateToSecond <= lv_MaxTime 
			AND mms.SequenceID > lv_LastSequenceID
		ORDER BY mms.SequenceID DESC
		LIMIT 1;

        IF(lv_LastSequenceID < lv_MaxSequenceID) THEN # If Has New Trans  
        
				SELECT	tmp.MatchID
				,	tmp.SportType
				,	tmp.ScoreDiff
				,	tmp.BettypeID
				,	tmp.BetID
				,	tmp.Betteam                
                ,	GROUP_CONCAT(DISTINCT tmp.CustID) AS CustIDList
                ,	GROUP_CONCAT(DISTINCT tmp.CTSCustID) AS CTSCustIDList
				,	GROUP_CONCAT(tmp.CustSequenceIDList) AS SequenceIDList
            FROM (    
					SELECT	mms.MatchID
						,	mms.SportType
						,	mms.ScoreDiff
						,	mms.BettypeID
						,	mms.BetID
						,	mms.Betteam                
						,	mms.CustID
						,	mms.CTSCustID
						,	tmpOg.GroupID                        
						,	tmpSt.TotalStake
                        ,	SUM(mms.Stake) AS CustStake
						,	GROUP_CONCAT(mms.SequenceID) AS CustSequenceIDList
					FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaNonLive AS mms
						INNER JOIN Temp_RuleSetting AS tmpSt ON tmpSt.LeagueGroupID = mms.LeagueGroupID AND tmpSt.SportType = mms.SportType
						LEFT JOIN Temp_OldGroup AS tmpOg ON mms.MatchID = tmpOg.MatchID AND mms.ScoreDiff = tmpOg.ScoreDiff AND mms.BettypeID = tmpOg.BettypeID
															AND mms.BetID = tmpOg.BetID AND mms.Betteam = tmpOg.Betteam
															AND (mms.GroupID = tmpOg.GroupID OR mms.GroupID = 0)
					WHERE mms.SequenceID <= lv_MaxSequenceID
					GROUP BY mms.MatchID, mms.SportType, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.CustID, mms.CTSCustID, tmpOg.GroupID, tmpSt.TotalStake, tmpSt.CustStake
					HAVING SUM(mms.Stake) >= tmpSt.CustStake 
				) AS tmp
            GROUP BY tmp.MatchID, tmp.SportType, tmp.ScoreDiff, tmp.BettypeID, tmp.BetID, tmp.Betteam, tmp.GroupID, tmp.TotalStake              
			HAVING COUNT(DISTINCT tmp.CustID) > 1
				AND SUM(tmp.CustStake) >= tmp.TotalStake 
			ORDER BY tmp.MatchID, tmp.ScoreDiff, tmp.BettypeID, tmp.BetID, tmp.Betteam, tmp.GroupID;
			
            SELECT DISTINCT CustID, CTSCustID
            FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaNonLive AS mms
            WHERE mms.SequenceID <= lv_MaxSequenceID;
            
            SET op_MaxSequenceID = lv_MaxSequenceID ;
            
		ELSE # Get Next Trans >  Steptime to Clear Trans
			SET op_MaxSequenceID = (SELECT mms.SequenceID 
									FROM CTS_DataCenter.MatchMonitorStagingGroupBettingSabaNonLive AS mms
									WHERE mms.SequenceID > lv_LastSequenceID
									ORDER BY mms.SequenceID ASC
									LIMIT 1);
		END IF;
        
	END IF;
 
END$$
DELIMITER ;
