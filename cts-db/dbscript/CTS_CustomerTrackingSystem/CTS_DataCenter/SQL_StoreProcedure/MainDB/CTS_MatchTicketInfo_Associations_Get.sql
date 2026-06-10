/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CTS_MatchTicketInfo_Associations_Get]
		@FromDate				DATETIME = NULL
	,	@ToDate					DATETIME = NULL
	,	@SportList				VARCHAR(MAX) = ''
	,	@LeagueEvent			VARCHAR(500) = ''
	,	@MarketList				VARCHAR(10)  = ''
	,	@BettypeList			VARCHAR(MAX) = '[]' --JSON
	,	@MatchSection			VARCHAR(10) = '' 	-- STRING
	,	@SportSabaLeagueGroup	VARCHAR(200) = ''
	,	@LeagueGroupList		VARCHAR(MAX)=''
	,	@UserAmount				MONEY = 0
	,	@TotalAmount			MONEY = 0
	,	@AssociationsList		VARCHAR(MAX) = '[]' -- JSON
AS

/*
	Created: 20251031@Logan.Nguyen
	Task : Get Match Ticket Info
	DB	 : WASAVerse

	Revisions:
		- 20251031@Logan.Nguyen: Created [Redmine ID: #239956]

	Params Explaination:
		,@BettypeList='[	{"BetType":1, "BetChoiceType":2}
						,	{"BetType":2, "BetChoiceType":2}
						,	{"BetType":126, "BetChoiceType":1}]'
	
	Params Explaination:
		,@AssociationsList='[{"RootCustID": 1, "CustIDAssociations": "11,12,13"}, {"RootCustID": 2, "CustIDAssociations": "21,22,23"}]'

	EXEC CTS_MatchTicketInfo_Associations_Get @FromDate = '2025-10-27 00:00:00'
							 , @ToDate = '2025-11-03 00:00:00'
							 , @SportList = '1'
							 , @LeagueEvent = ''
							 , @BettypeList = '[{"BetType":1,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0},{"BetType":2,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0},{"BetType":3,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0},{"BetType":5,"BetChoiceType":1,"BetID":0},{"BetType":6,"BetChoiceType":1,"BetID":0},{"BetType":7,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0},{"BetType":8,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0},{"BetType":12,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0},{"BetType":15,"BetChoiceType":1,"BetID":0},{"BetType":126,"BetChoiceType":1,"BetID":0},{"BetType":413,"BetChoiceType":1,"BetID":0},{"BetType":414,"BetChoiceType":1,"BetID":0}]'
							 , @DangerLevels = ''
							 , @AssociationsList='[{"RootCustID": 1, "CustIDAssociations": "11,12,13"}, {"RootCustID": 2, "CustIDAssociations": "21,22,23"}]'
							 , @LeagueGroupList = '1,2,3,4,5,6,7,8,9,10,11,12,13,14,41,72,73,77,78,79,80,81,82,99,100,101,102,103,104,105,106,107,0'
							 , @MarketList = '0,1'
							 , @SportSabaLeagueGroup = ''
							 , @MatchSection = '1,2,3,4'
							 , @UserAmount = 0.0000
							 , @TotalAmount = 0.0000 ;
		
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today					DATE = GETDATE();

	DECLARE @BalanceUpDay			DATETIME
		,	@MoveBetsDay			DATETIME
		,	@FDate 					DATETIME 
		, 	@TDate 					DATETIME 

		,	@MatchSection_Live		TINYINT = 1
		,	@MatchSection_Today		TINYINT = 2
		,	@MatchSection_Early		TINYINT = 3
		,	@MatchSection_Closed	TINYINT = 4

		,	@IsExcludeSabaGroup		BIT = 1
		,	@IsFromActive14			TINYINT = 0
		;

	DECLARE @SPORTTYPE_CRICKET		SMALLINT = 50;

	--===============================================================================================
	DECLARE @tmpBUMBData AS TABLE (BUDay DATETIME,	MBDay DATETIME);
	DECLARE @tmpSport AS TABLE (SportType TINYINT PRIMARY KEY);
	DECLARE @tmpMatchSection AS TABLE (Id TINYINT, EventStatus NVARCHAR(50), IsFrom14 BIT DEFAULT 0);
	DECLARE @tmpSportSabaLeagueGroup AS TABLE (SportType TINYINT, LeagueGroupID INT INDEX IX_SabaLeagueGroup);

	IF	OBJECT_ID('tempdb..#tmpBetType') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpBetType;
	END;

	CREATE TABLE #tmpBetType
	(
			BetType			INT
		,	BetChoiceType	TINYINT 		
		,	BetChoiceHome	NVARCHAR(10) 	
		,	BetChoiceAway	NVARCHAR(10) 	
		,	BetIdPattern	NVARCHAR(20)	
		,	BetId			BIGINT			
	);
	
	IF	OBJECT_ID('tempdb..#tmpCustomer') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustomer;
	END;

	CREATE TABLE #tmpCustomer
	(
			CustID	INT	PRIMARY KEY
	);
	
	IF OBJECT_ID('tempdb..#tmpAssoc') IS NOT NULL DROP TABLE #tmpAssoc;
    CREATE TABLE #tmpAssoc
	(
        	CustID			INT	NOT NULL
		,	RootCustID		INT	NOT NULL
    );
	CREATE CLUSTERED INDEX CIX_tmpAssoc_CustID ON #tmpAssoc(CustID);

	IF	OBJECT_ID('tempdb..#tmpLeagueGroup') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpLeagueGroup;
	END;

	CREATE TABLE	#tmpLeagueGroup
	(
			LeagueGroupID	INT 	
	);

	IF OBJECT_ID('tempdb..#tmpMatchSum_Group') IS NOT NULL 
	BEGIN
		DROP TABLE #tmpMatchSum_Group;
	END;	

    CREATE TABLE #tmpMatchSum_Group
    (
        RootCustID        INT NOT NULL,
        MatchId           INT NOT NULL,
        LiveIndicator     BIT NOT NULL,
        Bettype           INT NOT NULL,
        BetId             BIGINT,
        BetChoiceType     TINYINT,
        TotalAmountHome   MONEY,
        TotalAmountAway   MONEY,
        TotalTicketHome   MONEY,
        TotalTicketAway   MONEY,
        ListCustID        VARCHAR(MAX),
        IsFrom14          BIT DEFAULT 0
    );
	
	DROP TABLE IF EXISTS #tmpMatchInfo
	CREATE TABLE #tmpMatchInfo
	(
			MatchId			INT PRIMARY KEY
		,	HomeId			INT
		,	HomeName		VARCHAR(100)
		,	AwayId			INT
		,	AwayName		VARCHAR(100)
		,	EventDate		DATETIME
		,	GlobalShowTime	SMALLDATETIME
		,	EventStatus		NVARCHAR(50)
		,	SportType		INT
		,	LeagueId		INT
		,	LeagueName		NVARCHAR(500)
	);

	DROP TABLE IF EXISTS #tmpMatchInfo14
	CREATE TABLE #tmpMatchInfo14
	(
			MatchId			INT PRIMARY KEY
		,	HomeId			INT
		,	HomeName		VARCHAR(100)
		,	AwayId			INT
		,	AwayName		VARCHAR(100)
		,	EventDate		DATETIME
		,	GlobalShowTime	SMALLDATETIME
		,	EventStatus		NVARCHAR(50)
		,	SportType		INT
		,	LeagueId		INT
		,	LeagueName		NVARCHAR(500)
	);

	DROP TABLE IF EXISTS #tmpCustTrans
	CREATE TABLE #tmpCustTrans
	(
			CustID			INT
		,	MatchId			INT
		,	Liveindicator	BIT
		,	Bettype			SMALLINT
		,	BetId			BIGINT
		,	Betteam			NVARCHAR(10)
		,	Stake			MONEY
		,	Actualrate		FLOAT		
	)

	--===============================================================================================
	INSERT INTO @tmpBUMBData (BUDay, MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;
	
	SELECT	TOP(1) @BalanceUpDay = BUDay, @MoveBetsDay	= MBDay
	FROM @tmpBUMBData;
	
	IF(@UserAmount IS NULL)
	BEGIN
		SET @UserAmount = 0;
	END;


	IF(@TotalAmount IS NULL)
	BEGIN
		SET @TotalAmount = 0;
	END;

	IF (@ToDate IS NULL)
	BEGIN
		SET @ToDate = (SELECT MAX(m.EventDate) FROM bodb02.dbo.Match AS m WITH(NOLOCK));
	END
	
	SELECT 	@FDate = @FromDate, @TDate = @ToDate;

	IF @SportList <> ''
	BEGIN
		INSERT INTO @tmpSport (SportType)
		SELECT ssk.value FROM STRING_SPLIT (@SportList, ',') AS ssk;
	END;

	IF @LeagueGroupList <> ''
	BEGIN
		INSERT INTO #tmpLeagueGroup(LeagueGroupID)
		SELECT ssk.value FROM STRING_SPLIT (@LeagueGroupList, ',') AS ssk;
	END
	ELSE 
	BEGIN
		INSERT INTO #tmpLeagueGroup(LeagueGroupID)
		SELECT NULL;
	END;

	INSERT INTO #tmpAssoc(RootCustID, CustID)
	SELECT j.RootCustID, TRY_CAST(ss.value AS INT)
	FROM OPENJSON(@AssociationsList) WITH (
 			RootCustID			INT				'$.RootCustID'
		,	AssCustIDList		VARCHAR(MAX)	'$.AssCustIDList'
	) AS j
	CROSS APPLY STRING_SPLIT(ISNULL(NULLIF(j.AssCustIDList,''), '0'), ',') AS ss;

	INSERT INTO #tmpAssoc(RootCustID, CustID)
	SELECT DISTINCT
    		RootCustID
    	,	RootCustID AS CustID
	FROM #tmpAssoc;
	
	INSERT INTO #tmpBetType(BetType,BetChoiceType,BetChoiceHome,BetChoiceAway,BetIdPattern,BetId)
	SELECT	j.BetType
		,	j.BetChoiceType
		,	j.BetChoiceHome
		,	j.BetChoiceAway
		,	j.BetIDPattern
		,	j.BetID
	FROM OPENJSON (@BettypeList) WITH (
			BetType			INT				'$.BetType'
		,	BetChoiceType	TINYINT			'$.BetChoiceType'
		,	BetChoiceHome	NVARCHAR(10)	'$.BetChoiceHome'
		,	BetChoiceAway	NVARCHAR(10)	'$.BetChoiceAway'
		,	BetIDPattern	NVARCHAR(20)	'$.BetIDPattern'
		,	BetID			BIGINT			'$.BetID'
		) AS j;
		
	INSERT INTO @tmpMatchSection (Id, EventStatus)
	SELECT 	ssk.value
		,	CASE 
				WHEN ssk.value = @MatchSection_Closed THEN 'Completed'
				WHEN ssk.value IN (@MatchSection_Live,@MatchSection_Today,@MatchSection_Early) THEN 'running'
				ELSE ''
			END
	FROM STRING_SPLIT(@MatchSection, ',') AS ssk;
	
	IF EXISTS (SELECT 1 FROM @tmpMatchSection WHERE Id IN (@MatchSection_Live,@MatchSection_Today,@MatchSection_Early))
	BEGIN
		INSERT INTO @tmpMatchSection (Id, EventStatus)
		SELECT Id,a
		FROM (VALUES ('Closed'),('Postponed'),('internal'))  AS X(a)
			CROSS APPLY (SELECT Id 
						FROM @tmpMatchSection
						WHERE Id IN (@MatchSection_Live,@MatchSection_Today,@MatchSection_Early)) AS ms;
		
	END;
	
	IF (@SportSabaLeagueGroup <> '')
	BEGIN
		SET @IsExcludeSabaGroup = 0;
	
		INSERT INTO @tmpSportSabaLeagueGroup (SportType, LeagueGroupID)
		SELECT 	CAST(LEFT(ssk.value, CHARINDEX('_', ssk.value)-1) AS TINYINT) AS SportType
			,	CAST(SUBSTRING(ssk.value, CHARINDEX('_', ssk.value)+1, 6) AS TINYINT) AS LeagueGroupID
		FROM STRING_SPLIT (@SportSabaLeagueGroup, ',') AS ssk
		WHERE LEN(ssk.value) > 0;
	END;

	INSERT INTO #tmpCustomer(CustID)
    SELECT DISTINCT CustID FROM #tmpAssoc;
	
	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
		BEGIN
			SET @FDate = DATEADD(DD, 1, @MoveBetsDay);
		END;

		IF EXISTS (SELECT 1 FROM @tmpSport)
		BEGIN
			INSERT INTO #tmpMatchInfo(MatchID, HomeId, HomeName, AwayId, AwayName, EventDate, GlobalShowTime, EventStatus, SportType, LeagueId, LeagueName)
			SELECT	tmp.MatchID
				,	tmp.HomeId
				,	tmp.HomeName
				,	tmp.AwayId
				,	tmp.AwayName
				,	tmp.EventDate
				,	tmp.GlobalShowTime
				,	tmp.EventStatus
				,	tmp.SportType
				,	tmp.LeagueId
				,	tmp.LeagueName
			FROM (
					SELECT DISTINCT 
							match.MatchID
						,	match.HomeId
						,	h.TeamName AS HomeName
						,	match.AwayId
						,	a.TeamName AS AwayName
						,	match.EventDate
						,	match.GlobalShowTime
						,	match.EventStatus
						,	tmp.SportType
						,	l.LeagueId
						,	l.LeagueName
					FROM bodb02.dbo.Match AS match WITH(NOLOCK)
						INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON match.leagueid = l.leagueid
						INNER JOIN #tmpLeagueGroup AS lgroup WITH(NOLOCK) ON l.LeagueGroupID = ISNULL(lgroup.LeagueGroupID,l.LeagueGroupID)
						INNER JOIN bodb02.dbo.team AS h WITH(NOLOCK) ON h.TeamId = match.homeid 
						INNER JOIN bodb02.dbo.team AS a WITH(NOLOCK) ON a.TeamId = match.awayid
						INNER JOIN @tmpSport AS tmp ON match.Sporttype = tmp.SportType
						INNER JOIN @tmpMatchSection AS ms ON ms.EventStatus = match.eventstatus
					WHERE	match.EventDate >= @FDate 
							AND match.EventDate <= @TDate 
							AND l.IsTest = 0 AND match.isTestMatch = 0
							AND (CASE WHEN @IsExcludeSabaGroup = 1 AND l.LeagueGroupID NOT IN (42,74,108,113,122,151)
											AND EXISTS (SELECT 1 FROM @tmpSport AS s WHERE match.SportType = s.SportType) THEN 1
									  WHEN @IsExcludeSabaGroup = 0 AND l.LeagueGroupID NOT IN (42,74,108,113,122,151)
											AND EXISTS (SELECT 1 FROM @tmpSport AS s WHERE match.SportType = s.SportType) THEN 1
									  WHEN @IsExcludeSabaGroup = 0 AND l.LeagueGroupID IN (42,74,108,113,122,151)
											AND EXISTS (SELECT 1 FROM @tmpSportSabaLeagueGroup AS sl 
																	WHERE match.SportType = sl.SportType AND l.LeagueGroupID = sl.LeagueGroupID) THEN 1
									  ELSE 0 END = 1)
					) AS tmp
				WHERE (tmp.LeagueName LIKE '%' + @LeagueEvent + '%'
									OR tmp.HomeName LIKE '%' + @LeagueEvent + '%'
									OR tmp.AwayName LIKE '%' + @LeagueEvent + '%')
				;

		END;
		ELSE IF EXISTS (SELECT 1 FROM @tmpSportSabaLeagueGroup)
		BEGIN
			INSERT INTO #tmpMatchInfo(MatchID, HomeId, HomeName, AwayId, AwayName, EventDate, GlobalShowTime, EventStatus, SportType, LeagueId, LeagueName)
			SELECT	tmp.MatchID
				,	tmp.HomeId
				,	tmp.HomeName
				,	tmp.AwayId
				,	tmp.AwayName
				,	tmp.EventDate
				,	tmp.GlobalShowTime
				,	tmp.EventStatus
				,	tmp.SportType
				,	tmp.LeagueId
				,	tmp.LeagueName
			FROM (
					SELECT DISTINCT 
							m.MatchID
						,	m.HomeId
						,	home.TeamName AS HomeName
						,	m.AwayId
						,	away.TeamName AS AwayName
						,	m.EventDate
						,	m.GlobalShowTime
						,	m.EventStatus
						,	tmp.SportType
						,	l.LeagueId
						,	l.LeagueName
					FROM bodb02.dbo.Match AS m WITH(NOLOCK)
						INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
						INNER JOIN #tmpLeagueGroup AS lgroup WITH(NOLOCK) ON l.LeagueGroupID = ISNULL(lgroup.LeagueGroupID,l.LeagueGroupID)
						INNER JOIN bodb02.dbo.team AS home WITH(NOLOCK) ON home.TeamId = m.homeid 
						INNER JOIN bodb02.dbo.team AS away WITH(NOLOCK) ON away.TeamId = m.awayid
						INNER JOIN @tmpSportSabaLeagueGroup AS tmp ON m.Sporttype = tmp.SportType
						INNER JOIN @tmpMatchSection AS ms ON ms.EventStatus = m.eventstatus
					WHERE	m.EventDate >= @FDate 
							AND m.EventDate <= @TDate 
							AND l.IsTest = 0 AND m.isTestMatch = 0
							AND (CASE WHEN @IsExcludeSabaGroup = 1 AND l.LeagueGroupID NOT IN (42,74,108,113,122,151)
											AND EXISTS (SELECT 1 FROM @tmpSport AS s WHERE m.SportType = s.SportType) THEN 1
									  WHEN @IsExcludeSabaGroup = 0 AND l.LeagueGroupID NOT IN (42,74,108,113,122,151)
											AND EXISTS (SELECT 1 FROM @tmpSport AS s WHERE m.SportType = s.SportType) THEN 1
									  WHEN @IsExcludeSabaGroup = 0 AND l.LeagueGroupID IN (42,74,108,113,122,151)
											AND EXISTS (SELECT 1 FROM @tmpSportSabaLeagueGroup AS sl 
																	WHERE m.SportType = sl.SportType AND l.LeagueGroupID = sl.LeagueGroupID) THEN 1
									  ELSE 0 END = 1)
					) AS tmp
				WHERE (tmp.LeagueName LIKE '%' + @LeagueEvent + '%'
									OR tmp.HomeName LIKE '%' + @LeagueEvent + '%'
									OR tmp.AwayName LIKE '%' + @LeagueEvent + '%')
				;
		END;
		IF EXISTS (SELECT 1 FROM #tmpMatchInfo)
		BEGIN
			;WITH CTE_CustTrans AS(			
						SELECT	b.MatchId
							,	b.liveindicator
							,	b.bettype
							,	CASE WHEN m.SportType = @SPORTTYPE_CRICKET OR t.BetID = 0 THEN 0 ELSE b.BetId END AS BetID
							,	b.betteam
							,	b.stake
							,	b.actualrate
							,	c.CustID
							,	t.BetChoiceType
							,	t.BetChoiceHome
							,	t.BetChoiceAway
						FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
							INNER JOIN #tmpCustomer AS c WITH(NOLOCK) ON b.CustID = c.CustID
							INNER JOIN #tmpMatchInfo AS m WITH(NOLOCK) ON m.MatchId = b.matchid
							CROSS APPLY (
								SELECT bt.BetID, bt.BetChoiceType,bt.BetChoiceHome,bt.BetChoiceAway
								FROM #tmpBetType AS bt WITH(NOLOCK)
								WHERE b.Bettype = bt.Bettype 
							) AS t
						WHERE b.BetID = CASE WHEN m.SportType = @SPORTTYPE_CRICKET OR t.BetID = 0 THEN b.BetID ELSE t.BetID END)
			INSERT INTO #tmpMatchSum_Group(RootCustID, MatchId, LiveIndicator, BetChoiceType, Bettype, BetID, TotalAmountHome, TotalAmountAway, TotalTicketHome, TotalTicketAway, ListCustID, IsFrom14)
			SELECT 	a.RootCustID
				,	tmpCust.MatchId
				,	tmpCust.LiveIndicator
				,	tmpCust.BetChoiceType
				,	tmpCust.Bettype
				,	tmpCust.BetID
				,	SUM(CASE WHEN tmpCust.CustAmountHome >= @UserAmount THEN tmpCust.CustAmountHome ELSE 0 END) AS AmountHome
				,	SUM(CASE WHEN tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustAmountAway ELSE 0 END) AS AmountWay
				,	SUM(CASE WHEN tmpCust.CustAmountHome >= @UserAmount THEN tmpCust.CustTicketHome ELSE 0 END) AS TicketHome
				,	SUM(CASE WHEN tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustTicketAway ELSE 0 END) AS TicketAway
				,	STRING_AGG(CAST(CASE WHEN tmpCust.CustAmountHome >= @UserAmount OR tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustID ELSE NULL END AS VARCHAR(MAX)),',') AS ListCustID
				,	0 AS IsFrom14
			FROM (
					SELECT 	tmp.MatchId
						,	tmp.LiveIndicator
						,	tmp.BetChoiceType
						,	tmp.Bettype
						,	tmp.BetID
						,	tmp.CustID
						,	SUM(CASE WHEN tmp.BetChoiceType = 2 AND tmp.betteam = tmp.BetChoiceHome THEN tmp.stake * tmp.actualrate 
									 WHEN tmp.BetChoiceType = 1 THEN tmp.stake * tmp.actualrate 
									 ELSE 0 END) AS CustAmountHome
						,	SUM(CASE WHEN tmp.BetChoiceType = 2 AND tmp.betteam = tmp.BetChoiceAway THEN tmp.stake * tmp.actualrate 
									 ELSE 0 END) AS CustAmountAway
						,	SUM(CASE WHEN tmp.BetChoiceType = 2 AND tmp.betteam = tmp.BetChoiceHome THEN 1 
									 WHEN tmp.BetChoiceType = 1 THEN 1
									 ELSE 0 END) AS CustTicketHome
						,	SUM(CASE WHEN tmp.BetChoiceType = 2 AND tmp.betteam = tmp.BetChoiceAway THEN 1 
									 ELSE 0 END) AS CustTicketAway
					FROM CTE_CustTrans AS tmp
						INNER JOIN #tmpMatchInfo AS m WITH(NOLOCK) ON m.MatchId = tmp.MatchId					
					WHERE (CASE WHEN @MarketList = '' THEN 1
								  WHEN @MarketList <> '' AND tmp.LiveIndicator IN (SELECT ssk.value FROM STRING_SPLIT (@MarketList, ',') AS ssk) THEN 1
								  ELSE 0 END = 1)
					GROUP BY tmp.MatchId, tmp.BetChoiceType, tmp.Bettype, tmp.LiveIndicator, tmp.BetId, tmp.CustID

				) AS tmpCust
				INNER JOIN #tmpAssoc AS a ON a.CustID = tmpCust.CustID
					WHERE tmpCust.CustAmountHome >= @UserAmount
						OR tmpCust.CustAmountAway >= @UserAmount
					GROUP BY a.RootCustID, tmpCust.MatchId, tmpCust.BetChoiceType, tmpCust.Bettype, tmpCust.LiveIndicator, tmpCust.BetId
					HAVING (SUM(tmpCust.CustAmountHome) >=  @TotalAmount OR SUM(tmpCust.CustAmountAway) >=  @TotalAmount)
						AND SUM(CASE WHEN a.CustID = a.RootCustID THEN 1 ELSE 0 END) > 0 --Only Root
						AND SUM(CASE WHEN a.CustID <> a.RootCustID THEN 1 ELSE 0 END) > 0  -- Only Association
					OPTION (RECOMPILE) ;

			IF (@@ROWCOUNT > 0)
			BEGIN
				SET @IsFromActive14 = 1;
			END;
		END;
	END;

	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @BalanceUpDay < @FromDate
		BEGIN
			SET @FDate = @FromDate;
		END
		ELSE
		BEGIN
			SET @FDate = @BalanceUpDay;
		END;
			
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TDate = @MoveBetsDay;
		END;

		IF EXISTS (SELECT 1 FROM @tmpSport)
		BEGIN
			INSERT INTO #tmpMatchInfo14(MatchID, HomeId, HomeName, AwayId, AwayName, EventDate, GlobalShowTime, EventStatus, SportType, LeagueId, LeagueName)
			SELECT	tmp.MatchID
				,	tmp.HomeId
				,	tmp.HomeName
				,	tmp.AwayId
				,	tmp.AwayName
				,	tmp.EventDate
				,	tmp.GlobalShowTime
				,	tmp.EventStatus
				,	tmp.SportType
				,	tmp.LeagueId
				,	tmp.LeagueName
			FROM (
					SELECT DISTINCT 
							m.MatchID
						,	m.HomeId
						,	h.TeamName AS HomeName
						,	m.AwayId
						,	a.TeamName AS AwayName
						,	m.EventDate
						,	m.GlobalShowTime
						,	m.EventStatus
						,	tmp.SportType
						,	l.LeagueId
						,	l.LeagueName
					FROM bodb02.dbo.Match14 AS m WITH(NOLOCK)
						INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
						INNER JOIN #tmpLeagueGroup AS lg WITH(NOLOCK) ON l.LeagueGroupID = ISNULL(lg.LeagueGroupID,l.LeagueGroupID)
						INNER JOIN bodb02.dbo.team AS h WITH(NOLOCK) ON h.TeamId = m.homeid 
						INNER JOIN bodb02.dbo.team AS a WITH(NOLOCK) ON a.TeamId = m.awayid
						INNER JOIN @tmpSport AS tmp ON m.Sporttype = tmp.SportType
						INNER JOIN @tmpMatchSection AS ms ON ms.EventStatus = m.eventstatus
					WHERE	m.EventDate >= @FDate 
							AND m.EventDate <= @TDate 							
							AND l.IsTest = 0 AND m.isTestMatch = 0
							AND (CASE WHEN @IsExcludeSabaGroup = 1 AND l.LeagueGroupID NOT IN (42,74,108,113,122,151)
											AND EXISTS (SELECT 1 FROM @tmpSport AS s WHERE m.SportType = s.SportType) THEN 1
									  WHEN @IsExcludeSabaGroup = 0 AND l.LeagueGroupID NOT IN (42,74,108,113,122,151)
											AND EXISTS (SELECT 1 FROM @tmpSport AS s WHERE m.SportType = s.SportType) THEN 1
									  WHEN @IsExcludeSabaGroup = 0 AND l.LeagueGroupID IN (42,74,108,113,122,151)
											AND EXISTS (SELECT 1 FROM @tmpSportSabaLeagueGroup AS sl 
																	WHERE m.SportType = sl.SportType AND l.LeagueGroupID = sl.LeagueGroupID) THEN 1
									  ELSE 0 END = 1)
					) AS tmp
				WHERE (tmp.LeagueName LIKE '%' + @LeagueEvent + '%'
									OR tmp.HomeName LIKE '%' + @LeagueEvent + '%'
									OR tmp.AwayName LIKE '%' + @LeagueEvent + '%')
				;
			END;
			ELSE IF EXISTS (SELECT 1 FROM @tmpSportSabaLeagueGroup)				
			BEGIN
				INSERT INTO #tmpMatchInfo14(MatchID, HomeId, HomeName, AwayId, AwayName, EventDate, GlobalShowTime, EventStatus, SportType, LeagueId, LeagueName)
				SELECT	tmp.MatchID
					,	tmp.HomeId
					,	tmp.HomeName
					,	tmp.AwayId
					,	tmp.AwayName
					,	tmp.EventDate
					,	tmp.GlobalShowTime
					,	tmp.EventStatus
					,	tmp.SportType
					,	tmp.LeagueId
					,	tmp.LeagueName
				FROM (
						SELECT DISTINCT 
								m.MatchID
							,	m.HomeId
							,	h.TeamName AS HomeName
							,	m.AwayId
							,	a.TeamName AS AwayName
							,	m.EventDate
							,	m.GlobalShowTime
							,	m.EventStatus
							,	tmp.SportType
							,	l.LeagueId
							,	l.LeagueName
						FROM bodb02.dbo.Match14 AS m WITH(NOLOCK)
							INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
							INNER JOIN #tmpLeagueGroup AS lg WITH(NOLOCK) ON l.LeagueGroupID = ISNULL(lg.LeagueGroupID,l.LeagueGroupID)
							INNER JOIN bodb02.dbo.team AS h WITH(NOLOCK) ON h.TeamId = m.homeid 
							INNER JOIN bodb02.dbo.team AS a WITH(NOLOCK) ON a.TeamId = m.awayid
							INNER JOIN @tmpSportSabaLeagueGroup AS tmp ON m.Sporttype = tmp.SportType
							INNER JOIN @tmpMatchSection AS ms ON ms.EventStatus = m.eventstatus
						WHERE	m.EventDate >= @FDate 
								AND m.EventDate <= @TDate 							
								AND l.IsTest = 0 AND m.isTestMatch = 0
								AND (CASE WHEN @IsExcludeSabaGroup = 1 AND l.LeagueGroupID NOT IN (42,74,108,113,122,151)
												AND EXISTS (SELECT 1 FROM @tmpSport AS s WHERE m.SportType = s.SportType) THEN 1
										  WHEN @IsExcludeSabaGroup = 0 AND l.LeagueGroupID NOT IN (42,74,108,113,122,151)
												AND EXISTS (SELECT 1 FROM @tmpSport AS s WHERE m.SportType = s.SportType) THEN 1
										  WHEN @IsExcludeSabaGroup = 0 AND l.LeagueGroupID IN (42,74,108,113,122,151)
												AND EXISTS (SELECT 1 FROM @tmpSportSabaLeagueGroup AS sl 
																		WHERE m.SportType = sl.SportType AND l.LeagueGroupID = sl.LeagueGroupID) THEN 1
										  ELSE 0 END = 1)
						) AS tmp
					WHERE (tmp.LeagueName LIKE '%' + @LeagueEvent + '%'
										OR tmp.HomeName LIKE '%' + @LeagueEvent + '%'
										OR tmp.AwayName LIKE '%' + @LeagueEvent + '%');
			END
  
  IF Exists (SELECT 1 FROM #tmpMatchInfo14) 
  BEGIN

		INSERT INTO #tmpCustTrans(MatchId,Liveindicator,Bettype,BetId,Betteam,Stake,Actualrate,CustID)
		SELECT	b.MatchId
			,	b.Liveindicator
			,	b.Bettype
			,	CASE WHEN m.SportType = @SPORTTYPE_CRICKET THEN 0 ELSE b.BetId END AS BetID
			,	b.Betteam
			,	b.Stake
			,	b.Actualrate
			,	c.CustID							
		FROM bodb02.dbo.bettrans14 AS b WITH(NOLOCK)
			INNER JOIN #tmpCustomer AS c WITH(NOLOCK) ON b.CustID = c.CustID
			INNER JOIN #tmpMatchInfo14 AS m WITH(NOLOCK) ON m.MatchId = b.MatchId

		CREATE CLUSTERED INDEX CIX_tmpCustTrans ON #tmpCustTrans(MatchID);

		INSERT INTO #tmpMatchSum_Group(RootCustID, MatchId, LiveIndicator,BetChoiceType, Bettype,BetID, TotalAmountHome, TotalAmountAway, TotalTicketHome, TotalTicketAway, ListCustID, IsFrom14)
		SELECT	a.RootCustID
			,	tmpCust.MatchId
			,	tmpCust.LiveIndicator
			,	tmpCust.BetChoiceType
			,	tmpCust.Bettype
			,	tmpCust.BetID
			,	SUM(CASE WHEN tmpCust.CustAmountHome >= @UserAmount THEN tmpCust.CustAmountHome ELSE 0 END) AS AmountHome
			,	SUM(CASE WHEN tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustAmountAway ELSE 0 END) AS AmountWay
			,	SUM(CASE WHEN tmpCust.CustAmountHome >= @UserAmount THEN tmpCust.CustTicketHome ELSE 0 END) AS TicketHome
			,	SUM(CASE WHEN tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustTicketAway ELSE 0 END) AS TicketAway
			,	STRING_AGG(CAST(CASE WHEN tmpCust.CustAmountHome >= @UserAmount OR tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustID ELSE NULL END AS VARCHAR(MAX)),',') AS ListCustID
			,	1 AS IsFrom14
		FROM (
			SELECT 	tmp.MatchId
				,	tmp.LiveIndicator
				,	t.BetChoiceType
				,	tmp.Bettype
				,	tmp.CustID
				,	CASE WHEN t.BetID = 0 THEN 0 ELSE tmp.BetID END AS BetID
				,	SUM(CASE WHEN t.BetChoiceType = 2 AND tmp.betteam = t.BetChoiceHome THEN tmp.stake * tmp.actualrate 
							 WHEN t.BetChoiceType = 1 THEN tmp.stake * tmp.actualrate 
							 ELSE 0 END) AS CustAmountHome
				,	SUM(CASE WHEN t.BetChoiceType = 2 AND tmp.betteam = t.BetChoiceAway THEN tmp.stake * tmp.actualrate 
							 ELSE 0 END) AS CustAmountAway
				,	SUM(CASE WHEN t.BetChoiceType = 2 AND tmp.betteam = t.BetChoiceHome THEN 1 
							 WHEN t.BetChoiceType = 1 THEN 1
							 ELSE 0 END) AS CustTicketHome
				,	SUM(CASE WHEN t.BetChoiceType = 2 AND tmp.betteam = t.BetChoiceAway THEN 1 
							 ELSE 0 END) AS CustTicketAway
			FROM #tmpCustTrans AS tmp
				CROSS APPLY (
						SELECT bt.BetID, bt.BetChoiceType,bt.BetChoiceHome,bt.BetChoiceAway
						FROM #tmpBetType AS bt WITH(NOLOCK)
						WHERE tmp.Bettype = bt.Bettype 
					) AS t
		
			WHERE tmp.BetID = CASE WHEN t.BetID = 0 THEN tmp.BetID ELSE t.BetID END
				AND (CASE WHEN @MarketList = '' THEN 1
						  WHEN @MarketList <> '' AND tmp.LiveIndicator IN (SELECT ssk.value FROM STRING_SPLIT (@MarketList, ',') AS ssk) THEN 1
						  ELSE 0 END = 1)
			GROUP BY tmp.MatchId, t.BetChoiceType, tmp.Bettype, tmp.LiveIndicator, tmp.BetId, t.BetID, tmp.CustID
			) AS tmpCust
			INNER JOIN #tmpAssoc AS a ON a.CustID = tmpCust.CustID
				WHERE tmpCust.CustAmountHome >= @UserAmount
				OR tmpCust.CustAmountAway >= @UserAmount
				GROUP BY a.RootCustID, tmpCust.MatchId, tmpCust.BetChoiceType, tmpCust.Bettype, tmpCust.LiveIndicator, tmpCust.BetId
				HAVING (SUM(tmpCust.CustAmountHome) >=  @TotalAmount OR SUM(tmpCust.CustAmountAway) >=  @TotalAmount)
						AND SUM(CASE WHEN a.CustID = a.RootCustID THEN 1 ELSE 0 END) > 0
						AND SUM(CASE WHEN a.CustID <> a.RootCustID THEN 1 ELSE 0 END) > 0
			OPTION (RECOMPILE) ;	

		IF (@@ROWCOUNT > 0)
		BEGIN
			IF EXISTS (SELECT 1 FROM @tmpMatchSection WHERE Id = @MatchSection_Closed)
			BEGIN
				INSERT INTO @tmpMatchSection (Id, IsFrom14, EventStatus)
				SELECT @MatchSection_Closed, 1, X.a
				FROM (VALUES ('Completed'),('Closed'),('Postponed'),('internal'))  AS X(a);
			END;
			
			IF (@IsFromActive14 = 0)
			BEGIN
				SET @IsFromActive14 = 2;
			END
			ELSE
			BEGIN
				SET @IsFromActive14 = 3;
			END;
		END;
	END
END;
	
	CREATE CLUSTERED INDEX CIX_tmpMatchSum_Group ON #tmpMatchSum_Group(Bettype);	

	IF @IsFromActive14 = 1
	BEGIN
		SELECT 	tms.RootCustID
			,	tms.MatchId
			,	m.leagueid AS LeagueId
			,	m.LeagueName
			,	m.EventDate
			,	m.GlobalShowTime
			,	mss.MatchSection
			,	m.SportType
			,	m.homeid AS HomeId
			,	m.HomeName
			,	m.awayid AS AwayId
			,	m.AwayName
			,	tms.LiveIndicator
			,	tms.Bettype
			,	tms.BetID
			,	tms.BetChoiceType
			,	tms.TotalAmountHome
			,	tms.TotalAmountAway
			,	tms.TotalTicketHome
			,	tms.TotalTicketAway
			,	tms.IsFrom14
			,	tms.ListCustID
			FROM #tmpMatchSum_Group AS tms
				INNER JOIN #tmpMatchInfo AS m WITH(NOLOCK) ON m.MatchId = tms.MatchId AND tms.IsFrom14 = 0
				CROSS APPLY (SELECT TOP 1 ms.Id AS MatchSection
							 FROM @tmpMatchSection AS ms
							 WHERE ms.IsFrom14 = 0
								AND 1 = CASE WHEN m.EventStatus <> 'completed' THEN (CASE WHEN ms.Id = @MatchSection_Live AND m.GlobalShowTime <= GETDATE() THEN 1
																						WHEN ms.Id = @MatchSection_Today AND m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 1
																						WHEN ms.Id = @MatchSection_Early AND m.EventDate > @Today THEN 1 END)
											 WHEN m.EventStatus = ms.EventStatus AND ms.Id = @MatchSection_Closed THEN 1
											 ELSE 0 END) AS mss
		-- OPTION (RECOMPILE)
		;
	END
	ELSE IF @IsFromActive14 = 2
	BEGIN
		SELECT 	tms.RootCustID
			,	tms.MatchId
			,	m.leagueid AS LeagueId
			,	m.LeagueName
			,	m.EventDate
			,	m.GlobalShowTime
			,	mss.MatchSection
			,	m.SportType
			,	m.homeid AS HomeId
			,	m.HomeName
			,	m.awayid AS AwayId
			,	m.AwayName
			,	tms.LiveIndicator
			,	tms.Bettype
			,	tms.BetID
			,	tms.BetChoiceType
			,	tms.TotalAmountHome
			,	tms.TotalAmountAway
			,	tms.TotalTicketHome
			,	tms.TotalTicketAway
			,	tms.IsFrom14
			,	tms.ListCustID
			FROM #tmpMatchSum_Group AS tms
				INNER JOIN #tmpMatchInfo14 AS m WITH(NOLOCK) ON m.MatchId = tms.MatchId AND tms.IsFrom14 = 1
				CROSS APPLY (SELECT TOP 1 ms.Id AS MatchSection
							 FROM @tmpMatchSection AS ms
							 WHERE ms.IsFrom14 = 1
								AND 1 = CASE WHEN m.EventStatus <> 'completed' THEN (CASE WHEN ms.Id = @MatchSection_Live AND m.GlobalShowTime <= GETDATE() THEN 1
																						WHEN ms.Id = @MatchSection_Today AND m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 1
																						WHEN ms.Id = @MatchSection_Early AND m.EventDate > @Today THEN 1 END)
											 WHEN m.EventStatus = ms.EventStatus AND ms.Id = @MatchSection_Closed THEN 1
											 ELSE 0 END) AS mss
		-- OPTION (RECOMPILE)
		;
	END
	ELSE
	BEGIN
		SELECT 	tms.RootCustID
			,	tms.MatchId
			,	m.leagueid AS LeagueId
			,	m.LeagueName
			,	m.EventDate
			,	m.GlobalShowTime
			,	mss.MatchSection
			,	m.SportType
			,	m.homeid AS HomeId
			,	m.HomeName
			,	m.awayid AS AwayId
			,	m.AwayName
			,	tms.LiveIndicator
			,	tms.Bettype
			,	tms.BetID
			,	tms.BetChoiceType
			,	tms.TotalAmountHome
			,	tms.TotalAmountAway
			,	tms.TotalTicketHome
			,	tms.TotalTicketAway
			,	tms.IsFrom14
			,	tms.ListCustID
			FROM #tmpMatchSum_Group AS tms
				INNER JOIN #tmpMatchInfo AS m WITH(NOLOCK) ON m.MatchId = tms.MatchId AND tms.IsFrom14 = 0
				CROSS APPLY (SELECT TOP 1 ms.Id AS MatchSection
							 FROM @tmpMatchSection AS ms
							 WHERE ms.IsFrom14 = 0
								AND 1 = CASE WHEN m.EventStatus <> 'completed' THEN (CASE WHEN ms.Id = @MatchSection_Live AND m.GlobalShowTime <= GETDATE() THEN 1
																						WHEN ms.Id = @MatchSection_Today AND m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 1
																						WHEN ms.Id = @MatchSection_Early AND m.EventDate > @Today THEN 1 END)
											 WHEN m.EventStatus = ms.EventStatus AND ms.Id = @MatchSection_Closed THEN 1
											 ELSE 0 END) AS mss
			
		UNION ALL
		SELECT 	tms.RootCustID
			,	tms.MatchId
			,	m.leagueid AS LeagueId
			,	m.LeagueName
			,	m.EventDate
			,	m.GlobalShowTime
			,	mss.MatchSection
			,	m.SportType
			,	m.homeid AS HomeId
			,	m.HomeName
			,	m.awayid AS AwayId
			,	m.AwayName
			,	tms.LiveIndicator
			,	tms.Bettype
			,	tms.BetID
			,	tms.BetChoiceType
			,	tms.TotalAmountHome
			,	tms.TotalAmountAway
			,	tms.TotalTicketHome
			,	tms.TotalTicketAway
			,	tms.IsFrom14
			,	tms.ListCustID
			FROM #tmpMatchSum_Group AS tms
				INNER JOIN #tmpMatchInfo14 AS m WITH(NOLOCK) ON m.MatchId = tms.MatchId AND tms.IsFrom14 = 1
				CROSS APPLY (SELECT TOP 1 ms.Id AS MatchSection
							 FROM @tmpMatchSection AS ms
							 WHERE ms.IsFrom14 = 1
								AND 1 = CASE WHEN m.EventStatus <> 'completed' THEN (CASE WHEN ms.Id = @MatchSection_Live AND m.GlobalShowTime <= GETDATE() THEN 1
																						WHEN ms.Id = @MatchSection_Today AND m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 1
																						WHEN ms.Id = @MatchSection_Early AND m.EventDate > @Today THEN 1 END)
											 WHEN m.EventStatus = ms.EventStatus AND ms.Id = @MatchSection_Closed THEN 1
											 ELSE 0 END) AS mss
		-- OPTION (RECOMPILE)
		;
	END;	

	DROP TABLE IF EXISTS #tmpBetType;
	DROP TABLE IF EXISTS #tmpCustomer;
	DROP TABLE IF EXISTS #tmpMatchSum_Group;
	DROP TABLE IF EXISTS #tmpMatchInfo;
	DROP TABLE IF EXISTS #tmpMatchInfo14;
	DROP TABLE IF EXISTS #tmpCustTrans;

END;
