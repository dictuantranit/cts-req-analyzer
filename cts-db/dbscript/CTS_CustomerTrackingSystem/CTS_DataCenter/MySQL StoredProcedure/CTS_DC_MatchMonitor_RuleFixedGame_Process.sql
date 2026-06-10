/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleFixedGame_Process`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleFixedGame_Process`(
		IN ip_LiveIndicator		BOOLEAN
	,	IN ip_MaxSequenceID		BIGINT UNSIGNED
	,	IN ip_MatchID			INT UNSIGNED
    ,	IN ip_ScoreDiff			INT 
    ,	IN ip_BettypeID			INT UNSIGNED    
    ,	IN ip_BetID				BIGINT
    ,	IN ip_HDP				DECIMAL (8,4)
    ,	IN ip_Betteam			VARCHAR(50)
)   
    SQL SECURITY INVOKER
sp: BEGIN
		/*
		Created:	20210526@Casey.Huynh
		Task :		Match Monitor Rule
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20220726@Casey.Huynh: 	Created [Redmine ID: #175700]
			- 20220726@Casey.Huynh: 	Handle Duaration in 7 SECOND [Redmine ID: #177139]
			- 20220815@Casey.Huynh: 	Scale Out DB [Redmine ID: #176472]
			- 20221023@Casey.Huynh: 	Adjust Odds Range Rule, fix Data Type HighStake, Get Trans >= lv_FromTransDate for Non-Live [Redmine ID: #179065]
			- 20221227@Casey.Huynh: 	Rename Table and Tunning Performance [Redmine ID: #181205, #181914]
			- 20230112@Casey.Huynh: 	Fix issue not return full TransID [Redmine ID: #182814]
			- 20230206@Victoria.Le:		Change formula for OddsSpread [Redmine ID: #183277]
			- 20230602@Long.Luu:		Change formula for OddsSpread [Redmine ID: #189072]
        
		Param's Explanation (filtered by):	

		Example:
			CALL CTS_DC_MatchMonitor_RuleFixedGame_Process(@ip_LiveIndicator:=0,@ip_MaxSequenceID:=@op_MaxSequenceID,@ip_MatchID:=110100,@ip_ScoreDiff:=-2,@ip_BettypeID:=1,@ip_BetID:=0, @HDP:=-0.2500, @ip_Betteam:='h');
	*/
    DECLARE CONS_LOG 						TINYINT DEFAULT 0; #0:LogOff,1:LogOn
    DECLARE	CONST_RULE_GROUPID_FIXEDGAME 	TINYINT DEFAULT 2;
	
    DECLARE	lv_SportType					INT;
    DECLARE	lv_IsMajorLeague				BOOLEAN;
    DECLARE lv_MaxSequenceID 				BIGINT UNSIGNED;
    DECLARE lv_MaxTransDate 				DATETIME(3);
	DECLARE lv_LastTransDate 				DATETIME(3);
    DECLARE lv_FromTransDate 				BIGINT UNSIGNED;
    DECLARE lv_LastSequenceID 				BIGINT UNSIGNED;
    
    DECLARE	lv_Rule_TotalTicket				SMALLINT; 
    DECLARE	lv_Rule_HighStake				SMALLINT;
    DECLARE	lv_Rule_HighStakeTicketPercent	DECIMAL(6,2);    
	DECLARE	lv_Rule_TimeStep				INT; 
    DECLARE	lv_Rule_OddsSpread				DECIMAL(4,2);
    DECLARE	lv_Rule_Reason					INT;
	
    #============DEBUG LOG============================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_RuleFixedGame_Process';
    IF CONS_LOG = 1 THEN 
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(),CONCAT('ip_LiveIndicator:',ip_LiveIndicator,',ip_MaxSequenceID:',ip_MaxSequenceID
			,',ip_MatchID:',ip_MatchID,',ip_ScoreDiff:',ip_ScoreDiff,',ip_BettypeID:',ip_BettypeID,',ip_BetID:',ip_BetID,',ip_HDP:',ip_HDP,',ip_Betteam:',ip_Betteam); 
	END IF;
    #================================================================================
    
    DROP TEMPORARY TABLE IF EXISTS Temp_FixedTransRange;
    CREATE TEMPORARY TABLE Temp_FixedTransRange(
			TimeToSecond	BIGINT UNSIGNED
		,	MinSequenceID	BIGINT UNSIGNED
        ,	MaxSequenceID	BIGINT	UNSIGNED
        
        ,	PRIMARY KEY Temp_FixedTransRange(TimeToSecond)
	);   
    
    #===GET RULE FROM SystemParameter=====
     DROP TEMPORARY TABLE IF EXISTS Temp_Trans;
        CREATE TEMPORARY TABLE Temp_Trans(
				TimeToSecond	BIGINT UNSIGNED	
			,	TransDate		DATETIME(3)
            ,	TransID			BIGINT UNSIGNED
            ,	SequenceID		BIGINT UNSIGNED
            ,	CustID			BIGINT
            , 	Stake			DECIMAL(20,4)
            ,	Odds			DECIMAL(10,4)
			,	SignNumber		TINYINT
            ,	PRIMARY KEY (TimeToSecond, SequenceID, TransID, CustID)
            
        );
        
        DROP TEMPORARY TABLE IF EXISTS Temp_MatchMonitorGroupInSecond;
        CREATE TEMPORARY TABLE Temp_MatchMonitorGroupInSecond(				
            	TimeToSecond		BIGINT UNSIGNED
            ,	TotalTicket			INT
            , 	TotalHighStake		DECIMAL(20,4)
            ,	MinOdds				DECIMAL(10,4)
            ,	MaxOdds				DECIMAL(10,4)
            ,	MinNegativeOdds		DECIMAL(10,4)
            ,	MinPositiveOdds		DECIMAL(10,4)
            ,	MinSequenceID		BIGINT UNSIGNED
            ,	MaxSequenceID		BIGINT UNSIGNED 
			,	MinSignNumber		TINYINT
			,	MaxSignNumber		TINYINT
            ,	PRIMARY KEY (TimeToSecond)
        );    
        
        DROP TEMPORARY TABLE IF EXISTS Temp_MatchMonitorGroup;
        CREATE TEMPORARY TABLE Temp_MatchMonitorGroup(				
            	TimeToSecond		BIGINT UNSIGNED
            ,	TotalTicket			INT
            , 	TotalHighStake		DECIMAL(20,4)
            ,	MinOdds				DECIMAL(10,4)
            ,	MaxOdds				DECIMAL(10,4)
            ,	MinNegativeOdds		DECIMAL(10,4)
            ,	MinPositiveOdds		DECIMAL(10,4)
            ,	MinSequenceID		BIGINT UNSIGNED
            ,	MaxSequenceID		BIGINT UNSIGNED 
			,	MinSignNumber		TINYINT
			,	MaxSignNumber		TINYINT
            ,	PRIMARY KEY (TimeToSecond)
        );  
    
    
    IF (ip_LiveIndicator = 1) THEN
        
        SELECT s.ParameterValue
        INTO lv_LastSequenceID
        FROM CTS_DataCenter.SystemParameter AS s
        WHERE s.ParameterID = 100;        
        
		SELECT mms.SportType, mms.IsMajorLeague
		INTO lv_SportType, lv_IsMajorLeague
		FROM CTS_DataCenter.MatchMonitorStagingFixedGameLive AS mms
		WHERE mms.SequenceID > lv_LastSequenceID AND mms.MatchID = ip_MatchID
        LIMIT 1;   
        
		SELECT mst.TimeStep, mst.TotalTicket, mst.HighStake, mst.HighStakeTicketPercent, mst.OddsSpread, mst.Reason
        INTO lv_Rule_TimeStep, lv_Rule_TotalTicket, lv_Rule_HighStake, lv_Rule_HighStakeTicketPercent, lv_Rule_OddsSpread, lv_Rule_Reason  
        FROM CTS_DataCenter.MatchMonitorRuleSetting AS mst
        WHERE mst.SportType = lv_SportType AND mst.RuleGroupID = CONST_RULE_GROUPID_FIXEDGAME AND mst.RuleStatus = 1;     
        
        SELECT TO_SECONDS(TIMESTAMPADD(SECOND, lv_Rule_TimeStep, TransDate))
        INTO lv_FromTransDate
        FROM CTS_DataCenter.MatchMonitorStagingFixedGameLive AS mmt
		WHERE mmt.MatchID = ip_MatchID AND mmt.ScoreDiff = ip_ScoreDiff AND mmt.BettypeID = ip_BettypeID 
        AND mmt.BetID = ip_BetID AND mmt.Betteam = ip_Betteam AND mmt.Hdp = ip_HDP
		ORDER BY TransDate
        LIMIT 1;        
       
		INSERT INTO Temp_Trans(TimeToSecond, TransID, SequenceID, CustID, Stake, Odds, SignNumber)
        SELECT 	TO_SECONDS(TransDate) AS TimeToSecond
			,	mms.TransID
			,	mms.SequenceID
            ,	mms.CustID
			,	mms.Stake
			,	mms.Odds
			,	SIGN(mms.Odds) AS SignNumber
        FROM CTS_DataCenter.MatchMonitorStagingFixedGameLive AS mms
        WHERE mms.MatchID = ip_MatchID AND mms.ScoreDiff = ip_ScoreDiff AND mms.BettypeID = ip_BettypeID AND mms.BetID = ip_BetID AND mms.Betteam = ip_Betteam AND mms.Hdp = ip_HDP AND mms.SequenceID <= ip_MaxSequenceID;
	END IF; 
 
    IF (ip_LiveIndicator = 0) THEN
        SELECT s.ParameterValue
        INTO lv_LastSequenceID
        FROM CTS_DataCenter.SystemParameter AS s
        WHERE s.ParameterID = 101;        
        
		SELECT mms.SportType, mms.IsMajorLeague
		INTO lv_SportType, lv_IsMajorLeague
		FROM CTS_DataCenter.MatchMonitorStagingFixedGameNonLive AS mms
		WHERE mms.SequenceID > lv_LastSequenceID AND mms.MatchID = ip_MatchID
        LIMIT 1;   
        
		SELECT mst.TimeStep, mst.TotalTicket, mst.HighStake, mst.HighStakeTicketPercent, mst.OddsSpread, mst.Reason
        INTO lv_Rule_TimeStep, lv_Rule_TotalTicket, lv_Rule_HighStake, lv_Rule_HighStakeTicketPercent, lv_Rule_OddsSpread, lv_Rule_Reason  
        FROM CTS_DataCenter.MatchMonitorRuleSetting AS mst
        WHERE mst.SportType = lv_SportType AND mst.RuleGroupID = CONST_RULE_GROUPID_FIXEDGAME AND mst.RuleStatus = 1;     
        
        SELECT TO_SECONDS(TIMESTAMPADD(SECOND, lv_Rule_TimeStep, TransDate))
        INTO lv_FromTransDate
        FROM CTS_DataCenter.MatchMonitorStagingFixedGameNonLive AS mmt
		WHERE mmt.MatchID = ip_MatchID AND mmt.ScoreDiff = ip_ScoreDiff AND mmt.BettypeID = ip_BettypeID 
        AND mmt.BetID = ip_BetID AND mmt.Betteam = ip_Betteam AND mmt.Hdp = ip_HDP
		ORDER BY TransDate
        LIMIT 1;        
       
		INSERT INTO Temp_Trans(TimeToSecond, TransID, SequenceID, CustID, Stake, Odds, SignNumber)
        SELECT 	TO_SECONDS(TransDate) AS TimeToSecond
			,	mms.TransID
			,	mms.SequenceID
            ,	mms.CustID
			,	mms.Stake
			,	mms.Odds
			,	SIGN(mms.Odds) AS SignNumber
        FROM CTS_DataCenter.MatchMonitorStagingFixedGameNonLive AS mms
        WHERE mms.MatchID = ip_MatchID AND mms.ScoreDiff = ip_ScoreDiff AND mms.BettypeID = ip_BettypeID AND mms.BetID = ip_BetID AND mms.Betteam = ip_Betteam AND mms.Hdp = ip_HDP AND mms.SequenceID <= ip_MaxSequenceID;
	
	END IF;

	INSERT INTO Temp_MatchMonitorGroupInSecond(TimeToSecond, TotalTicket, TotalHighStake, MinOdds, MaxOdds, MinNegativeOdds, MinPositiveOdds, MinSequenceID, MaxSequenceID, MinSignNumber, MaxSignNumber)
	SELECT	tmpTs.TimeToSecond
		,	COUNT(1) AS TotalTicket
		,	SUM(CASE WHEN tmpTs.Stake >= lv_Rule_HighStake THEN 1 ELSE 0 END) AS TotalHighStake
		,	MIN(tmpTs.Odds) AS MinOdds
		,	MAX(tmpTs.Odds) AS MaxOdds
		,	MIN(CASE WHEN SIGN(tmpTs.Odds) = -1 THEN tmpTs.Odds ELSE 0 END) AS MinNegativeOdds
		,	MIN(CASE WHEN SIGN(tmpTs.Odds) = 1 THEN tmpTs.Odds ELSE 999999 END) AS MinPositiveOdds
		,	MIN(SequenceID) AS MinSequenceID
		,	MAX(SequenceID) AS MaxSequenceID
		,	MIN(tmpTs.SignNumber) AS MinSignNumber
		,	MAX(tmpTs.SignNumber) AS MaxSignNumber
	FROM Temp_Trans AS tmpTs
	GROUP BY tmpTs.TimeToSecond;
    
    SET  @sqlString = CONCAT('
    INSERT INTO Temp_MatchMonitorGroup(TimeToSecond, TotalTicket, TotalHighStake, MinOdds, MaxOdds, MinNegativeOdds, MinPositiveOdds, MinSequenceID, MinSignNumber, MaxSignNumber, MaxSequenceID)
    SELECT  tmpMg.TimeToSecond
		,	SUM(tmpMg.TotalTicket)   OVER w1  AS TotalTrans                
		,	SUM(tmpMg.TotalHighStake)   OVER w1  AS TotalHighStake				
		,	MIN(tmpMg.MinOdds) OVER w1  AS MinOdds
		, 	MAX(tmpMg.MaxOdds) OVER w1  AS MaxOdds			
		,	MIN(tmpMg.MinNegativeOdds) OVER w1  AS MinNegativeOdds
		, 	MIN(tmpMg.MinPositiveOdds) OVER w1  AS MinPositiveOdds
		,	MIN(tmpMg.MinSequenceID) OVER w1  AS MinSequenceID
		,	MIN(tmpMg.MinSignNumber) OVER w1 AS MinSignNumber
		,	MAX(tmpMg.MaxSignNumber) OVER w1 AS MaxSignNumber
		,	tmpMg.MaxSequenceID	
	FROM Temp_MatchMonitorGroupInSecond AS tmpMg
	WINDOW w1 AS (ORDER BY TimeToSecond DESC RANGE BETWEEN CURRENT ROW AND  ',lv_Rule_TimeStep,'  FOLLOWING)');
	  
    PREPARE stmt1 FROM @sqlString;

	EXECUTE stmt1;

	# The same sign
	INSERT INTO Temp_FixedTransRange (TimeToSecond,MinSequenceID, MaxSequenceID)
	SELECT	tmpMg.TimeToSecond
		,	tmpMg.MinSequenceID
        ,	tmpMg.MaxSequenceID
	FROM	Temp_MatchMonitorGroup AS tmpMg
	WHERE tmpMg.TotalTicket > lv_Rule_TotalTicket
		AND (tmpMg.TotalHighStake/tmpMg.TotalTicket) > lv_Rule_HighStakeTicketPercent 
		AND ABS(ABS(tmpMg.MaxOdds) - ABS(tmpMg.MinOdds))*100 >= lv_Rule_OddsSpread
		AND tmpMg.TimeToSecond >= lv_FromTransDate
		AND tmpMg.MinSignNumber = tmpMg.MaxSignNumber;
		
	# The different sign
	INSERT INTO Temp_FixedTransRange (TimeToSecond,MinSequenceID, MaxSequenceID)
	SELECT	tmpMg.TimeToSecond
		,	tmpMg.MinSequenceID
        ,	tmpMg.MaxSequenceID
	FROM	Temp_MatchMonitorGroup AS tmpMg
	WHERE tmpMg.TotalTicket > lv_Rule_TotalTicket
		AND (tmpMg.TotalHighStake/tmpMg.TotalTicket) > lv_Rule_HighStakeTicketPercent 
		AND ((1-ABS(tmpMg.MinNegativeOdds))+(1-ABS(tmpMg.MinPositiveOdds)))*100 >= lv_Rule_OddsSpread
		AND tmpMg.TimeToSecond >= lv_FromTransDate
		AND tmpMg.MinSignNumber != tmpMg.MaxSignNumber;

	SELECT lv_Rule_Reason AS Reason
		,	tmp.TransIDList
		,	tmp.CustIDList
	FROM (
			SELECT  GROUP_CONCAT(DISTINCT TransID) AS TransIDList
				,	GROUP_CONCAT(DISTINCT CustID) AS CustIDList
			FROM Temp_Trans AS tmpTs
				INNER JOIN Temp_FixedTransRange AS tmpFt ON tmpTs.SequenceID BETWEEN tmpFt.MinSequenceID and  tmpFt.MaxSequenceID
			) AS tmp
	WHERE tmp.TransIDList IS NOT NULL;	
 
END$$
DELIMITER ;

