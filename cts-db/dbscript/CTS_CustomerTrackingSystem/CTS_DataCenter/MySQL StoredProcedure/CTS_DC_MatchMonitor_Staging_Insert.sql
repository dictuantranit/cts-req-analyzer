/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_Staging_Insert`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_Staging_Insert`(
		IN ip_LiveIndicator	BOOLEAN
	,	IN ip_PoolType		INT
    ,	IN ip_TransList 	JSON
    
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20210526@Casey.Huynh
		Task :		Match Monitor Insert trans ticket to Staging table
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20210526@Casey.Huynh: Created [Redmine ID: 152883]
            -	20210719@Casey.Huynh: Fix Issue Rule Trans.StepTime and AssGroup [Redmine ID: 158946]
            -	20210823@Casey.Huynh: Seperate scan for Live and NonLive [Redmine ID: 159195]
            -	20211213@Casey.Huynh: Enhance MM, Add column LeagueName [Redmine ID: 165606]
            -	20220110@Casey.Huynh: Enhance MM, Add SportType, Betteam, BetID [Redmine ID: 166986]
            - 	20220726@Casey.Huynh: Fixed Game [Redmine ID: #175700]
            - 	20220830@Casey.Huynh: New Category for Classify Group Betting [Redmine ID: #176976]
			-	20220815@Casey.Huynh: Scale Out DB [Redmine ID: #176472]
            -	20221021@Casey.Huynh: Fixed Clean Data Staging [Redmine ID: #179427]
            - 	202201021@Casey.Huynh: Seperate pool Staging [Redmine ID: #179439]
            - 	20221115@Casey.Huynh: Detect Irrgation Rule [Redmine ID: #179499]
            - 	20221206@Casey.Huynh: Change Table Nane, ScoreDiff and add HDP, Odds range for Fixed Game [Redmine ID: #181205]
			- 	20221228@Victoria.Le: Add HDP for Irrgation Rule [Redmine ID: #181990]
			-	20230203@Victoria.Le: Change Odds Range for Fixed Game Rule - Malayisan Odds [Redmine ID: #183277]
            -	20231120@Casey.Huynh: E-Sport GB support New Bettypes, change setting table [Redmine ID: #196396]
            -	20240109@Casey.Huynh: Enhance Hedging Rule, execlute Licensee Cust and Limit stake [Redmine ID: #192172]
            -	20240509@Casey.Huynh: HF Hedging StepTime, Add column TransDateToSecond [Redmine ID: #204338]
            -	20240530@Casey.Huynh: Saba Group Betting [Redmine ID: #191972]
            -	20240417@Casey.Huynh: Renovate Arbitrage Rule [Redmine ID: #203639]
            -	20240417@Casey.Huynh: Renovate GroupBetting Rule [Redmine ID: #203319]
			-	20240704@Casey.Huynh: Saba Group Betting - Add Basketball and enhance Soccer [Redmine ID: #207523]
            -	20250213@Thomas.Nguyen: Set ScoreDiff = 0, BetID = 0 to only group by Match, bettype, bet team, live indicator for Cricket [Redmine ID: #217745]
			-	20250314@Thomas.Nguyen: Set LiveHomeScore, LiveAwayScore, ScoreDiff = 0 to not group by ScoreDiff for Badminton and get only settings of MM [Redmine ID: #219681]
			-	20250414@Casey.Huynh: Match Monitor Table Tennis Child Match [Redmine ID: #221510]
            - 	20250527@Casey.Huynh: Detect Volleyball Group Betting(Bettype 704,705,219,220) [Redmine ID: #226408]
            - 	20250610@Casey.Huynh: Detect Tennis Group Betting(Bettype 153,154,155,156) [Redmine ID: #229855]
			- 	20250718@Logan.Nguyen: Saba Group Betting - Classify Saba Soccer Group Betting into CC3101-3201 [Redmine ID: #227848]
			-	20250808@Logan.Nguyen: 	Match Monitor Group Betting - Cricket [Redmine ID: #235043]
            
		Param's Explanation (filtered by):		
			ip_PoolType: 
            LIVE:
				1001: MatchMonitorStagingGroupBettingLive               
				1002: MatchMonitorStagingGroupBettingSabaLive                
				1003: MatchMonitorStagingHedgingLive               
				1004: MatchMonitorStagingFixedGameLive
			NON-LIVE:			 
				2001: MatchMonitorStagingGroupBettingNonLive
				2002: MatchMonitorStagingGroupBettingSabaNonLive
				2003: MatchMonitorStagingHedgingNonLive
				2004: MatchMonitorStagingArbitrageNonLive
				2005: MatchMonitorStagingFixedGameNonLive
				2006: MatchMonitorStagingIrrigationNonLive

		Example:
			CALL CTS_DataCenter.CTS_DC_MatchMonitor_Staging_Insert(
              @ip_LiveIndicator:=1
            , @ip_PoolType:=1002
            , @ip_TransList:='[{"SportType": 1,"SequenceID": 1003,"IsMajorLeague": 0,"TransID": 1003,"TransDate" : "2021-05-17 07:48:52.533","MatchID" : 43614953,"EventDate" : "2021-05-17 00:00:00","KickOffTime" : "2021-05-17 00:00:00","EventStatus" : "running","HomeID" : 953,"AwayID" : 113,"LeagueID" : 3,"Bettype" : 3, "BetID" : 0,  "LiveIndicator" : "1","CustID" : 12500792,"Stake" : 20,"Betteam" : "a", "Odds" : "0.1","LiveHomeScore" : 0,"LiveAwayScore" : 2,"LeagueName":"ABC League"}]'
            );
			
	*/
    DECLARE CONST_LOG 						TINYINT DEFAULT 0; #0:LogOff, 1:LogOn
    
	DECLARE CONST_RULE_GROUPID_GROUPBETTING	INT DEFAULT 1;
    DECLARE CONST_RULE_GROUPID_FIXEDGAME	INT DEFAULT 2;
    DECLARE CONST_RULE_GROUPID_HEDGING		INT DEFAULT 3;
    DECLARE CONST_RULE_GROUPID_IRRIGATION	INT DEFAULT 4;
    DECLARE CONST_RULE_GROUPID_ARBITRAGE	INT DEFAULT 5;
    DECLARE CONST_RULE_GROUPID_GROUPBETTINGSABA	INT DEFAULT 6;
    
    DECLARE CONST_SPORTTYPE_BASKETBALL			INT DEFAULT 2;
	DECLARE CONST_SPORTTYPE_BADMINTON			INT DEFAULT 9;
	DECLARE CONST_SPORTTYPE_CRICKET				INT DEFAULT 50;
    DECLARE CONST_SPORTTYPE_TABLETENNIS			INT DEFAULT 18;
    DECLARE CONST_SPORTTYPE_VOLLEYBALL			INT DEFAULT 6;
    DECLARE CONST_SPORTTYPE_TENNIS				INT DEFAULT 5;
    
	DECLARE CONST_FUNCTIONID_MATCHMONITOR		INT DEFAULT 1;

    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_Staging_Insert';
    IF CONST_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), CONCAT('@ip_LiveIndicator:=',ip_LiveIndicator,'@ip_PoolType:=',ip_PoolType);
    END IF;
    #==================LOG=======================================================   

    DROP TEMPORARY TABLE IF EXISTS Temp_Staging;
	CREATE TEMPORARY TABLE Temp_Staging(
			SequenceID		BIGINT UNSIGNED NOT NULL
		,	SportType		INT NOT NULL
        ,	IsMajorLeague	BOOLEAN NOT NULL
        ,	Odds			DECIMAL(10,4) NOT NULL
		,	TransID			BIGINT UNSIGNED NOT NULL
		,	TransDate		DATETIME(3) NULL
		,	MatchID			INT NULL		
		,	ScoreDiff		INT NULL
		,	BettypeID		INT NULL
		,	BetID			BIGINT DEFAULT 0
		,	Betteam			VARCHAR(10) NULL        
		,	CustID			BIGINT UNSIGNED NULL
		,	Stake			DECIMAL(20,4) NULL
		,	GroupID			INT DEFAULT '0'
		,	LiveHomeScore	INT NULL
		,	LiveAwayScore	INT NULL
		,	EventDate		DATE NULL
		,	KickOffTime		DATETIME NULL
		,	EventStatus		VARCHAR(50) NULL
		,	HomeID			INT NULL
		,	AwayID			INT NULL
		,	LeagueID		INT NULL
		,	LeagueName		VARCHAR(500) NULL        
        ,	HDP				DECIMAL(8,4) NULL
        ,	Hdp1			DECIMAL(8,4) NULL
        ,	Hdp2			DECIMAL(8,4) NULL
        ,	LeagueGroupID	INT
		,	PRIMARY KEY (SportType, IsMajorLeague, Odds, SequenceID)
		,	INDEX SequenceID(SequenceID)
	) ENGINE=InnoDB;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_MatchMonitorRuleSetting;
    CREATE TEMPORARY TABLE Temp_MatchMonitorRuleSetting(
			RuleGroupID TINYINT 
		,	LeagueGroupID INT
		,	SportType 	INT
        ,	BettypeID	INT
		,	LeagueType 	BOOLEAN
		,	MinOdds 	DECIMAL(10,4) 
		,	MaxOdds 	DECIMAL(10,4)
        ,	MinStake	DECIMAL(20,4) NULL
        
        ,	PRIMARY KEY PK_Temp_MatchMonitorRuleSetting(RuleGroupID, SportType, BettypeID, LeagueType)
        
	);

    INSERT INTO Temp_MatchMonitorRuleSetting(RuleGroupID, LeagueGroupID, SportType, BettypeID, LeagueType,  MinOdds, MaxOdds, MinStake)
    SELECT 	mst.RuleGroupID
		,	IFNULL(mst.LeagueGroupID,0)
		,	mst.SportType
        ,	tmp.BettypeID
		,	mst.LeagueType
		,	mst.MinOdds
        ,	mst.MaxOdds
        ,	mst.HighStake
    FROM (	SELECT sbs.SportTypeID, sbs.BetTypeID, sbs.LeagueGroupID, js.Reason
			FROM CTS_DataCenter.SportBettypeSetting AS sbs
			, JSON_TABLE(CONCAT('["', REPLACE(IFNULL(MMReason,''), ',', '","'), '"]'),
								  '$[*]' COLUMNS (Reason VARCHAR(2) PATH '$')) js
			WHERE sbs.FunctionID = CONST_FUNCTIONID_MATCHMONITOR) AS tmp
		 INNER JOIN CTS_DataCenter.MatchMonitorRuleSetting AS mst ON mst.SportType = tmp.SportTypeID AND mst.Reason = tmp.Reason AND tmp.LeagueGroupID = IFNULL(mst.LeagueGroupID,0); 

    INSERT IGNORE INTO Temp_Staging(SequenceID, TransID, TransDate, LeagueName, SportType, MatchID, HomeID, AwayID, EventStatus, KickOffTime, LeagueID, EventDate, LiveHomeScore, LiveAwayScore, ScoreDiff, BettypeID, BetID, CustID, Stake, Betteam, Odds, IsMajorLeague, HDP, Hdp1, Hdp2, LeagueGroupID)
		SELECT  js.SequenceID
			,	js.TransID
			,	js.TransDate
            ,	js.LeagueName
            ,	js.SportType
			,	js.MatchID
			,	js.HomeID
			,	js.AwayID
			,	js.EventStatus
			,	js.KickOffTime
			,	js.LeagueID
			,	js.EventDate
			,	(CASE WHEN js.SportType IN (CONST_SPORTTYPE_BASKETBALL, CONST_SPORTTYPE_CRICKET, CONST_SPORTTYPE_BADMINTON, CONST_SPORTTYPE_TABLETENNIS, CONST_SPORTTYPE_VOLLEYBALL, CONST_SPORTTYPE_TENNIS) THEN 0 ELSE js.LiveHomeScore END) AS LiveHomeScore
			,	(CASE WHEN js.SportType IN (CONST_SPORTTYPE_BASKETBALL, CONST_SPORTTYPE_CRICKET, CONST_SPORTTYPE_BADMINTON, CONST_SPORTTYPE_TABLETENNIS, CONST_SPORTTYPE_VOLLEYBALL, CONST_SPORTTYPE_TENNIS) THEN 0 ELSE js.LiveAwayScore END) AS LiveAwayScore
			,	(CASE WHEN js.SportType IN (CONST_SPORTTYPE_BASKETBALL, CONST_SPORTTYPE_CRICKET, CONST_SPORTTYPE_BADMINTON, CONST_SPORTTYPE_TABLETENNIS, CONST_SPORTTYPE_VOLLEYBALL, CONST_SPORTTYPE_TENNIS) THEN 0 ELSE (js.LiveHomeScore*10000) + js.LiveAwayScore END) AS ScoreDiff
			,	js.BettypeID
            ,	CASE 
    				WHEN js.SportType = CONST_SPORTTYPE_CRICKET 
         				AND js.BetTypeID  IN (501, 9404, 9405)
    				THEN 0 
    				ELSE IFNULL(js.BetID, 0) 
				END AS BetID
			,	js.CustID
			,	js.Stake
            ,	js.Betteam
            ,	js.Odds
            ,	js.IsMajorLeague
            ,	(js.Hdp1 - js.Hdp2) AS HDP
            ,	js.Hdp1
            ,	js.Hdp2
            ,	js.LeagueGroupID
		FROM JSON_TABLE(ip_TransList,
					 "$[*]" COLUMNS(
								SequenceID		BIGINT UNSIGNED PATH "$.SequenceID" 	
							,	TransID			BIGINT UNSIGNED PATH "$.TransID" 
							,	TransDate		DATETIME(3) PATH "$.TransDate" 
							,	LeagueName		VARCHAR(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci PATH "$.LeagueName"
							,	SportType		INT PATH "$.SportType"
							,	MatchID			INT PATH "$.MatchID"
							,	HomeID			INT	PATH "$.HomeID" 
							,	AwayID			INT	PATH "$.AwayID" 
							,	EventStatus		VARCHAR(50)	PATH "$.EventStatus" 
							,	KickOffTime		DATETIME PATH "$.KickOffTime" 
							,	LeagueID		INT	PATH "$.LeagueID"
							,	EventDate		DATE PATH "$.EventDate"
							,	LiveHomeScore	INT	PATH "$.LiveHomeScore" 
							,	LiveAwayScore	INT	PATH "$.LiveAwayScore" 
							,	BettypeID		INT	PATH "$.Bettype"
							,	BetID			BIGINT	PATH "$.BetID"
							,	CustID			INT PATH "$.CustID"
							,	Stake			DECIMAL(20,4) PATH "$.Stake" 
							,	Betteam			VARCHAR(10)	PATH "$.Betteam"
                            ,	Odds			DECIMAL(10,4) PATH "$.Odds"
                            ,	IsMajorLeague	BOOLEAN	PATH "$.IsMajorLeague" 
                            ,	Hdp1			DECIMAL(8,4) PATH "$.Hdp1" 
                            ,	Hdp2			DECIMAL(8,4) PATH "$.Hdp2"
                            ,	LeagueGroupID	INT PATH "$.LeagueGroupID"
						)
					) AS js;  

    IF ip_LiveIndicator = 1 THEN 
		#=====GROUP BETTING===================
		IF (ip_PoolType = 1001) THEN
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingGroupBettingLive(SequenceID, TransID, TransDate, TransDateToSecond, LeagueName, SportType, MatchID, HomeID, AwayID, EventStatus, KickOffTime, LeagueID, EventDate, LiveHomeScore, LiveAwayScore, ScoreDiff, BettypeID, BetID
			, CustID, CTSCustID, IsLicensee, Stake, Betteam, Odds, IsMajorLeague, Hdp1, Hdp2, HDP, InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
				,	UNIX_TIMESTAMP(tmpSt.TransDate) AS TransDateToSecond 
				,	tmpSt.LeagueName
				,	tmpSt.SportType
				,	tmpSt.MatchID
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.EventStatus
				,	tmpSt.KickOffTime
				,	tmpSt.LeagueID
				,	tmpSt.EventDate
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.CustID
				,	cus.CTSCustID
				, 	cus.IsLicensee
				,	tmpSt.Stake
				,	tmpSt.Betteam
				,	tmpSt.Odds
				,	tmpSt.IsMajorLeague            
				,	tmpSt.Hdp1
				,	tmpSt.Hdp2
				,	tmpSt.HDP
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpSt.CustID = cus.CustID
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_GROUPBETTING
																	AND tmpMst.SportType = tmpSt.SportType 
																	AND (tmpMst.LeagueType = 2 OR (tmpMst.LeagueType = tmpSt.IsMajorLeague))
																	AND tmpMst.BettypeID = tmpSt.BettypeID 
			WHERE tmpSt.LeagueGroupID IS NULL;
            
            LEAVE sp;
            
		END IF;
		
        #=====GROUP BETTING SABA===================
		IF (ip_PoolType = 1002) THEN
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingGroupBettingSabaLive(SequenceID, TransID, TransDate, TransDateToSecond, MatchID, SportType, ScoreDiff, BettypeID, BetID, Betteam, CustID, CTSCustID, Stake, GroupID, LiveHomeScore, LiveAwayScore, EventDate, KickOffTime, EventStatus, HomeID, AwayID, LeagueID, LeagueGroupID, LeagueName, InsertTime, IsLicensee)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
				,	UNIX_TIMESTAMP(tmpSt.TransDate) AS TransDateToSecond
				,	tmpSt.MatchID
				,	tmpSt.SportType
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.Betteam
				,	tmpSt.CustID
                ,	cus.CTSCustID
				,	tmpSt.Stake
				,	tmpSt.GroupID
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.EventDate
				,	tmpSt.KickOffTime
				,	tmpSt.EventStatus
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.LeagueID
                ,	tmpSt.LeagueGroupID
				,	tmpSt.LeagueName
				,	CURRENT_TIMESTAMP(3) AS InsertTime
				,	cus.IsLicensee
			FROM Temp_Staging AS tmpSt
				INNER JOIN CTS_DataCenter.CTSCustomer cus ON tmpSt.CustID = cus.CustID
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_GROUPBETTINGSABA 
																	  AND tmpMst.LeagueGroupID = tmpSt.LeagueGroupID
                                                                      AND tmpMst.SportType = tmpSt.SportType
				WHERE tmpSt.LeagueGroupID IS NOT NULL;

            LEAVE sp;
            
		END IF;

		#=====HEDGING================================
        IF (ip_PoolType = 1003) THEN
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingHedgingLive(SequenceID, TransID, TransDate, TransDateToSecond, LeagueName, SportType, MatchID, HomeID, AwayID, EventStatus, KickOffTime, LeagueID, EventDate, LiveHomeScore, LiveAwayScore, ScoreDiff, BettypeID, BetID, CustID
			, CTSCustID, SubscriberID, Stake, Betteam, InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
				,	UNIX_TIMESTAMP(tmpSt.TransDate) AS TransDateToSecond 
				,	tmpSt.LeagueName
				,	tmpSt.SportType
				,	tmpSt.MatchID
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.EventStatus
				,	tmpSt.KickOffTime
				,	tmpSt.LeagueID
				,	tmpSt.EventDate
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.CustID
				,	cus.CTSCustID 
				,	cus.SubscriberID
				,	tmpSt.Stake
				,	tmpSt.Betteam
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN CTS_DataCenter.CTSCustomer cus ON tmpSt.CustID = cus.CustID
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_HEDGING
																	AND tmpMst.SportType = tmpSt.SportType 
																	AND (tmpMst.LeagueType = 2 OR (tmpMst.LeagueType = tmpSt.IsMajorLeague))
																	AND tmpMst.BettypeID = tmpSt.BettypeID
			WHERE 	tmpSt.Stake >= tmpMst.MinStake 
				AND cus.IsLicensee = 0
				AND tmpSt.LeagueGroupID IS NULL;
            
            LEAVE sp;
                            
		END IF;
        
        #=====Staging Fixed Game Betting================================
        IF (ip_PoolType = 1004) THEN
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingFixedGameLive(SequenceID, TransID, TransDate, LeagueName, SportType, MatchID, HomeID, AwayID, EventStatus, KickOffTime, LeagueID, EventDate, LiveHomeScore, LiveAwayScore, ScoreDiff, BettypeID, BetID, CustID, Stake, Betteam, Odds, IsMajorLeague, Hdp1, Hdp2, HDP, InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
				,	tmpSt.LeagueName
				,	tmpSt.SportType
				,	tmpSt.MatchID
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.EventStatus
				,	tmpSt.KickOffTime
				,	tmpSt.LeagueID
				,	tmpSt.EventDate
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.CustID
				,	tmpSt.Stake
				,	tmpSt.Betteam
				,	tmpSt.Odds
				,	tmpSt.IsMajorLeague
				,	tmpSt.Hdp1
				,	tmpSt.Hdp2
				,	tmpSt.HDP
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_FIXEDGAME
							AND tmpMst.SportType = tmpSt.SportType AND (tmpMst.LeagueType = 2 OR (tmpMst.LeagueType = tmpSt.IsMajorLeague))
							AND tmpMst.BettypeID = tmpSt.BettypeID  
							AND ABS(tmpSt.Odds) >= tmpMst.MinOdds
			WHERE tmpSt.LeagueGroupID IS NULL;  
            
            LEAVE sp;
            		
		END IF;  
        
        LEAVE sp;		
    END IF; 
    
	IF ip_LiveIndicator = 0 THEN
        #=====GROUP BETTING===================
        IF (ip_PoolType = 2001) THEN
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingGroupBettingNonLive(SequenceID, TransID, TransDate, TransDateToSecond, LeagueName, SportType, MatchID, HomeID, AwayID, EventStatus, KickOffTime, LeagueID, EventDate, LiveHomeScore, LiveAwayScore, ScoreDiff, BettypeID, BetID
			, CustID, CTSCustID, IsLicensee, Stake, Betteam, Odds, IsMajorLeague, Hdp1, Hdp2, HDP, InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
				,	UNIX_TIMESTAMP(tmpSt.TransDate) AS TransDateToSecond 
				,	tmpSt.LeagueName
				,	tmpSt.SportType
				,	tmpSt.MatchID
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.EventStatus
				,	tmpSt.KickOffTime
				,	tmpSt.LeagueID
				,	tmpSt.EventDate
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.CustID
				,	cus.CTSCustID
				, 	cus.IsLicensee
				,	tmpSt.Stake
				,	tmpSt.Betteam
				,	tmpSt.Odds
				,	tmpSt.IsMajorLeague            
				,	tmpSt.Hdp1
				,	tmpSt.Hdp2
				,	tmpSt.HDP
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpSt.CustID = cus.CustID
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_GROUPBETTING
																	AND tmpMst.SportType = tmpSt.SportType 
																	AND (tmpMst.LeagueType = 2 OR (tmpMst.LeagueType = tmpSt.IsMajorLeague))
																	AND tmpMst.BettypeID = tmpSt.BettypeID		
			WHERE tmpSt.LeagueGroupID IS NULL;
			
			LEAVE sp;
            
        END IF;
        
		#=====GROUP BETTING SABA===================
		IF (ip_PoolType = 2002) THEN
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingGroupBettingSabaNonLive(SequenceID, TransID, TransDate, TransDateToSecond, MatchID, SportType, ScoreDiff, BettypeID, BetID, Betteam, CustID, CTSCustID, Stake, GroupID, LiveHomeScore, LiveAwayScore, EventDate, KickOffTime, EventStatus, HomeID, AwayID, LeagueID, LeagueGroupID, LeagueName, InsertTime, IsLicensee)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
				,	UNIX_TIMESTAMP(tmpSt.TransDate) AS TransDateToSecond
				,	tmpSt.MatchID
				,	tmpSt.SportType
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
                ,	tmpSt.BetID
				,	tmpSt.Betteam
				,	tmpSt.CustID
                ,	cus.CTSCustID
				,	tmpSt.Stake
				,	tmpSt.GroupID
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.EventDate
				,	tmpSt.KickOffTime
				,	tmpSt.EventStatus
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.LeagueID
                ,	tmpSt.LeagueGroupID
				,	tmpSt.LeagueName
				,	CURRENT_TIMESTAMP(3) AS InsertTime
				,	cus.IsLicensee
			FROM Temp_Staging AS tmpSt
				INNER JOIN CTS_DataCenter.CTSCustomer cus ON tmpSt.CustID = cus.CustID
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_GROUPBETTINGSABA 
																	  AND tmpMst.LeagueGroupID = tmpSt.LeagueGroupID
                                                                      AND tmpMst.SportType = tmpSt.SportType
            WHERE tmpSt.LeagueGroupID IS NOT NULL;

            LEAVE sp;
            
		END IF;

		#=====HEDGING================================
		IF (ip_PoolType = 2003) THEN	
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingHedgingNonLive(SequenceID, TransID, TransDate, TransDateToSecond, LeagueName, SportType, MatchID, HomeID, AwayID, EventStatus, KickOffTime, LeagueID, EventDate, LiveHomeScore, LiveAwayScore, ScoreDiff, BettypeID, BetID, CustID, CTSCustID, SubscriberID, Stake, Betteam, InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
				,	UNIX_TIMESTAMP(tmpSt.TransDate) AS TransDateToSecond 
				,	tmpSt.LeagueName
				,	tmpSt.SportType
				,	tmpSt.MatchID
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.EventStatus
				,	tmpSt.KickOffTime
				,	tmpSt.LeagueID
				,	tmpSt.EventDate
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.CustID
				,	cus.CTSCustID 
				,	cus.SubscriberID
				,	tmpSt.Stake
				,	tmpSt.Betteam
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN CTS_DataCenter.CTSCustomer cus ON tmpSt.CustID = cus.CustID
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_HEDGING
																	AND tmpMst.SportType = tmpSt.SportType 
																	AND (tmpMst.LeagueType = 2 OR (tmpMst.LeagueType = tmpSt.IsMajorLeague))
																	AND tmpMst.BettypeID = tmpSt.BettypeID
			WHERE	tmpSt.Stake >= tmpMst.MinStake 
				AND cus.IsLicensee = 0
				AND tmpSt.LeagueGroupID IS NULL; 
				
			LEAVE sp;
			
		END IF;    
        
		#=====ARBITRAGE================================
        IF (ip_PoolType = 2004) THEN        
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingArbitrageNonLive(SequenceID, TransID, TransDate, TransDateToSecond
            , LeagueName, SportType, MatchID, HomeID, AwayID, EventStatus, KickOffTime, LeagueID, EventDate, LiveHomeScore, LiveAwayScore
            , ScoreDiff, BettypeID, BetID, CustID, CTSCustID, SubscriberID, Stake, Betteam, IsMajorLeague, Hdp1, Hdp2, HDP, InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
                ,	UNIX_TIMESTAMP(tmpSt.TransDate) AS TransDateToSecond 
				,	tmpSt.LeagueName
				,	tmpSt.SportType
				,	tmpSt.MatchID
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.EventStatus
				,	tmpSt.KickOffTime
				,	tmpSt.LeagueID
				,	tmpSt.EventDate
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.CustID
                ,	cus.CTSCustID 
				,	cus.SubscriberID
				,	tmpSt.Stake
				,	tmpSt.Betteam
				,	tmpSt.IsMajorLeague
				,	tmpSt.Hdp1
				,	tmpSt.Hdp2
				,	tmpSt.HDP
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN CTS_DataCenter.CTSCustomer cus ON tmpSt.CustID = cus.CustID
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_ARBITRAGE
														AND tmpMst.SportType = tmpSt.SportType 
														AND (tmpMst.LeagueType = 2 OR (tmpMst.LeagueType = tmpSt.IsMajorLeague))
														AND tmpMst.BettypeID = tmpSt.BettypeID
			WHERE tmpSt.LeagueGroupID IS NULL;			
			LEAVE sp;
			
		END IF;  
        
        #=====FIXED GAME================================
        IF (ip_PoolType = 2005) THEN
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingFixedGameNonLive(SequenceID, TransID, TransDate, LeagueName, SportType, MatchID, HomeID, AwayID, EventStatus, KickOffTime, LeagueID, EventDate, LiveHomeScore, LiveAwayScore, ScoreDiff, BettypeID, BetID, CustID, Stake, Betteam, Odds, IsMajorLeague, Hdp1, Hdp2, HDP, InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
				,	tmpSt.LeagueName
				,	tmpSt.SportType
				,	tmpSt.MatchID
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.EventStatus
				,	tmpSt.KickOffTime
				,	tmpSt.LeagueID
				,	tmpSt.EventDate
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.CustID
				,	tmpSt.Stake
				,	tmpSt.Betteam
				,	tmpSt.Odds
				,	tmpSt.IsMajorLeague
				,	tmpSt.Hdp1
				,	tmpSt.Hdp2
				,	tmpSt.HDP
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_FIXEDGAME
														AND tmpMst.SportType = tmpSt.SportType 
														AND (tmpMst.LeagueType = 2 OR (tmpMst.LeagueType = tmpSt.IsMajorLeague))
														AND tmpMst.BettypeID = tmpSt.BettypeID
														AND ABS(tmpSt.Odds) >= tmpMst.MinOdds
			WHERE tmpSt.LeagueGroupID IS NULL; 
			
			LEAVE sp;           
		END IF;
        #=====IRRIGATION================================        
		IF (ip_PoolType = 2006) THEN
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorStagingIrrigationNonLive(SequenceID, TransID, TransDate, LeagueName, SportType, MatchID, HomeID, AwayID, EventStatus, KickOffTime, LeagueID, EventDate, LiveHomeScore, LiveAwayScore, ScoreDiff, BettypeID, BetID, CustID, Stake, Betteam, Odds, Hdp, InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.TransDate
				,	tmpSt.LeagueName
				,	tmpSt.SportType
				,	tmpSt.MatchID
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.EventStatus
				,	tmpSt.KickOffTime
				,	tmpSt.LeagueID
				,	tmpSt.EventDate
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.ScoreDiff
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.CustID
				,	tmpSt.Stake
				,	tmpSt.Betteam
				,	tmpSt.Odds
				,	tmpSt.HDP
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN Temp_MatchMonitorRuleSetting AS tmpMst ON  tmpMst.RuleGroupID = CONST_RULE_GROUPID_IRRIGATION
														AND tmpMst.SportType = tmpSt.SportType 
														AND (tmpMst.LeagueType = 2 OR (tmpMst.LeagueType = tmpSt.IsMajorLeague))
														AND tmpMst.BettypeID = tmpSt.BettypeID
			WHERE tmpSt.LeagueGroupID IS NULL; 
			
			LEAVE sp;
			
		END IF;     		
        
        LEAVE sp;		
	END IF;
    
END$$
DELIMITER ;
