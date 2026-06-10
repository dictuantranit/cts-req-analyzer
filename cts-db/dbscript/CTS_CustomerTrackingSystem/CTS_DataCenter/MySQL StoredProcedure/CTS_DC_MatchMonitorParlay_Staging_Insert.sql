/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitorParlay_Staging_Insert`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitorParlay_Staging_Insert`(
		IN ip_LiveIndicator	BOOLEAN
	,	IN ip_PoolType		INT
    ,	IN ip_TransList 	JSON
    
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20240823@Casey.Huynh
		Task :		Match Monitor Insert trans ticket to Staging table
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20240823@Casey.Huynh: Created [Redmine ID: 152883]
            
           
		Param's Explanation (filtered by):		
			ip_PoolType: 
            LIVE:
				1001: MatchMonitorParlayStagingGroupBettingLive       
			NON-LIVE:			 
				2001: MatchMonitorParlayStagingGroupBettingNonLive

		Example:
			CALL CTS_DataCenter.CTS_DC_MatchMonitorParlay_Staging_Insert(
              @ip_LiveIndicator:=0
            , @ip_PoolType:=2001
            , @ip_TransList:='[
					{"SequenceID":"119785519874","TransID":"288117431400923136","Refno":"1000000002348096671","TransIDm":"288117431400923140","TransDate":"2024-08-15 06:01:46.733","MatchID":"83673481","SportType":"1","LiveHomeScore":"56","LiveAwayScore":"55","BetTypeID":"3","BetID":"","BetTeam":"h","CustID":"3167530","EventDate":"2024-08-14 00:00:00.000","KickOffTime":"2024-08-14 06:03:00","EventStatus":"running","HomeID":"1975","AwayID":"18486","LeagueID":"7877","LeagueName":"*SVFG - BHYR"}
					,{"SequenceID":"119785519879","TransID":"288117452875759616","Refno":"1000000002348096721","TransIDm":"288117452875759621","TransDate":"2024-08-15 06:01:46.733","MatchID":"83673483","SportType":"2","LiveHomeScore":"73","LiveAwayScore":"76","BetTypeID":"3","BetID":"","BetTeam":"a","CustID":"3167530","EventDate":"2024-08-14 00:00:00.000","KickOffTime":"2024-08-14 06:03:00","EventStatus":"running","HomeID":"1975","AwayID":"18486","LeagueID":"78717","LeagueName":"*NBA - Number of Regular Season Wins"}
					,{"SequenceID":"119785519901","TransID":"288117560249942016","Refno":"1000000002348096941","TransIDm":"288117560249942019","TransDate":"2024-08-15 06:01:46.733","MatchID":"83673483","SportType":"2","LiveHomeScore":"13","LiveAwayScore":"17","BetTypeID":"1","BetID":"","BetTeam":"a","CustID":"3167530","EventDate":"2024-08-14 00:00:00.000","KickOffTime":"2024-08-14 06:03:00","EventStatus":"running","HomeID":"1975","AwayID":"18486","LeagueID":"78717","LeagueName":"*NBA - Number of Regular Season Wins"}
					,{"SequenceID":"119785519908","TransID":"288117594609680384","Refno":"1000000002348097011","TransIDm":"288117594609680389","TransDate":"2024-08-15 06:01:46.733","MatchID":"83673483","SportType":"2","LiveHomeScore":"25","LiveAwayScore":"25","BetTypeID":"609","BetID":"803","BetTeam":"h","CustID":"3167530","EventDate":"2024-08-14 00:00:00.000","KickOffTime":"2024-08-14 06:03:00","EventStatus":"running","HomeID":"1975","AwayID":"18486","LeagueID":"78717","LeagueName":"*NBA - Number of Regular Season Wins"}
					,{"SequenceID":"119785519932","TransID":"288117710573797376","Refno":"1000000002348097251","TransIDm":"288117710573797381","TransDate":"2024-08-15 06:01:46.733","MatchID":"83673483","SportType":"2","LiveHomeScore":"58","LiveAwayScore":"54","BetTypeID":"3","BetID":"","BetTeam":"h","CustID":"3167530","EventDate":"2024-08-14 00:00:00.000","KickOffTime":"2024-08-14 06:03:00","EventStatus":"running","HomeID":"1975","AwayID":"18486","LeagueID":"78717","LeagueName":"*NBA - Number of Regular Season Wins"}
				]'
            );		
            
            SELECT * FROM MatchMonitorParlayStagingGroupBettingNonLive;
	*/
    DECLARE CONST_LOG 							TINYINT DEFAULT 0; #0:LogOff, 1:LogOn
    
    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_StagingParlay_Insert';
    IF CONST_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), CONCAT('@ip_LiveIndicator:=',ip_LiveIndicator,'@ip_PoolType:=',ip_PoolType);
    END IF;
    #==================LOG=======================================================   

    DROP TEMPORARY TABLE IF EXISTS Temp_Staging;
	CREATE TEMPORARY TABLE Temp_Staging(
			SequenceID			BIGINT UNSIGNED NOT NULL
		,	TransID			BIGINT UNSIGNED NOT NULL
        ,	Refno				BIGINT UNSIGNED NOT NULL
		,	TransIDm				BIGINT UNSIGNED NOT NULL
        ,	TransDate			DATETIME(3) NOT NULL        
        ,	MatchID				INT NOT NULL
        ,	SportType			INT NOT NULL
        ,	LiveHomeScore		INT NOT NULL
        ,	LiveAwayScore		INT NOT NULL
		,	BettypeID			INT NOT NULL
        ,	BetID				BIGINT NOT NULL
        ,	Betteam				VARCHAR(10) NOT NULL 
        ,	CustID				BIGINT UNSIGNED NOT NULL
        ,	EventDate			DATE NULL
        ,	KickOffTime			DATETIME NULL
        ,	EventStatus			VARCHAR(50) NULL
        ,	HomeID				INT NOT NULL
		,	AwayID				INT NOT NULL
        ,	LeagueID			INT NOT NULL
        ,	LeagueName			VARCHAR(500) NOT NULL
	) ENGINE=InnoDB;

    INSERT IGNORE INTO Temp_Staging(SequenceID, TransID, Refno, TransIDm, TransDate, MatchID, SportType, LiveHomeScore, LiveAwayScore, BettypeID, BetID, Betteam
			, CustID, EventDate, KickOffTime, EventStatus, HomeID, AwayID, LeagueID, LeagueName)
	SELECT	js.SequenceID
		,	js.TransID
		,	js.Refno
		,	js.TransIDm
		,	js.TransDate
		,	js.MatchID
		,	js.SportType
		,	(CASE WHEN js.SportType = 2 THEN 0 ELSE js.LiveHomeScore END) AS LiveHomeScore
		,	(CASE WHEN js.SportType = 2 THEN 0 ELSE js.LiveAwayScore END) AS LiveAwayScore
		,	js.BettypeID
		,	(CASE WHEN js.BetID = '' THEN 0 ELSE js.BetID END) AS BetID
		,	js.Betteam
		,	js.CustID
		,	js.EventDate
		,	js.KickOffTime
		,	js.EventStatus
		,	js.HomeID
		,	js.AwayID
		,	js.LeagueID
		,	js.LeagueName
	FROM JSON_TABLE(ip_TransList,
		 "$[*]" COLUMNS(
					   SequenceID		BIGINT UNSIGNED PATH "$.SequenceID"
					 , TransID			BIGINT UNSIGNED PATH "$.TransID"
					 , Refno			BIGINT UNSIGNED PATH "$.Refno"
					 , TransIDm			BIGINT UNSIGNED PATH "$.TransIDm"
					 , TransDate		DATETIME(3) PATH "$.TransDate"
					 , MatchID			INT PATH "$.MatchID"
					 , SportType		INT PATH "$.SportType"
					 , LiveHomeScore	INT PATH "$.LiveHomeScore"
					 , LiveAwayScore	INT PATH "$.LiveAwayScore"
					 , BetTypeID		INT PATH "$.BetTypeID"
					 , BetID			BIGINT PATH "$.BetID"
					 , Betteam			VARCHAR(10) PATH "$.BetTeam"
					 , CustID			BIGINT UNSIGNED PATH "$.CustID"
					 , EventDate		DATE PATH "$.EventDate"
					 , KickOffTime		DATETIME PATH "$.KickOffTime"
					 , EventStatus		VARCHAR(50) PATH "$.EventStatus"
					 , HomeID			INT PATH "$.HomeID"
					 , AwayID			INT PATH "$.AwayID"
					 , LeagueID			INT PATH "$.LeagueID"
					 , LeagueName		VARCHAR(500) PATH "$.LeagueName"
			)
		) AS js;  

    IF ip_LiveIndicator = 1 THEN 
		#=====GROUP BETTING===================
		IF (ip_PoolType = 1001) THEN
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorParlayStagingGroupBettingLive(SequenceID, TransID, Refno, TransIDm, TransDate, MatchID, SportType, LiveHomeScore, LiveAwayScore, BettypeID, BetID, Betteam
				, CustID, CTSCustID, EventDate, KickOffTime, EventStatus, HomeID, AwayID, LeagueID, LeagueName, TransDateToSecond, ScoreDiff, GroupID,  InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.Refno
				,	tmpSt.TransIDm
				,	tmpSt.TransDate
				,	tmpSt.MatchID
				,	tmpSt.SportType
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.Betteam
				,	tmpSt.CustID
                ,	cus.CTSCustID
				,	tmpSt.EventDate
				,	tmpSt.KickOffTime
				,	tmpSt.EventStatus
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.LeagueID
				,	tmpSt.LeagueName
                ,	UNIX_TIMESTAMP(tmpSt.TransDate) AS TransDateToSecond
				,	(CASE WHEN tmpSt.SportType = 2 THEN 0 ELSE (tmpSt.LiveHomeScore*10000) + tmpSt.LiveAwayScore END) AS ScoreDiff
				,	0 AS GroupID
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpSt.CustID = cus.CustID;
            
            LEAVE sp;
            
		END IF;
	
    END IF; 
    
	IF ip_LiveIndicator = 0 THEN
        #=====PARLAY GROUP BETTING===================
        IF (ip_PoolType = 2001) THEN

			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorParlayStagingGroupBettingNonLive(SequenceID, TransID, Refno, TransIDm, TransDate, MatchID, SportType, LiveHomeScore, LiveAwayScore, BettypeID, BetID, Betteam
				, CustID, CTSCustID, EventDate, KickOffTime, EventStatus, HomeID, AwayID, LeagueID, LeagueName, TransDateToSecond, ScoreDiff, GroupID,  InsertTime)
			SELECT	tmpSt.SequenceID
				,	tmpSt.TransID
				,	tmpSt.Refno
				,	tmpSt.TransIDm
				,	tmpSt.TransDate
				,	tmpSt.MatchID
				,	tmpSt.SportType
				,	tmpSt.LiveHomeScore
				,	tmpSt.LiveAwayScore
				,	tmpSt.BettypeID
				,	tmpSt.BetID
				,	tmpSt.Betteam
				,	tmpSt.CustID
                ,	cus.CTSCustID
				,	tmpSt.EventDate
				,	tmpSt.KickOffTime
				,	tmpSt.EventStatus
				,	tmpSt.HomeID
				,	tmpSt.AwayID
				,	tmpSt.LeagueID
				,	tmpSt.LeagueName
                ,	UNIX_TIMESTAMP(tmpSt.TransDate) AS TransDateToSecond
				,	(CASE WHEN tmpSt.SportType = 2 THEN 0 ELSE (tmpSt.LiveHomeScore*10000) + tmpSt.LiveAwayScore END) AS ScoreDiff
				,	0 AS GroupID
				,	CURRENT_TIMESTAMP(3) AS InsertTime
			FROM Temp_Staging AS tmpSt
				INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpSt.CustID = cus.CustID;
            
            LEAVE sp;
            
		END IF;
        
	END IF;
    
END$$
DELIMITER ;