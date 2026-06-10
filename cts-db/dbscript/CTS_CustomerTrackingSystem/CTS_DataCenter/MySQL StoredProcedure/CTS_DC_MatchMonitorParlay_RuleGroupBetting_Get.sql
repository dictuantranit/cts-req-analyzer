/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Get`(
		IN	ip_LiveIndicator	BOOLEAN
	,	OUT	op_MaxSequenceID	BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20240826@Casey.Huynh
		Task :		Match Monitor Rule - Get
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20240826@Casey.Huynh: Created [Redmine ID: 207397]
            
		Param's Explanation (filtered by):
        
		Example:
			CALL CTS_DC_MatchMonitorParlay_RuleGroupBetting_Get(@ip_LiveIndicator:=0,@op_MaxSequenceID); SELECT @op_MaxSequenceID;
            
	*/
    DECLARE CONST_LOG								TINYINT DEFAULT 0; #0:LogOff, 1:LogOn
    DECLARE CONST_MMRULEGROUP_GROUPBETTINGPARLAY	INT DEFAULT 7;
    DECLARE CONST_MMREASON_GROUPBETTINGPARLAY		INT DEFAULT 5;
    DECLARE CONST_LASTSEQUENCE_SYSPARAMETERID_LIVE		INT DEFAULT 173;
    DECLARE CONST_LASTSEQUENCE_SYSPARAMETERID_NONLIVE	INT DEFAULT 174;
    
	DECLARE lv_LastSequenceID	BIGINT UNSIGNED DEFAULT 0;
    DECLARE lv_MaxSequenceID	BIGINT UNSIGNED DEFAULT 0;
	DECLARE lv_MaxTime			BIGINT;
    DECLARE lv_Rule_TimeStep	SMALLINT;
    
    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitorParlay_RuleGroupBetting_Get';
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
    
    #===============================================================================================   
   
	SELECT	s.TimeStep
    INTO	lv_Rule_TimeStep
    FROM	CTS_DataCenter.MatchMonitorRuleSetting AS s
    WHERE	s.RuleGroupID = CONST_MMRULEGROUP_GROUPBETTINGPARLAY
		AND s.Reason = CONST_MMREASON_GROUPBETTINGPARLAY 
        AND s.RuleStatus=1 
    LIMIT	1;

	IF ip_LiveIndicator = 1 THEN #=============Live Trans==================
		
		SELECT sys.ParameterValue
        INTO lv_LastSequenceID
        FROM CTS_DataCenter.SystemParameter AS sys
        WHERE ParameterID = CONST_LASTSEQUENCE_SYSPARAMETERID_LIVE;      

		INSERT INTO Temp_OldGroup(MatchID, ScoreDiff, BettypeID, BetID, Betteam, GroupID)
        SELECT	mms.MatchID
			,	mms.ScoreDiff
            ,	mms.BettypeID
            ,	mms.BetID
            ,	mms.Betteam
            ,	mms.GroupID
        FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingLive AS mms
		WHERE mms.SequenceID <= lv_LastSequenceID AND mms.GroupID > 0
        GROUP BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.GroupID;  
                            
        #==========Get Next Trans In TimeStep==================       
        SELECT mms.TransDateToSecond + lv_Rule_TimeStep
        INTO lv_MaxTime
        FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingLive AS mms
        WHERE mms.SequenceID >= lv_LastSequenceID
        ORDER BY mms.SequenceID ASC
        LIMIT 1;        
	
		SELECT mms.SequenceID
        INTO lv_MaxSequenceID
		FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingLive AS mms 
		WHERE mms.TransDateToSecond <= lv_MaxTime 
			AND mms.SequenceID > lv_LastSequenceID
		ORDER BY mms.SequenceID DESC
		LIMIT 1;

        IF(lv_LastSequenceID < lv_MaxSequenceID) THEN # If Has New Trans   

			SELECT	mms.MatchID
                ,	MIN(mms.SportType) AS SportType
				,	mms.ScoreDiff
				,	mms.BettypeID
				,	mms.BetID
				,	mms.Betteam
				,	GROUP_CONCAT(DISTINCT mms.CustID) AS CustIDList
                ,	GROUP_CONCAT(DISTINCT mms.CTSCustID) AS CTSCustIDList
                ,	GROUP_CONCAT(mms.TransIDm) AS TransIDmList
			FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingLive AS mms
				LEFT JOIN Temp_OldGroup AS tmpOg ON mms.MatchID = tmpOg.MatchID AND mms.ScoreDiff = tmpOg.ScoreDiff AND mms.BettypeID = tmpOg.BettypeID
													AND mms.BetID = tmpOg.BetID AND mms.Betteam = tmpOg.Betteam
													AND (mms.GroupID = tmpOg.GroupID OR mms.GroupID = 0)
			WHERE mms.SequenceID <= lv_MaxSequenceID            
			GROUP BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, tmpOg.GroupID
            HAVING COUNT(DISTINCT CustID) > 1
			ORDER BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, tmpOg.GroupID;
            
            SET op_MaxSequenceID = lv_MaxSequenceID ;
            
		ELSE # Get Next Trans > 3 minute to Clear Trans
			SET op_MaxSequenceID = (SELECT mms.SequenceID 
									FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingLive AS mms
									WHERE mms.SequenceID > lv_LastSequenceID
									ORDER BY mms.SequenceID ASC
									LIMIT 1);
		END IF;      
        
	ELSE #=============NON Live Trans==================
    
		SELECT sys.ParameterValue
        INTO lv_LastSequenceID
        FROM CTS_DataCenter.SystemParameter AS sys
        WHERE ParameterID = CONST_LASTSEQUENCE_SYSPARAMETERID_NONLIVE;      
        
		INSERT INTO Temp_OldGroup(MatchID, ScoreDiff, BettypeID, BetID, Betteam, GroupID)
        SELECT	mms.MatchID
			,	mms.ScoreDiff
            ,	mms.BettypeID
            ,	mms.BetID
            ,	mms.Betteam
            ,	mms.GroupID
        FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingNonLive AS mms
		WHERE mms.SequenceID <= lv_LastSequenceID AND mms.GroupID > 0
        GROUP BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.GroupID;  
                            
        #==========Get Next Trans In TimeStep==================       
        SELECT mms.TransDateToSecond + lv_Rule_TimeStep
        INTO lv_MaxTime
        FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingNonLive AS mms
        WHERE mms.SequenceID >= lv_LastSequenceID
        ORDER BY mms.SequenceID ASC
        LIMIT 1;
        
		SELECT mms.SequenceID
        INTO lv_MaxSequenceID
		FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingNonLive AS mms 
		WHERE mms.TransDateToSecond <= lv_MaxTime 
			AND mms.SequenceID > lv_LastSequenceID
		ORDER BY mms.SequenceID DESC
		LIMIT 1;

        IF(lv_LastSequenceID < lv_MaxSequenceID) THEN # If Has New Trans   

			SELECT	mms.MatchID				
                ,	MIN(mms.SportType) AS SportType
				,	mms.ScoreDiff
				,	mms.BettypeID
				,	mms.BetID
				,	mms.Betteam
                ,	GROUP_CONCAT(DISTINCT mms.CustID) AS CustIDList
                ,	GROUP_CONCAT(DISTINCT mms.CTSCustID) AS CTSCustIDList
				,	GROUP_CONCAT(mms.TransIDm) AS TransIDmList
			FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingNonLive AS mms
				LEFT JOIN Temp_OldGroup AS tmpOg ON mms.MatchID = tmpOg.MatchID AND mms.ScoreDiff = tmpOg.ScoreDiff AND mms.BettypeID = tmpOg.BettypeID
													AND mms.BetID = tmpOg.BetID AND mms.Betteam = tmpOg.Betteam
													AND (mms.GroupID = tmpOg.GroupID OR mms.GroupID = 0)
			WHERE mms.SequenceID <= lv_MaxSequenceID 
			GROUP BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, tmpOg.GroupID
            HAVING COUNT(DISTINCT CustID) > 1
			ORDER BY mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, tmpOg.GroupID;
			           
            SET op_MaxSequenceID = lv_MaxSequenceID ;
            
		ELSE # Get Next Trans > 1 minute to Clear Trans
			SET op_MaxSequenceID = (SELECT mms.SequenceID 
						FROM CTS_DataCenter.MatchMonitorParlayStagingGroupBettingNonLive AS mms
						WHERE mms.SequenceID > lv_LastSequenceID
						ORDER BY mms.SequenceID ASC
						LIMIT 1);
		END IF;
        
	END IF;
 
END$$
DELIMITER ;
