/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_Get`(
		IN	ip_MatchInfos		JSON			# MatchID, EventDate, KickOffTime, MatchSection
	,	IN 	ip_FromDate 		DATETIME
    ,	IN 	ip_ToDate 			DATETIME
    ,	IN	ip_SportType		JSON			# JSON LeagueGroupID and SportTypeID
    , 	IN	ip_Market 			TINYINT			# NULL if Both (Live and NonLive))
    ,	IN 	ip_IsVerified 		TINYINT(1)
    ,	IN 	ip_Bettypes 		JSON 			# BettypeID and BetID       
    ,	IN	ip_Reason			VARCHAR(50)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210526@Long.Luu
		Task :		Get Match Monitor report
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20210526@Long.Luu: 		Created [Redmine ID: 152883]
			-	20210823@Casey.Huynh: 	Return Market value [Redmine ID: 159195]
			- 	20220107@Casey.Huynh: 	Fix Issue get data for Verified Trans [Redmine ID: 167192]
			-	20211213@Casey.Huynh: 	Enhance MM, Add column LeagueName, reset IsVerified = 0 [Redmine ID: 165606]
			-	20220110@Casey.Huynh: 	Enhance MM, BetID, Reason [Redmine ID: 166986]
			- 	20220216@Casey.Huynh: 	Fix Issue, show IsVerified = 0 when all tickets were verified [Redmine ID: 166986]
			- 	20220325@Long.Luu: 		Add Reason filter [Redmine ID: 170466]
			-	20220805@Jonas.Huynh: 	Add Reason Fixed Game [Redmine ID: 175700]
			-	20221027@Casey.Huynh: 	Update Verify By Reason and Betteam [RedmineID: 179439]
			-	20230105@Casey.Huynh: 	Add search by InsertDate and remove ip_LeagueName [Redmine ID: #181995]
			-	20230214@Victoria.Le	Add ip_MatchInfos to get latest EventDate and KickOffTime (GolobalShowTime) when search by EventDate 
										Remove ip_DateType, ip_MatchSection [RedmineID: #183280]
			- 	20231116@Long.Luu: 		Return fraud ticket list of each match-liveindicator-bettype-betid [Redmine ID: 195042]
			- 	20231120@Casey.Huynh:	Enhance Rule for Esport. Adjust Group Stake to 300, Add AssociationByIP, ShareMatch(3 Match(last 7 day) [Redmine ID: #196396]
			-	20240123@Casey.Huynh:	Return Quater X Details BetID [Redmine ID: #200120]
			-	20240201@Thomas.Nguyen:	Remove column LeagueName [Redmine ID: #197706]
			-	20240530@Casey.Huynh:	Saba Group Betting [Redmine ID: #191972]
            - 	20240829@Casey.Huynh:	Handle TicketType (Single or Parlay) [Redmine ID: #152883]
            - 	20250218@Thomas.Nguyen:	Fix issue not filter by Bettype in Scan Date mode [Redmine ID: #217782]
            -	20250317@Casey.Huynh: 	Match Monitor Badminton [Redmine ID: #219681]
			-	20250812@Logan.Nguyen: 	Match Monitor Group Betting - Cricket [Redmine ID: #235043]
			-	20251006@Logan.Nguyen: 	Match Monitor Group Betting - Badminton - BetID [Redmine ID: #239957]

		Param's Explanation (filtered by):
			- ip_Market: 		0 return LiveIndicator = 0, 1 return LiveIndicator = 1, NULL: Both Live And Non-Live
            - ip_Reason: 		0:Group Betting, 1: Hedging, 2: Arbitrage, 3: Fixed Game
			- ip_MatchInfos: 	= NULL: search by InsertDate
								<> NULL: search by EventDate
			- ip_SabaLeagueGroupID: NULL: NOT Saba ELSE Saba LeagueGroupID
		Example:
			SELECT * FROM MatchMonitor ORDER BY ID DESC
            SELECT * FROM CTS_DataCenter.MatchMonitorDetailsVerifiedTrans;
            
			CALL CTS_DC_MatchMonitor_Get(
				 @ip_MatchInfos:='[{"MatchId":83679714,"EventDate":"2024-09-09","KickOffTime":"2024-09-09","MatchSection":"1"}]'
				,@ip_FromDate:='2024-09-09 00:00:00',@ip_ToDate:='2024-08-30 00:00:00'
				,@ip_SportType:='[{"LeagueGroupID":0,"SportTypeID":1}]'
				,@ip_Market:=0,@ip_IsVerified:=NULL
				,@ip_Bettypes:='[{"BettypeID":1,"BetID":0},{"BettypeID":3,"BetID":0},{"BettypeID":7,"BetID":0}]',@ip_Reason:='0,5');
    */
    
	DECLARE lv_IsLog TINYINT DEFAULT 0;    
	DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_Get';
    DECLARE lv_LogInfo TEXT;
	
	#==================LOG=======================================================
	IF lv_IsLog = 1 THEN
		SET lv_LogInfo = CONCAT('@ip_FromDate:=''',IFNULL(ip_FromDate,'NULL'),''''
								,',@ip_ToDate:=''',IFNULL(ip_ToDate,'NULL'),''''
								,',@ip_SportType:=''',IFNULL(ip_SportType,'NULL'),''''
								,',@ip_Market:=''',IFNULL(ip_Market,'NULL'),''''
								,',@ip_IsVerified:=''',IFNULL(ip_IsVerified,'NULL'),''''
								,',@ip_Bettypes:=''',IFNULL(ip_Bettypes,'NULL'),''''
								,',@ip_Reason:=''',IFNULL(ip_Reason,'NULL'),'''');
		
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText, JsonString1)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), lv_LogInfo, ip_MatchInfos; 
	END IF;  
	#==================LOG=======================================================  
      
	DROP TEMPORARY TABLE IF EXISTS Temp_MatchMonitor;
    CREATE TEMPORARY TABLE Temp_MatchMonitor(
        	MatchID 		INT
        ,	EventDate		DATETIME DEFAULT NULL
        ,	LiveIndicator	TINYINT
        ,	HomeID			INT
        ,	AwayID			INT
        ,	LeagueID		INT
        ,	SportTypeID		INT
        ,	BettypeID		INT
        ,	BetID			BIGINT
        ,	Reason			TINYINT
        ,	MatchSection	INT DEFAULT NULL
        ,	KickOffTime		DATETIME DEFAULT NULL
        ,	TicketType		SMALLINT
        ,	PRIMARY KEY PK_Temp_MatchMonitor(MatchID,LiveIndicator,BettypeID, BetID, Reason)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_MatchFraudTrans;
    CREATE TEMPORARY TABLE Temp_MatchFraudTrans(
        	MatchID 		INT
        ,	LiveIndicator	TINYINT
        ,	BettypeID		INT
        ,	BetID			BIGINT
        ,	FraudTrans		LONGTEXT
        ,	FraudRefno		LONGTEXT
        ,	FraudTransm		LONGTEXT
        ,	TicketType		SMALLINT
        ,	PRIMARY KEY PK_Temp_MatchFraudTrans(MatchID,LiveIndicator,BettypeID, BetID,TicketType)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Bettype;
    CREATE TEMPORARY TABLE Temp_Bettype(
			BettypeID 	INT UNSIGNED
        ,	BetID		BIGINT
        
        ,	INDEX IX_Temp_Bettype(BettypeID,BetID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Sporttype;
    CREATE TEMPORARY TABLE Temp_Sporttype(        
			LeagueGroupID 	INT
		,	SportTypeID		INT
        ,	PRIMARY KEY PK_Temp_Sporttype_Sporttype_LeagueGroupID(LeagueGroupID, SportTypeID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Reason;
    CREATE TEMPORARY TABLE Temp_Reason(
			ReasonID 	INT PRIMARY KEY
	);
	
    
    DROP TEMPORARY TABLE IF EXISTS Temp_MatchGroup;
    CREATE TEMPORARY TABLE Temp_MatchGroup(
			MatchID 		INT
		, 	SportTypeID		INT
        ,	LiveIndicator	TINYINT
		,	BettypeID		INT
        ,	BetID			INT
        ,	Reason			INT
        ,	VerifiedBy		VARCHAR(1000)
        ,	TicketType		SMALLINT
        
        ,	PRIMARY KEY PK_Temp_MatchTrans(MatchID,LiveIndicator,BettypeID, BetID, TicketType, Reason)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_MatchGroup_NotVerified;
    CREATE TEMPORARY TABLE Temp_MatchGroup_NotVerified(
			MatchID 		INT
        ,	LiveIndicator	TINYINT
		,	BettypeID		INT
        ,	BetID			INT
        ,	TicketType		SMALLINT
        
        ,	PRIMARY KEY PK_Temp_MatchTrans(MatchID,LiveIndicator,BettypeID, BetID,TicketType)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_VerfiedTrans;
    CREATE TEMPORARY TABLE Temp_VerfiedTrans(
			TransID			BIGINT UNSIGNED
        ,	Reason			TINYINT        
		,	MatchID 		INT
        ,	LiveIndicator	TINYINT
		,	BettypeID		INT
        ,	BetID			INT
        ,	VerifiedBy 		VARCHAR(50)
        ,	TicketType		SMALLINT
        ,	INDEX IX_Temp_VerfiedTrans(TransID,Reason)
        ,	INDEX IX_Temp_VerfiedTrans_MatchGroup(MatchID,LiveIndicator,BettypeID, BetID, Reason,TicketType)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MatchInfo;
	CREATE TEMPORARY TABLE Temp_MatchInfo(
			MatchID 		INT
		,	EventDate		DATETIME
		,	LiveIndicator	TINYINT
		,	HomeID			INT
		,	AwayID			INT
		,	LeagueID		INT 
		,	SporttypeID		INT
		,	LeagueGroupID	INT
		,	BettypeID		INT
		,	BetID			BIGINT
		,	Reason			TINYINT
		,	MatchSection	INT 
		,	KickOffTime		DATETIME
        ,	TicketType		SMALLINT
		
		,	INDEX IX_Temp_MatchInfo_MatchIDBettypeIDBetID(MatchID,BettypeID,BetID)
	);
	
	#================================================================================
    
	INSERT IGNORE INTO Temp_Sporttype(LeagueGroupID, SportTypeID)
	SELECT  js.LeagueGroupID
		,	js.SportTypeID
	FROM JSON_TABLE(ip_Sporttype,
					 "$[*]" COLUMNS(
								LeagueGroupID		INT	PATH "$.LeagueGroupID"
							,	SportTypeID			INT	PATH "$.SportTypeID"
						)
				) AS js;  

    INSERT IGNORE INTO Temp_Bettype(BettypeID, BetID)
	SELECT  js.BettypeID
		,	js.BetID
	FROM JSON_TABLE(ip_Bettypes,
					 "$[*]" COLUMNS(
								BettypeID		INT		PATH "$.BettypeID"
							,	BetID			BIGINT	PATH "$.BetID"
						)
				) AS js;  

    SET @sql = CONCAT("INSERT IGNORE INTO Temp_Reason (ReasonID) VALUES ('", REPLACE(ip_Reason, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1; 

    IF (IFNULL(ip_MatchInfos,'') = '') THEN # Search by Scanned Date
		INSERT INTO Temp_MatchMonitor(MatchID, LiveIndicator, HomeID, AwayID, LeagueID, SportTypeID, BettypeID, BetID, Reason, TicketType)    
				SELECT 	DISTINCT mm.MatchID
			,	mm.LiveIndicator
			,	mm.HomeID
			,	mm.AwayID
			,	mm.LeagueID
			,	mm.Sporttype
			,	mm.BettypeID
			,	mm.BetID
			,	mm.Reason	# 0:Group Betting, 1: Hedging, 2: Arbitrage, 3: Fixed Game , 58: Irrigition
            ,	mm.TicketType
		FROM   CTS_DataCenter.MatchMonitor AS mm
			INNER JOIN Temp_Bettype AS tmpBt ON mm.BettypeID = tmpBt.BettypeID 
							AND mm.BetID =  IFNULL(tmpBt.BetID, mm.BetID)
			INNER JOIN Temp_Sporttype AS tmpSt ON mm.Sporttype = tmpSt.SportTypeID AND IFNULL(mm.LeagueGroupID,0) = tmpSt.LeagueGroupID
			INNER JOIN Temp_Reason AS r ON r.ReasonID = mm.Reason
		WHERE mm.InsertDate BETWEEN ip_FromDate AND ip_ToDate
			AND mm.LiveIndicator = IFNULL(ip_Market, mm.LiveIndicator); 
            
    ELSE #ip_MatchInfos <> '' THEN # Search by Event Date		
                              
		INSERT IGNORE INTO Temp_MatchInfo (MatchID, EventDate, LiveIndicator, HomeID, AwayID, LeagueID, SporttypeID,LeagueGroupID, BettypeID, BetID, Reason, MatchSection, KickOffTime, TicketType)
		SELECT  DISTINCT js.MatchId
			,	js.EventDate
			,	mm.LiveIndicator
			,	mm.HomeID
			,	mm.AwayID
			,	mm.LeagueID
			,	mm.Sporttype
            ,	IFNULL(mm.LeagueGroupID,0)
			,	mm.BettypeID
			,	mm.BetID AS BetID
			,	mm.Reason		# 0:Group Betting, 1: Hedging, 2: Arbitrage, 3: Fixed Game
			,	js.MatchSection
			, 	js.KickOffTime
            ,	mm.TicketType
		FROM CTS_DataCenter.MatchMonitor AS mm
			INNER JOIN JSON_TABLE(ip_MatchInfos,
									 "$[*]" COLUMNS(
												MatchId			INT			PATH "$.MatchId"
											,	EventDate		DATETIME	PATH "$.EventDate"
											,	KickOffTime		DATETIME	PATH "$.KickOffTime"
											,	MatchSection	TINYINT		PATH "$.MatchSection"
										)
								) AS js ON js.MatchId = mm.MatchId
			INNER JOIN Temp_Bettype AS tmpBt ON mm.BettypeID = tmpBt.BettypeID 
				AND mm.BetID = IFNULL(tmpBt.BetID,mm.BetID)
			INNER JOIN Temp_Reason AS r ON r.ReasonID = mm.Reason
		WHERE	mm.LiveIndicator = IFNULL(ip_Market, mm.LiveIndicator);
    
		INSERT INTO Temp_MatchMonitor(MatchID, EventDate, LiveIndicator, HomeID, AwayID, LeagueID, SportTypeID, BettypeID, BetID, Reason, MatchSection, KickOffTime, TicketType)    
		SELECT 	DISTINCT tmpMi.MatchID
			,	tmpMi.EventDate
			,	tmpMi.LiveIndicator
			,	tmpMi.HomeID
			,	tmpMi.AwayID
			,	tmpMi.LeagueID
			,	tmpMi.SportTypeID
			,	tmpMi.BettypeID
			,	tmpMi.BetID AS BetID
			,	tmpMi.Reason		# Refer table StaticList(ListID=16)
			,	tmpMi.MatchSection
			, 	tmpMi.KickOffTime
            ,	tmpMi.TicketType
		FROM   Temp_MatchInfo AS tmpMi 
			INNER JOIN Temp_Sporttype AS tmpSt ON tmpMi.SporttypeID = tmpSt.SportTypeID AND tmpMi.LeagueGroupID= tmpSt.LeagueGroupID;
    END IF;

    INSERT IGNORE INTO Temp_VerfiedTrans(TransID, Reason, VerifiedBy, MatchID,LiveIndicator,BettypeID, BetID, TicketType)
    SELECT	js.TransID
		,	mdv.Reason
        ,	us.UserName
        ,	mdv.MatchID
        ,	mdv.LiveIndicator
        ,	mdv.BettypeID
        ,	mdv.BetID AS BetID
        ,	mdv.TicketType
    FROM CTS_DataCenter.MatchMonitorDetailsVerifiedTrans AS mdv		
		LEFT JOIN CTS_Admin.CTSUser AS us ON us.UserID = mdv.VerifiedBy
		INNER JOIN Temp_MatchMonitor AS tmpMm ON mdv.MatchID = tmpMm.MatchID AND mdv.LiveIndicator = tmpMm.LiveIndicator 
														AND mdv.BettypeID = tmpMm.BettypeID 
                                                        AND mdv.BetID = tmpMm.BetID AND mdv.TicketType = tmpMm.TicketType
			JOIN JSON_TABLE(REPLACE(JSON_ARRAY(mdv.ListTransID), ',', '","'), 
						'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
						) js;

    INSERT INTO Temp_MatchGroup(MatchID, SportTypeID, LiveIndicator, BettypeID, BetID, TicketType, Reason, VerifiedBy)
    SELECT	tmpMm.MatchID
			,	tmpMm.SportTypeID
			,	tmpMm.LiveIndicator
			,	tmpMm.BettypeID
            ,	tmpMm.BetID
            ,	tmpMm.TicketType
			,	tmpMm.Reason
            ,	GROUP_CONCAT(DISTINCT tmpVt.VerifiedBy)
	FROM Temp_MatchMonitor AS tmpMm
		LEFT JOIN Temp_VerfiedTrans AS tmpVt ON tmpVt.MatchID = tmpMm.MatchID AND tmpVt.LiveIndicator = tmpMm.LiveIndicator 
												AND tmpVt.BettypeID = tmpMm.BettypeID AND tmpVt.BetID = tmpMm.BetID AND tmpVt.TicketType = tmpMm.TicketType 
	GROUP BY tmpMm.MatchID, tmpMm.LiveIndicator, tmpMm.BettypeID, tmpMm.BetID, tmpMm.TicketType, tmpMm.Reason; 

	INSERT INTO Temp_MatchGroup_NotVerified(MatchID, LiveIndicator, BettypeID, BetID, TicketType)
    SELECT DISTINCT	tmpMg.MatchID
		,	tmpMg.LiveIndicator
		,	tmpMg.BettypeID
        ,	tmpMg.BetID
        ,	tmpMg.TicketType
    FROM Temp_MatchGroup AS tmpMg
		INNER JOIN CTS_DataCenter.MatchMonitorDetails AS mmd ON tmpMg.MatchID = mmd.MatchID AND tmpMg.LiveIndicator = mmd.LiveIndicator
																AND tmpMg.BettypeID = mmd.BettypeID 
                                                                AND tmpMg.BetID = mmd.BetID 
                                                                AND tmpMg.TicketType = mmd.TicketType
		JOIN JSON_TABLE(REPLACE(JSON_ARRAY(mmd.ListTransID), ',', '","'), 
						'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
						) js
	WHERE NOT EXISTS (SELECT 1 FROM Temp_VerfiedTrans AS tmpVt WHERE js.TransID = tmpVt.TransID);    

	INSERT INTO Temp_MatchFraudTrans(MatchID,LiveIndicator,BettypeID,BetID,TicketType,FraudTrans,FraudRefno,FraudTransm)
	SELECT 	t.MatchID, t.LiveIndicator, t.BettypeID, t.BetID, t.TicketType
		,	GROUP_CONCAT(DISTINCT d.ListTransID) AS FraudTrans
        ,	GROUP_CONCAT(DISTINCT d.ListRefno) AS FraudRefno
        ,	GROUP_CONCAT(DISTINCT d.ListTransIDm) AS FraudTransm
    FROM Temp_MatchMonitor AS t
		INNER JOIN CTS_DataCenter.MatchMonitorDetails AS d ON t.MatchID = d.MatchID 
			AND t.LiveIndicator = d.LiveIndicator AND t.BettypeID = d.BettypeID 
									AND t.BetID = d.BetID
									AND  t.TicketType = d.TicketType 
		INNER JOIN Temp_Reason AS r ON d.Reason = r.ReasonID
	GROUP BY t.MatchID, t.LiveIndicator, t.BettypeID, t.BetID, t.TicketType;

    IF (ip_IsVerified IS NULL)
    THEN 

		SELECT	tmpMm.MatchID
            ,	tmpMm.MatchSection
			,	tmpMm.EventDate
            ,	tmpMm.KickOffTime
			,	tmpMm.LiveIndicator AS Market
			,	tmpMm.HomeID
			,	tmpMm.AwayID
			,	tmpMm.LeagueID
            ,	tmpMm.SportTypeID
			,	tmpMm.BettypeID
            ,	tmpMm.BetID
            ,	REPLACE(REPLACE(sbs.BettypeNameDisplay, '[X]', 
						(CASE 
    						WHEN LOCATE('X', sbs.BetIDPattern) > 0 
    							THEN CAST(
    								SUBSTRING(
        								LPAD(tmpMm.BetID, LENGTH(sbs.BetIDPattern), '0'),
            							LOCATE('X', sbs.BetIDPattern),
            							LENGTH(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern))) - LENGTH(REPLACE(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern)), 'X',''))
        							) AS UNSIGNED
    							)
    						ELSE 0
						END)), ' Y ', (CASE WHEN (tmpMm.BetID > 999) THEN CONCAT(' ',(tmpMm.BetID MOD 100),' ') ELSE 0 END)) AS BettypeNameDisplay
        	,	-- DetailsX
				CASE 
    				WHEN LOCATE('X', sbs.BetIDPattern) > 0 
    				THEN CAST(
        				SUBSTRING(
            				LPAD(tmpMm.BetID, LENGTH(sbs.BetIDPattern), '0'),
            				LOCATE('X', sbs.BetIDPattern),
            				LENGTH(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern))) - LENGTH(REPLACE(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern)), 'X',''))
        				) AS UNSIGNED
    				)
    				ELSE 0
				END AS DetailsX
            ,	-- DetailsY
				CASE 
    				WHEN LOCATE('Y', sbs.BetIDPattern) > 0 
    				THEN CAST(
        				SUBSTRING(
            				LPAD(tmpMm.BetID, LENGTH(sbs.BetIDPattern), '0'),
            				LOCATE('Y', sbs.BetIDPattern),
            				LENGTH(SUBSTRING(sbs.BetIDPattern, LOCATE('Y', sbs.BetIDPattern))) - LENGTH(REPLACE(SUBSTRING(sbs.BetIDPattern, LOCATE('Y', sbs.BetIDPattern)), 'Y',''))
        				) AS UNSIGNED
    				)
    				ELSE 0
				END AS DetailsY		
			,	GROUP_CONCAT(DISTINCT tmpMm.Reason)	AS Reason		
			,	NOT EXISTS(SELECT 1 FROM Temp_MatchGroup_NotVerified AS tmpNv WHERE tmpMm.MatchID = tmpNv.MatchID AND tmpMm.LiveIndicator = tmpNv.LiveIndicator 
					AND tmpMm.BettypeID = tmpNv.BettypeID AND tmpMm.BetID = tmpNv.BetID AND tmpMm.TicketType = tmpNv.TicketType LIMIT 1) IsVerified
            ,	GROUP_CONCAT(DISTINCT tmpMg.VerifiedBy)	AS VerifiedBy
            ,	t.FraudTrans
            ,	t.FraudRefno
            ,	t.FraudTransm
            ,	tmpMm.TicketType
		FROM Temp_MatchMonitor AS tmpMm
			INNER JOIN CTS_DataCenter.BettypeSetting AS sbs ON sbs.BetTypeID = tmpMm.BettypeID
			INNER JOIN Temp_MatchFraudTrans AS t ON tmpMm.MatchID = t.MatchID AND tmpMm.LiveIndicator = t.LiveIndicator 
					AND tmpMm.BettypeID = t.BettypeID AND tmpMm.BetID = t.BetID AND t.TicketType = tmpMm.TicketType
			LEFT JOIN Temp_MatchGroup AS tmpMg ON tmpMm.MatchID = tmpMg.MatchID AND tmpMm.LiveIndicator = tmpMg.LiveIndicator 
					AND tmpMm.BettypeID = tmpMg.BettypeID AND tmpMm.BetID = tmpMg.BetID AND tmpMg.TicketType = tmpMm.TicketType
		GROUP BY tmpMm.MatchID
            ,	tmpMm.MatchSection
			,	tmpMm.EventDate
            ,	tmpMm.KickOffTime
			,	tmpMm.LiveIndicator
			,	tmpMm.HomeID
			,	tmpMm.AwayID
			,	tmpMm.LeagueID
            ,	tmpMm.SporttypeID
			,	tmpMm.BettypeID
            ,	tmpMm.BetID
            ,	sbs.BettypeNameDisplay
            ,	t.FraudTrans
            ,	t.FraudRefno
            ,	t.FraudTransm
            ,	tmpMm.TicketType
			,	sbs.BetIDPattern;

	END IF;

	IF (ip_IsVerified = 0)
    THEN
		SELECT	tmpMm.MatchID
            ,	tmpMm.MatchSection
			,	tmpMm.EventDate
            ,	tmpMm.KickOffTime
			,	tmpMm.LiveIndicator AS Market
			,	tmpMm.HomeID
			,	tmpMm.AwayID
			,	tmpMm.LeagueID
            ,	tmpMm.SportTypeID
			,	tmpMm.BettypeID
            ,	tmpMm.BetID
            ,	REPLACE(REPLACE(sbs.BettypeNameDisplay, '[X]', 
						(CASE 
    						WHEN LOCATE('X', sbs.BetIDPattern) > 0 
    							THEN CAST(
    								SUBSTRING(
        								LPAD(tmpMm.BetID, LENGTH(sbs.BetIDPattern), '0'),
            							LOCATE('X', sbs.BetIDPattern),
            							LENGTH(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern))) - LENGTH(REPLACE(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern)), 'X',''))
        							) AS UNSIGNED
    							)
    						ELSE 0
						END)), ' Y ', (CASE WHEN (tmpMm.BetID > 999) THEN CONCAT(' ',(tmpMm.BetID MOD 100),' ') ELSE 0 END)) AS BettypeNameDisplay
            ,	-- DetailsX
				CASE 
    				WHEN LOCATE('X', sbs.BetIDPattern) > 0 
    				THEN CAST(
        				SUBSTRING(
            				LPAD(tmpMm.BetID, LENGTH(sbs.BetIDPattern), '0'),
            				LOCATE('X', sbs.BetIDPattern),
            				LENGTH(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern))) - LENGTH(REPLACE(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern)), 'X',''))
        				) AS UNSIGNED
    				)
    				ELSE 0
				END AS DetailsX
            ,	-- DetailsY
				CASE 
    				WHEN LOCATE('Y', sbs.BetIDPattern) > 0 
    				THEN CAST(
        				SUBSTRING(
            				LPAD(tmpMm.BetID, LENGTH(sbs.BetIDPattern), '0'),
            				LOCATE('Y', sbs.BetIDPattern),
            				LENGTH(SUBSTRING(sbs.BetIDPattern, LOCATE('Y', sbs.BetIDPattern))) - LENGTH(REPLACE(SUBSTRING(sbs.BetIDPattern, LOCATE('Y', sbs.BetIDPattern)), 'Y',''))
        				) AS UNSIGNED
    				)
    				ELSE 0
				END AS DetailsY	
			,	GROUP_CONCAT(DISTINCT tmpMm.Reason)	AS Reason		
			,	0 AS IsVerified
            ,	GROUP_CONCAT(DISTINCT tmpMg.VerifiedBy)	AS VerifiedBy
            ,	t.FraudTrans
            ,	t.FraudRefno
            ,	t.FraudTransm
            ,	tmpMm.TicketType
		FROM Temp_MatchMonitor AS tmpMm
			INNER JOIN CTS_DataCenter.BettypeSetting AS sbs ON sbs.BetTypeID = tmpMm.BettypeID
			INNER JOIN Temp_MatchFraudTrans AS t ON tmpMm.MatchID = t.MatchID AND tmpMm.LiveIndicator = t.LiveIndicator 
					AND tmpMm.BettypeID = t.BettypeID AND tmpMm.BetID = t.BetID AND tmpMm.TicketType = t.TicketType
			INNER JOIN Temp_MatchGroup AS tmpMg ON tmpMm.MatchID = tmpMg.MatchID AND tmpMm.LiveIndicator = tmpMg.LiveIndicator 
					AND tmpMm.BettypeID = tmpMg.BettypeID AND tmpMm.BetID = tmpMg.BetID AND tmpMm.Reason = tmpMg.Reason
		WHERE EXISTS(SELECT 1 FROM Temp_MatchGroup_NotVerified AS tmpNv WHERE tmpMm.MatchID = tmpNv.MatchID AND tmpMm.LiveIndicator = tmpNv.LiveIndicator 
					AND tmpMm.BettypeID = tmpNv.BettypeID AND tmpMm.BetID = tmpNv.BetID)
        GROUP BY tmpMm.MatchID
            ,	tmpMm.MatchSection
			,	tmpMm.EventDate
            ,	tmpMm.KickOffTime
			,	tmpMm.LiveIndicator
			,	tmpMm.HomeID
			,	tmpMm.AwayID
			,	tmpMm.LeagueID
            ,	tmpMm.SporttypeID
			,	tmpMm.BettypeID
            ,	tmpMm.BetID
            ,	sbs.BettypeNameDisplay
            ,	tmpMm.TicketType
			,	sbs.BetIDPattern;
	END IF;
    
    IF (ip_IsVerified = 1)
    THEN
		
		SELECT	tmpMm.MatchID
            ,	tmpMm.MatchSection
			,	tmpMm.EventDate
            ,	tmpMm.KickOffTime
			,	tmpMm.LiveIndicator AS Market
			,	tmpMm.HomeID
			,	tmpMm.AwayID
			,	tmpMm.LeagueID
            ,	tmpMm.SporttypeID
			,	tmpMm.BettypeID
            ,	tmpMm.BetID
            ,	REPLACE(REPLACE(sbs.BettypeNameDisplay, '[X]', 
						(CASE 
    						WHEN LOCATE('X', sbs.BetIDPattern) > 0 
    							THEN CAST(
    								SUBSTRING(
        								LPAD(tmpMm.BetID, LENGTH(sbs.BetIDPattern), '0'),
            							LOCATE('X', sbs.BetIDPattern),
            							LENGTH(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern))) - LENGTH(REPLACE(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern)), 'X',''))
        							) AS UNSIGNED
    							)
    						ELSE 0
						END)), ' Y ', (CASE WHEN (tmpMm.BetID > 999) THEN CONCAT(' ',(tmpMm.BetID MOD 100),' ') ELSE 0 END)) AS BettypeNameDisplay
            ,	-- DetailsX
				CASE 
    				WHEN LOCATE('X', sbs.BetIDPattern) > 0 
    				THEN CAST(
        				SUBSTRING(
            				LPAD(tmpMm.BetID, LENGTH(sbs.BetIDPattern), '0'),
            				LOCATE('X', sbs.BetIDPattern),
            				LENGTH(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern))) - LENGTH(REPLACE(SUBSTRING(sbs.BetIDPattern, LOCATE('X', sbs.BetIDPattern)), 'X',''))
        				) AS UNSIGNED
    				)
    				ELSE 0
				END AS DetailsX
            ,	-- DetailsY
				CASE 
    				WHEN LOCATE('Y', sbs.BetIDPattern) > 0 
    				THEN CAST(
        				SUBSTRING(
            				LPAD(tmpMm.BetID, LENGTH(sbs.BetIDPattern), '0'),
            				LOCATE('Y', sbs.BetIDPattern),
            				LENGTH(SUBSTRING(sbs.BetIDPattern, LOCATE('Y', sbs.BetIDPattern))) - LENGTH(REPLACE(SUBSTRING(sbs.BetIDPattern, LOCATE('Y', sbs.BetIDPattern)), 'Y',''))
        				) AS UNSIGNED
    				)
    				ELSE 0
				END AS DetailsY	
			,	GROUP_CONCAT(DISTINCT tmpMm.Reason)	AS Reason		
			,	1 AS IsVerified
            ,	GROUP_CONCAT(DISTINCT tmpMg.VerifiedBy)	AS VerifiedBy
            ,	t.FraudTrans
            ,	t.FraudRefno
            ,	t.FraudTransm
            ,	tmpMm.TicketType
		FROM Temp_MatchMonitor AS tmpMm        
			INNER JOIN CTS_DataCenter.BettypeSetting AS sbs ON sbs.BetTypeID = tmpMm.BettypeID
			INNER JOIN Temp_MatchFraudTrans AS t ON tmpMm.MatchID = t.MatchID AND tmpMm.LiveIndicator = t.LiveIndicator 
					AND tmpMm.BettypeID = t.BettypeID AND tmpMm.BetID = t.BetID AND tmpMm.TicketType = t.TicketType
			INNER JOIN Temp_MatchGroup AS tmpMg ON tmpMm.MatchID = tmpMg.MatchID AND tmpMm.LiveIndicator = tmpMg.LiveIndicator 
					AND tmpMm.BettypeID = tmpMg.BettypeID AND tmpMm.BetID = tmpMg.BetID AND tmpMm.Reason = tmpMg.Reason
		WHERE NOT EXISTS(SELECT 1 FROM Temp_MatchGroup_NotVerified AS tmpNv WHERE tmpMm.MatchID = tmpNv.MatchID AND tmpMm.LiveIndicator = tmpNv.LiveIndicator 
					AND tmpMm.BettypeID = tmpNv.BettypeID AND tmpMm.BetID = tmpNv.BetID)
        GROUP BY tmpMm.MatchID
            ,	tmpMm.MatchSection
			,	tmpMm.EventDate
            ,	tmpMm.KickOffTime
			,	tmpMm.LiveIndicator
			,	tmpMm.HomeID
			,	tmpMm.AwayID
			,	tmpMm.LeagueID
            ,	tmpMm.SporttypeID
			,	tmpMm.BettypeID
            ,	tmpMm.BetID
            ,	sbs.BettypeNameDisplay
            ,	tmpMm.TicketType
			,	sbs.BetIDPattern;
	END IF;
                   
END$$
DELIMITER ;

