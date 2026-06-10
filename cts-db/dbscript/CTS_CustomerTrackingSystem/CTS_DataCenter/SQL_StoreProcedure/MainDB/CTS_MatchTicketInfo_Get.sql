/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CTS_MatchTicketInfo_Get]
		@FromDate				DATETIME = NULL
	,	@ToDate					DATETIME = NULL
	,	@SportList				VARCHAR(MAX) = ''
	,	@LeagueEvent			VARCHAR(500) = ''
	,	@MarketList				VARCHAR(10)  = ''
	,	@BettypeList			VARCHAR(MAX) = '[]' --JSON
	,	@MatchSection			VARCHAR(10) = '' 	-- STRING
	,	@DangerLevels			VARCHAR(10)
	,	@SportSabaLeagueGroup	VARCHAR(200) = ''
	,	@UserNameList			VARCHAR(MAX)=''
	,	@LeagueGroupList		VARCHAR(MAX)=''
	,	@UserAmount				MONEY = 0
	,	@TotalAmount			MONEY = 0
	,	@IsExclTestCurr			BIT = 1
AS

/*
	Created: 20240102@Casey.Huynh
	Task : Get Match Ticket Info
	DB	 : bodb02

	Revisions:
		- 20240102@Casey.Huynh: Created [Redmine ID: #196361]
		- 20240322@Vitoria.Le: 	Change inputs to optimize query data [Redmine ID: #201380]
		- 20240521@Thomas.Nguyen: Remove hardcode 2 Agent WINRM and M999RM00 as internal accounts for Danger Monitor [Redmine ID: #205239]
		- 20240702@Casey.Huynh:	Add Filter by Username and LeagueGroup  [Redmine ID: #206494]	
		- 20240802@Casey.Huynh:	Add Filter by User Amount and Total Amount  [Redmine ID: #207528]	
		- 20241227@Casey.Huynh:	Tunning Phase 1, USE(Max Dop,Force Index) [Redmine ID: #214663]	
		- 20250103@Casey.Huynh:	Tunning Phase 2, REMOVE(Max Dop,Force Index) enhance logic get data, switch sp to WASAVerse [Redmine ID: #214663]	
		- 20250320@Jonas.Huynh:	Danger Monitor - Handle BetID for Cricket [Redmine ID: #217765]
		- 20250506@Casey.Huynh:	Danger Monitor - Fix LeagueGroup Filter [Redmine ID: #226078]
        - 20250807@Winfred.Pham: Get Data for Sum betType [Redmine ID: #202508 ]
        - 20250923@Long.Luu: 	Add Agents ORI6RM & ORI20RM  as internal account [Redmine ID: #239117]
		- 20251031@Logan.Nguyen: 	Add WITH(NOLOCK) [Redmine ID: #239956]

	Params Explaination:
		,@BettypeList='[	{"BetType":1, "BetChoiceType":2}
						,	{"BetType":2, "BetChoiceType":2}
						,	{"BetType":126, "BetChoiceType":1}]'
		
	exec CTS_MatchTicketInfo_Get 
				@FromDate='2024-07-30 00:00:00'
			,	@ToDate='2024-08-06 00:00:00'
			,	@SportList='1'
			,	@LeagueEvent=''
			,	@BettypeList='[{"BetType":1,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0}
						,{"BetType":3,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0}
						,{"BetType":7,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0}
						,{"BetType":8,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0}
						,{"BetType":2,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0}
						,{"BetType":12,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetID":0}
						,{"BetType":413,"BetChoiceType":1,"BetID":0}
						,{"BetType":414,"BetChoiceType":1,"BetID":0}
						,{"BetType":6,"BetChoiceType":1,"BetID":0}
						,{"BetType":126,"BetChoiceType":1,"BetID":0}]'
			,	@DangerLevels='2_11'
			,	@UserNameList=''
			,	@LeagueGroupList='1,2,3,4,5,6,7,8,9,10,11,12,13,14,41,72,73,77,78,79,80,81,82,99,100,101,102,103,104,105,106,107,0'
			,	@MarketList='0,1'
			,	@SportSabaLeagueGroup=''
			,	@MatchSection='1,2,3,4'
			,	@UserAmount=0.0000
			,	@TotalAmount=0.0000
	
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

		,	@DangerType				TINYINT
		,	@Danger					TINYINT
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

	CREATE TABLE #tmpBetType (
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

	CREATE TABLE	#tmpCustomer(
			CustId				INT 	
	);

	IF	OBJECT_ID('tempdb..#tmpUsername') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpUsername;
	END;

	CREATE TABLE	#tmpUsername(
			UserName	VARCHAR(50) 	
	);
	
	IF	OBJECT_ID('tempdb..#tmpLeagueGroup') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpLeagueGroup;
	END;

	CREATE TABLE	#tmpLeagueGroup(
			LeagueGroupID	INT 	
	);

	IF	OBJECT_ID('tempdb..#tmpMatchSum') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchSum;
	END;

	CREATE TABLE #tmpMatchSum (
			MatchId				INT NOT NULL
		,	LiveIndicator		BIT NOT NULL
		,	Bettype				INT NOT NULL
		,	BetId				BIGINT 
		,	BetChoiceType		TINYINT
		,	TotalAmountHome		MONEY
		,	TotalAmountAway		MONEY
		,	TotalTicketHome		MONEY
		,	TotalTicketAway		MONEY
		,	IsFrom14			BIT DEFAULT 0
	);
	
	DROP TABLE IF EXISTS #tmpMatchInfo
	CREATE TABLE #tmpMatchInfo(
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
	CREATE TABLE #tmpMatchInfo14(
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
	CREATE TABLE #tmpCustTrans(
			CustId			INT
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

	IF @UserNameList <> '' AND @UserNameList IS NOT NULL
	BEGIN
		INSERT INTO #tmpUsername(UserName)
		SELECT DISTINCT ssk.value FROM STRING_SPLIT (@UserNameList, ',') AS ssk;
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
	
	WITH CTE_Danger AS (
		SELECT 	CAST(LEFT(ssk.value, CHARINDEX('_', ssk.value)-1) AS TINYINT) AS DangerType
			,	CAST(SUBSTRING(ssk.value, CHARINDEX('_', ssk.value)+1, 6) AS TINYINT) AS Danger
		FROM STRING_SPLIT (@DangerLevels, ',') AS ssk
		WHERE LEN(ssk.value) > 0
	)
	SELECT @DangerType = DangerType, @Danger = Danger
	FROM CTE_Danger;
	
	IF (@SportSabaLeagueGroup <> '')
	BEGIN
		SET @IsExcludeSabaGroup = 0;
	
		INSERT INTO @tmpSportSabaLeagueGroup (SportType, LeagueGroupID)
		SELECT 	CAST(LEFT(ssk.value, CHARINDEX('_', ssk.value)-1) AS TINYINT) AS SportType
			,	CAST(SUBSTRING(ssk.value, CHARINDEX('_', ssk.value)+1, 6) AS TINYINT) AS LeagueGroupID
		FROM STRING_SPLIT (@SportSabaLeagueGroup, ',') AS ssk
		WHERE LEN(ssk.value) > 0;
	END;

	IF @UsernameList <> '' AND @UserNameList IS NOT NULL
	BEGIN
		INSERT INTO #tmpCustomer(CustId)
		SELECT cs.custid
		FROM bodb02.dbo.Customer AS cs WITH (NOLOCK) 
			INNER JOIN #tmpUsername AS un WITH(NOLOCK) ON un.username = cs.username;
	END
	ELSE
	BEGIN
		IF @DangerType = 1 
		BEGIN
			INSERT INTO #tmpCustomer(CustId)
			SELECT cust.custid
			FROM bodb02.dbo.v_danger_custInfo AS cust WITH(NOLOCK)
				INNER JOIN bodb02.dbo.Customer AS cs WITH (NOLOCK) ON cs.custid = cust.custid 
			WHERE cs.site NOT IN ('Nextbet','9wickets','9wsports')
				AND cs.username NOT LIKE '%Cashout%'
				AND cs.mrecommend NOT IN (27899314,11656504,12146012) 
				AND cs.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
				AND (CASE WHEN @IsExclTestCurr = 0 THEN 1 
						  WHEN @IsExclTestCurr = 1 AND cs.currency NOT IN (20,27,28) THEN 1 
						  ELSE 0 END = 1)
				AND cs.srecommend NOT IN (41430709) 
				AND cust.RoleId = 1
				AND cust.danger > 0 AND cust.danger = @Danger;
		END;
		IF @DangerType = 2
		BEGIN
			INSERT INTO #tmpCustomer(CustId)
			SELECT cust.custid
			FROM bodb02.dbo.v_danger_custInfo AS cust WITH(NOLOCK)
				INNER JOIN bodb02.dbo.Customer AS cs WITH (NOLOCK) ON cs.custid = cust.custid
			WHERE cs.site NOT IN ('Nextbet','9wickets','9wsports')
				AND cs.username NOT LIKE '%Cashout%'
				AND cs.mrecommend NOT IN (27899314,11656504,12146012) 
				AND cs.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
				AND (CASE WHEN @IsExclTestCurr = 0 THEN 1 
						  WHEN @IsExclTestCurr = 1 AND cs.currency NOT IN (20,27,28) THEN 1 
						  ELSE 0 END = 1)
				AND cs.srecommend NOT IN (41430709) 
				AND cust.RoleId = 1
				AND cust.danger2 > 0 AND cust.danger2 = @Danger;
		END;
		IF @DangerType = 3
		BEGIN
			INSERT INTO #tmpCustomer(CustId)
			SELECT cust.custid
			FROM bodb02.dbo.v_danger_custInfo AS cust WITH(NOLOCK)
				INNER JOIN bodb02.dbo.Customer AS cs WITH (NOLOCK) ON cs.custid = cust.custid 
			WHERE cs.site NOT IN ('Nextbet','9wickets','9wsports')
				AND cs.username NOT LIKE '%Cashout%'
				AND cs.mrecommend NOT IN (27899314,11656504,12146012) 
				AND cs.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
				AND (CASE WHEN @IsExclTestCurr = 0 THEN 1 
						  WHEN @IsExclTestCurr = 1 AND cs.currency NOT IN (20,27,28) THEN 1 
						  ELSE 0 END = 1)
				AND cs.srecommend NOT IN (41430709) 
				AND cust.RoleId = 1
				AND cust.danger3 > 0 AND cust.danger3 = @Danger;
		END;
		IF @DangerType = 4
		BEGIN
			INSERT INTO #tmpCustomer(CustId)
			SELECT cust.custid
			FROM bodb02.dbo.v_danger_custInfo AS cust WITH(NOLOCK)
				INNER JOIN bodb02.dbo.Customer AS cs WITH (NOLOCK) ON cs.custid = cust.custid 
			WHERE cs.site NOT IN ('Nextbet','9wickets','9wsports')
				AND cs.username NOT LIKE '%Cashout%'
				AND cs.mrecommend NOT IN (27899314,11656504,12146012) 
				AND cs.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
				AND (CASE WHEN @IsExclTestCurr = 0 THEN 1 
						  WHEN @IsExclTestCurr = 1 AND cs.currency NOT IN (20,27,28) THEN 1 
						  ELSE 0 END = 1)
				AND cs.srecommend NOT IN (41430709) 
				AND cust.RoleId = 1
				AND cust.danger4 > 0 AND cust.danger4 = @Danger;
		END;
		IF @DangerType = 5
		BEGIN
			INSERT INTO #tmpCustomer(CustId)
			SELECT cust.custid
			FROM bodb02.dbo.v_danger_custInfo AS cust WITH(NOLOCK)
				INNER JOIN bodb02.dbo.Customer AS cs WITH (NOLOCK) ON cs.custid = cust.custid 
			WHERE cs.site NOT IN ('Nextbet','9wickets','9wsports')
				AND cs.username NOT LIKE '%Cashout%'
				AND cs.mrecommend NOT IN (27899314,11656504,12146012) 
				AND cs.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
				AND (CASE WHEN @IsExclTestCurr = 0 THEN 1 
						  WHEN @IsExclTestCurr = 1 AND cs.currency NOT IN (20,27,28) THEN 1 
						  ELSE 0 END = 1)
				AND cs.srecommend NOT IN (41430709) 
				AND cust.RoleId = 1
				AND cust.danger5 > 0 AND cust.danger5 = @Danger;
		END;
	END;

	CREATE CLUSTERED INDEX CIX_tmpDangerCust ON #tmpCustomer(CustId);

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
					FROM bodb02.dbo.Match AS m WITH(NOLOCK)
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
						,	h.TeamName AS HomeName
						,	m.AwayId
						,	a.TeamName AS AwayName
						,	m.EventDate
						,	m.GlobalShowTime
						,	m.EventStatus
						,	tmp.SportType
						,	l.LeagueId
						,	l.LeagueName
					FROM bodb02.dbo.Match AS m WITH(NOLOCK)
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
							,	c.CustId
							,	t.BetChoiceType
							,	t.BetChoiceHome
							,	t.BetChoiceAway
						FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
							INNER JOIN #tmpCustomer AS c WITH(NOLOCK) ON b.custid = c.custid
							INNER JOIN #tmpMatchInfo AS m WITH(NOLOCK) ON m.MatchId = b.matchid
							CROSS APPLY (
								SELECT bt.BetID, bt.BetChoiceType,bt.BetChoiceHome,bt.BetChoiceAway
								FROM #tmpBetType AS bt WITH(NOLOCK)
								WHERE b.Bettype = bt.Bettype 
							) AS t
						WHERE b.BetID = CASE WHEN m.SportType = @SPORTTYPE_CRICKET OR t.BetID = 0 THEN b.BetID ELSE t.BetId END)
			INSERT INTO #tmpMatchSum(MatchId, LiveIndicator,BetChoiceType, Bettype,BetID, TotalAmountHome, TotalAmountAway, TotalTicketHome, TotalTicketAway)
			SELECT 	tmpCust.MatchId
				,	tmpCust.LiveIndicator
				,	tmpCust.BetChoiceType
				,	tmpCust.Bettype
				,	tmpCust.BetID
				,	SUM(CASE WHEN tmpCust.CustAmountHome >= @UserAmount THEN tmpCust.CustAmountHome ELSE 0 END) AS AmountHome
				,	SUM(CASE WHEN tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustAmountAway ELSE 0 END) AS AmountWay
				,	SUM(CASE WHEN tmpCust.CustAmountHome >= @UserAmount THEN tmpCust.CustTicketHome ELSE 0 END) AS TicketHome
				,	SUM(CASE WHEN tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustTicketAway ELSE 0 END) AS TicketAway
			
			FROM (
					SELECT 	tmp.MatchId
						,	tmp.LiveIndicator
						,	tmp.BetChoiceType
						,	tmp.Bettype
						,	tmp.BetID
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
				WHERE tmpCust.CustAmountHome >= @UserAmount
					OR tmpCust.CustAmountAway >= @UserAmount
				GROUP BY tmpCust.MatchId, tmpCust.BetChoiceType, tmpCust.Bettype, tmpCust.LiveIndicator, tmpCust.BetId
				HAVING SUM(tmpCust.CustAmountHome) >=  @TotalAmount
					OR SUM(tmpCust.CustAmountAway) >=  @TotalAmount
				OPTION (RECOMPILE) ;

			IF (@@ROWCOUNT > 0)
			BEGIN
				SET @IsFromActive14 = 1;
			END;
		END;
	END;

	IF @Fromdate <= @MoveBetsDay
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
										OR tmp.AwayName LIKE '%' + @LeagueEvent + '%')
					;
			END
  
  IF Exists (SELECT 1 FROM #tmpMatchInfo14) 
  BEGIN

		INSERT INTO #tmpCustTrans(MatchId,Liveindicator,Bettype,BetId,Betteam,Stake,Actualrate,CustId)
		SELECT	b.MatchId
			,	b.Liveindicator
			,	b.Bettype
			,	CASE WHEN m.SportType = @SPORTTYPE_CRICKET THEN 0 ELSE b.BetId END AS BetID
			,	b.Betteam
			,	b.Stake
			,	b.Actualrate
			,	c.CustId							
		FROM bodb02.dbo.bettrans14 AS b WITH(NOLOCK)
			INNER JOIN #tmpCustomer AS c WITH(NOLOCK) ON b.custid = c.custid
			INNER JOIN #tmpMatchInfo14 AS m WITH(NOLOCK) ON m.MatchId = b.MatchId

		CREATE CLUSTERED INDEX CIX_tmpDangerCust ON #tmpCustTrans(MatchID);

		INSERT INTO #tmpMatchSum(MatchId, LiveIndicator,BetChoiceType, Bettype,BetID, TotalAmountHome, TotalAmountAway, TotalTicketHome, TotalTicketAway, IsFrom14)
		SELECT 		tmpCust.MatchId
				,	tmpCust.LiveIndicator
				,	tmpCust.BetChoiceType
				,	tmpCust.Bettype
				,	tmpCust.BetID
				,	SUM(CASE WHEN tmpCust.CustAmountHome >= @UserAmount THEN tmpCust.CustAmountHome ELSE 0 END) AS AmountHome
				,	SUM(CASE WHEN tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustAmountAway ELSE 0 END) AS AmountWay
				,	SUM(CASE WHEN tmpCust.CustAmountHome >= @UserAmount THEN tmpCust.CustTicketHome ELSE 0 END) AS TicketHome
				,	SUM(CASE WHEN tmpCust.CustAmountAway >= @UserAmount THEN tmpCust.CustTicketAway ELSE 0 END) AS TicketAway
				,	1 AS IsFrom14
			FROM (
					SELECT 	tmp.MatchId
						,	tmp.LiveIndicator
						,	t.BetChoiceType
						,	tmp.Bettype
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
				WHERE tmpCust.CustAmountHome >= @UserAmount
					OR tmpCust.CustAmountAway >= @UserAmount
				GROUP BY tmpCust.MatchId, tmpCust.BetChoiceType, tmpCust.Bettype, tmpCust.LiveIndicator, tmpCust.BetId
				HAVING SUM(tmpCust.CustAmountHome) >=  @TotalAmount
					OR SUM(tmpCust.CustAmountAway) >=  @TotalAmount
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
	
	CREATE CLUSTERED INDEX CIX_tmpMatchSum ON #tmpMatchSum(Bettype);	

	IF @IsFromActive14 = 1
	BEGIN
		SELECT 	tms.MatchId
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
			FROM #tmpMatchSum AS tms
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
		SELECT 	tms.MatchId
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
			FROM #tmpMatchSum AS tms
				INNER JOIN #tmpMatchInfo14 AS m WITH(NOLOCK) ON m.MatchId = tms.MatchId AND tms.IsFrom14 = 1
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
	ELSE
	BEGIN
		SELECT 	tms.MatchId
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
			FROM #tmpMatchSum AS tms
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
		SELECT 	tms.MatchId
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
			FROM #tmpMatchSum AS tms
				INNER JOIN #tmpMatchInfo14 AS m WITH(NOLOCK) ON m.MatchId = tms.MatchId AND tms.IsFrom14 = 1
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
	END;	

	DROP TABLE IF EXISTS #tmpBetType;
	DROP TABLE IF EXISTS #tmpCustomer;
	DROP TABLE IF EXISTS #tmpMatchSum;
	DROP TABLE IF EXISTS #tmpMatchInfo;
	DROP TABLE IF EXISTS #tmpMatchInfo14;
	DROP TABLE IF EXISTS #tmpCustTrans;

END;
