/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CTS_Rpt_MatchMonitor_MatchInfo]
		@MatchIds			VARCHAR(MAX) = ''
	,	@SportList			VARCHAR(100) = ''
	,	@FromDateTime		DATETIME
	,	@ToDateTime			DATETIME
	,	@MatchSection		VARCHAR(20)
	,	@Event				VARCHAR(200) = ''
AS
/*
	Created: 20230214@Victoria.Le
	Task : Get Match Info
	DB	 : bodb02

	Revisions:
		- 20230214@Victoria.Le:		Initial Writing [Redmine ID: #183280]
		- 20230601@Victoria.Le:		Return IsGetDataFromOrigin [Redmine ID: #185793]
		- 20231116@Long.Luu: 		Return match's datasource [Redmine ID: 195042]
		- 20240826@Casey.Huynh: 	Add Fitler Event and return LeagueName, HomeName, ScoreName	[Redmine ID: 152883]
		- 20250211@Tony.Nguyen:		Add SportList [Redmine ID: 217782]
		- 20250401@Logan.Nguyen:	Handle duplicate primary key temporary table [Redmine ID: #219106]

	Params Explaination:
		- @MatchIds:
			+ @MatchIds = ''	==> Get Match Info by EventDate (FromDateTime & ToDateTime)
			+ @MatchIds <> ''	==> Get Match Info by List MatchId
	
	Filter by ScanDate:
		EXECUTE [dbo].[CTS_Rpt_MatchMonitor_MatchInfo]
				@MatchIds = '83677751,83677753,83677755'
			,	@SportList = ''
			,	@FromDateTime = ''
			,	@ToDateTime = ''
			,	@MatchSection = '1,2,3,4'
			,	@Event='TA'
	Filter by EventDate:
		EXECUTE [dbo].[CTS_Rpt_MatchMonitor_MatchInfo] 
				@MatchIds = ''
			,	@SportList = '1,2,43,50'
			,	@FromDateTime = '2024-08-30'
			,	@ToDateTime = '2024-08-30'
			,	@MatchSection = '1,2,3,4'
			--,	@Event= NULL
			--,	@Event= ''
			,	@Event= 'TA'
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Today			DATE = GETDATE()

	IF @Event IS NULL
	BEGIN
		SET @Event = ''
	END

	IF	OBJECT_ID('tempdb..#tmpMatchSection') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchSection
	END

	CREATE TABLE #tmpMatchSection (
			MatchSection		TINYINT
	)

	IF	OBJECT_ID('tempdb..#tmpMatchesInfo') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchesInfo
	END

	CREATE TABLE #tmpMatchesInfo (
			MatchId				INT NOT NULL 
		,	HomeId				INT
		,	AwayId				INT
		,	LeagueId			INT
		,	EventDate			DATETIME
		,	KickOffTime			DATETIME
		,	MatchSection		TINYINT
		,	IsGetDataFromOrigin	BIT
		,	DataSource			TINYINT DEFAULT 0 -- 0: Origin; 1: 14; 2: _bk 
	)

	INSERT INTO #tmpMatchSection (MatchSection)
	SELECT DISTINCT ms.value FROM STRING_SPLIT (@MatchSection, ',') ms

	IF ISNULL(@MatchIds,'') = '' AND ISNULL(@SportList,'') <> ''
	BEGIN
		
		DECLARE @BalanceUpDay			SMALLDATETIME
			,	@MoveBetsDay			SMALLDATETIME

		DECLARE @IsGetDataFromOrigin	BIT = 0
			,	@IsGetDataFrom14		BIT = 0
			,	@IsGetDataFromBK		BIT = 0

		DECLARE @FromDateOrigin			SMALLDATETIME = NULL
			,	@ToDateOrigin			SMALLDATETIME = NULL
			,	@FromDate14				SMALLDATETIME = NULL
			,	@ToDate14				SMALLDATETIME = NULL
			,	@FromDateBK				SMALLDATETIME = NULL
			,	@ToDateBK				SMALLDATETIME = NULL
	
		IF	OBJECT_ID('tempdb..#BUMBData') IS NOT NULL
		BEGIN
			DROP TABLE	#BUMBData
		END

		CREATE TABLE	#BUMBData (
				BUDay	SMALLDATETIME
			,	MBDay	SMALLDATETIME
		)

		IF	OBJECT_ID('tempdb..#tmpSportList') IS NOT NULL
		BEGIN
			DROP TABLE #tmpSportList
		END

		CREATE TABLE #tmpSportList (
				SportType			TINYINT
		)

		INSERT INTO #tmpSportList (SportType)
		SELECT st.value FROM STRING_SPLIT (@SportList, ',') st

		INSERT INTO #BUMBData(BUDay,MBDay)
		EXECUTE bodb02.dbo.Age_SelBalanceUpDay

		SELECT	TOP(1)
				@BalanceUpDay	= BUDay
			,	@MoveBetsDay	= MBDay
		FROM #BUMBData WITH(NOLOCK)
		
		-- For @FromDateTime
		IF @FromDateTime < @BalanceUpDay
		BEGIN
			SET @IsGetDataFromBK = 1
		END
		ELSE IF @FromDateTime <= @MoveBetsDay
		BEGIN
			SET @IsGetDataFrom14 = 1
		END
		ELSE IF @FromDateTime > @MoveBetsDay
		BEGIN
			SET @IsGetDataFromOrigin = 1
		END

		-- For @ToDateTime
		IF @ToDateTime < @BalanceUpDay
		BEGIN
			SET @IsGetDataFromBK = 1
		END
		ELSE IF @ToDateTime <= @MoveBetsDay
		BEGIN
			SET @IsGetDataFrom14 = 1
		END
		ELSE IF @ToDateTime > @MoveBetsDay
		BEGIN
			SET @IsGetDataFromOrigin = 1
		END

		IF @FromDateTime < @BalanceUpDay AND @ToDateTime > @MoveBetsDay
		BEGIN
			SET @IsGetDataFromBK		= 1
			SET @IsGetDataFrom14		= 1
			SET @IsGetDataFromOrigin	= 1
		END

		IF (@IsGetDataFromBK = 1 AND @IsGetDataFromOrigin = 1)
			OR (@IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 1)
		BEGIN
			SELECT	@FromDateOrigin		=	DATEADD(DD,1,@MoveBetsDay)
				,	@ToDateOrigin		=	@ToDateTime
				,	@FromDate14			=	@BalanceUpDay
				,	@ToDate14			=	@MoveBetsDay
				,	@FromDateBK			=	@FromDateTime 
				,	@ToDateBK			=	DATEADD(DD,-1,@BalanceUpDay)
		END

		IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 0
		BEGIN
			SELECT	@FromDate14			=	@BalanceUpDay
				,	@ToDate14			=	@ToDateTime
				,	@FromDateBK			=	@FromDateTime 
				,	@ToDateBK			=	DATEADD(DD,-1,@BalanceUpDay)
		END

		IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 1
		BEGIN
			SELECT	@FromDateOrigin		=	DATEADD(DD,1,@MoveBetsDay)
				,	@ToDateOrigin		=	@ToDateTime
				,	@FromDate14			=	@FromDateTime
				,	@ToDate14			=	@MoveBetsDay
		END

		IF @IsGetDataFromBK = 1 AND @IsGetDataFrom14 = 0 AND @IsGetDataFromOrigin = 0
		BEGIN
			SELECT	@FromDateBK			=	@FromDateTime 
				,	@ToDateBK			=	@ToDateTime
		END

		IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 1 AND @IsGetDataFromOrigin = 0
		BEGIN
			SELECT	@FromDate14			=	@FromDateTime
				,	@ToDate14			=	@ToDateTime
		END

		IF @IsGetDataFromBK = 0 AND @IsGetDataFrom14 = 0 AND @IsGetDataFromOrigin = 1
		BEGIN
			SELECT	@FromDateOrigin		=	@FromDateTime
				,	@ToDateOrigin		=	@ToDateTime
		END

		IF	@IsGetDataFromBK = 1
		BEGIN
			INSERT INTO #tmpMatchesInfo (MatchId,HomeId,AwayId,LeagueId,EventDate,KickOffTime,MatchSection,IsGetDataFromOrigin,DataSource)
			SELECT	m.MatchId
				,	m.HomeId
				,	m.AwayId
				,	m.LeagueId
				,	m.EventDate
				,	m.GlobalShowTime
				,	CASE
						WHEN m.eventstatus <> 'completed' THEN (CASE 
																	WHEN m.GlobalShowTime <= GETDATE() THEN 1 --LIVE
																	WHEN m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 2 --TODAY
																	WHEN m.EventDate > @Today THEN 3 -- EARLY
																END)
						ELSE 4 -- CLOSED
					END
				,	0 AS IsGetDataFromOrigin
				,	2 AS DataSource
			FROM bodb_Archive.dbo.match_bk AS m WITH(NOLOCK)
			INNER JOIN #tmpSportList AS tsl ON m.sporttype = tsl.SportType
			WHERE m.EventDate BETWEEN @FromDateBK AND @ToDateBK

		END

		IF	@IsGetDataFrom14 = 1
		BEGIN
			INSERT INTO #tmpMatchesInfo (MatchId,HomeId,AwayId,LeagueId,EventDate,KickOffTime,MatchSection,IsGetDataFromOrigin,DataSource)
			SELECT	m.MatchId
				,	m.HomeId
				,	m.AwayId
				,	m.LeagueId				
				,	m.EventDate
				,	m.GlobalShowTime
				,	CASE
						WHEN m.eventstatus <> 'completed' THEN (CASE 
																	WHEN m.GlobalShowTime <= GETDATE() THEN 1 --LIVE
																	WHEN m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 2 --TODAY
																	WHEN m.EventDate > @Today THEN 3 -- EARLY
																END)
						ELSE 4 -- CLOSED
					END
				,	0 AS IsGetDataFromOrigin
				,	1 AS DataSource
			FROM bodb02.dbo.match14 AS m WITH(NOLOCK)
			INNER JOIN #tmpSportList AS tsl ON m.sporttype = tsl.SportType
			WHERE m.EventDate BETWEEN @FromDate14 AND @ToDate14

		END

		IF	@IsGetDataFromOrigin = 1
		BEGIN
			INSERT INTO #tmpMatchesInfo (MatchId,HomeId,AwayId,LeagueId,EventDate,KickOffTime,MatchSection,IsGetDataFromOrigin,DataSource)
			SELECT	m.MatchId
				,	m.HomeId
				,	m.AwayId
				,	m.leagueid
				,	m.EventDate
				,	m.GlobalShowTime
				,	CASE
						WHEN m.eventstatus <> 'completed' THEN (CASE 
																	WHEN m.GlobalShowTime <= GETDATE() THEN 1 --LIVE
																	WHEN m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 2 --TODAY
																	WHEN m.EventDate > @Today THEN 3 -- EARLY
																END)
						ELSE 4 -- CLOSED
					END
				,	@IsGetDataFromOrigin AS IsGetDataFromOrigin
				,	0 AS DataSource
			FROM bodb02.dbo.Match AS m WITH(NOLOCK)
			INNER JOIN #tmpSportList AS tsl ON m.sporttype = tsl.SportType
			WHERE m.EventDate BETWEEN @FromDateOrigin AND @ToDateOrigin

		END
	
		DROP TABLE #BUMBData
		DROP TABLE #tmpSportList
	END
	ELSE
	IF ISNULL(@MatchIds,'') <> ''
	BEGIN

		IF	OBJECT_ID('tempdb..#tmpMatches') IS NOT NULL
		BEGIN
			DROP TABLE #tmpMatches
		END

		CREATE TABLE #tmpMatches(
				MatchId				INT NOT NULL PRIMARY KEY
		)

		INSERT INTO #tmpMatches (MatchId)
		SELECT ssk.value FROM STRING_SPLIT (@MatchIds, ',') ssk

		--FromBK
		INSERT INTO #tmpMatchesInfo (MatchId,HomeId,AwayId,LeagueId,EventDate,KickOffTime,MatchSection,IsGetDataFromOrigin,DataSource)
		SELECT	m.MatchId
			,	m.HomeId
			,	m.AwayId
			,	m.leagueid
			,	m.EventDate
			,	m.GlobalShowTime
			,	CASE
					WHEN m.eventstatus <> 'completed' THEN (CASE 
																WHEN m.GlobalShowTime <= GETDATE() THEN 1 --LIVE
																WHEN m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 2 --TODAY
																WHEN m.EventDate > @Today THEN 3 -- EARLY
															END)
					ELSE 4 -- CLOSED
				END
			,	0 AS IsGetDataFromOrigin
			,	2 AS DataSource
		FROM #tmpMatches AS tm 
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON tm.MatchId = m.matchid
		
		DELETE tm
		FROM #tmpMatches AS tm
		INNER JOIN #tmpMatchesInfo AS m ON tm.MatchId = m.matchid

		--From14
		INSERT INTO #tmpMatchesInfo (MatchId,HomeId,AwayId,LeagueId,EventDate,KickOffTime,MatchSection,IsGetDataFromOrigin,DataSource)
		SELECT	m.MatchId
			,	m.HomeId
			,	m.AwayId
			,	m.leagueid
			,	m.EventDate
			,	m.GlobalShowTime
			,	CASE
					WHEN m.eventstatus <> 'completed' THEN (CASE 
																WHEN m.GlobalShowTime <= GETDATE() THEN 1 --LIVE
																WHEN m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 2 --TODAY
																WHEN m.EventDate > @Today THEN 3 -- EARLY
															END)
					ELSE 4 -- CLOSED
				END
			,	0 AS IsGetDataFromOrigin
			,	1 AS DataSource
		FROM #tmpMatches AS tm 
			INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON tm.MatchId = m.matchid

		DELETE tm
		FROM #tmpMatches AS tm
		INNER JOIN #tmpMatchesInfo AS m ON tm.MatchId = m.matchid

		-- FromOrigin
		INSERT INTO #tmpMatchesInfo (MatchId,HomeId,AwayId,LeagueId,EventDate,KickOffTime,MatchSection,IsGetDataFromOrigin,DataSource)
		SELECT	m.MatchId
			,	m.HomeId
			,	m.AwayId
			,	m.leagueid
			,	m.EventDate
			,	m.GlobalShowTime
			,	CASE
					WHEN m.eventstatus <> 'completed' THEN (CASE 
																WHEN m.GlobalShowTime <= GETDATE() THEN 1 --LIVE
																WHEN m.EventDate = @Today AND m.GlobalShowTime > GETDATE() THEN 2 --TODAY
																WHEN m.EventDate > @Today THEN 3 -- EARLY
															END)
					ELSE 4 -- CLOSED
				END
			,	1 AS IsGetDataFromOrigin
			,	0 AS DataSource
		FROM #tmpMatches AS tm
			INNER JOIN bodb02.dbo.Match AS m WITH(NOLOCK) ON tm.MatchId = m.matchid

		DROP TABLE #tmpMatches
	END ;
	
	CREATE INDEX IX_tmpMatchesInfo_MatchId ON #tmpMatchesInfo(MatchId);

	WITH CTE_MatchesInfo
		AS
			(
			SELECT	*
					, ROW_NUMBER() OVER (PARTITION BY MatchId ORDER BY DataSource ASC) AS rn
			FROM	#tmpMatchesInfo
			)
	DELETE	FROM CTE_MatchesInfo
	WHERE	rn > 1 ;
		
	SELECT	tmi.MatchId
		,	tmi.EventDate
		,	tmi.KickOffTime
		,	tmi.MatchSection
		,	tmi.IsGetDataFromOrigin
		,	h.teamname AS HomeName
		,	a.teamname AS AwayName
		,	l.leaguename AS LeagueName
		,	tmi.DataSource
	FROM #tmpMatchesInfo AS tmi
		INNER JOIN #tmpMatchSection AS tms ON tmi.MatchSection = tms.MatchSection
		INNER JOIN bodb02.dbo.Team AS h WITH(NOLOCK) ON h.teamid = tmi.homeid
		INNER JOIN bodb02.dbo.Team AS a WITH(NOLOCK) ON a.teamid = tmi.AwayId
		INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON l.leagueid = tmi.leagueid
	WHERE	h.TeamName LIKE '%'+@Event+'%'
		OR	a.TeamName LIKE '%'+@Event+'%'
		OR	l.LeagueName LIKE '%'+@Event+'%'
	
	DROP TABLE #tmpMatchesInfo
	DROP TABLE #tmpMatchSection
END

GO
