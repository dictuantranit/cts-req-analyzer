/*<info serverAlias="DBCTS-bodb02" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_Association_GetBySharedMatches]
	@ListCustId			VARCHAR(MAX) = '',
	@RootCustId			BIGINT = 0,
	@QueryType			TINYINT = 0
AS
/*
	Created: 20220726@Long.Luu
	Task : CTS - Association Detection by Shared At Least 3 Matches Within last 7 days
	DB	 : bodb02

	Revisions:
		- 20220726@Long.Luu: 		Created [Redmine ID: #175701]
		- 20220929@Long.Luu: 		Adjust the asssociation rule [Redmine ID: #178331]
		- 20221101@Long.Luu: 		Update the threshold [Redmine ID: #178333]
		- 20230512@Victoria.Le:		Change condition with ticket stake for each cust [Redmine ID: #187978]
		- 20230602@Long.Luu:		Add new agent as internal account [Redmine ID: #188554]
        - 20231024@Long.Luu: 		Add Agent HITRM & WINRM as internal account [Redmine ID: #195355]
        - 20231207@Long.Luu: 		Add Agent M999RM00 as internal account [Redmine ID: #197915]
		- 20240920@Thomas.Nguyen: 	Enhance Performance [Redmine ID: #210628]
        - 20250923@Long.Luu: 		Add Agents ORI6RM & ORI20RM  as internal account [Redmine ID: #239117]

	Params Explaination:
		- @QueryType: 1 detect associations, 2 get fraud tickets, 3 get association custlist of a group, 4 get fraud tickets of a custgroup

	Example:
		EXECUTE [dbo].[CTS_Association_GetBySharedMatches] @ListCustId = '2,3',@RootCustId=2,@QueryType=1;
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @CONST_MAXTIMEINTERVAL					SMALLINT = 180; -- 180 Seconds = 3 minutes
	DECLARE @CONST_MATCHSHARED						SMALLINT = 3;
	DECLARE @CONST_STAKETHRESHOLD_SOCCER			SMALLINT = 500;
	DECLARE @CONST_STAKETHRESHOLD_BASKETBALL		SMALLINT = 300;
	DECLARE @CONST_STAKETHRESHOLD_OTHER				SMALLINT = 150;

	DECLARE @DataFromDate							SMALLDATETIME
		,	@Today									DATE = GETDATE()
		,	@CutOffDate								DATE = '2021-09-22'
		,	@BalanceUpDay							SMALLDATETIME
		,	@MoveBetsDay							SMALLDATETIME;
	
	DROP TABLE IF EXISTS #tmpCustIdsOrg;
	CREATE TABLE #tmpCustIdsOrg(
			CustId				INT NOT NULL PRIMARY KEY
	);

	DROP TABLE IF EXISTS #tmpCustIds;
	CREATE TABLE #tmpCustIds(
			CustId				INT NOT NULL PRIMARY KEY
	);

	DROP TABLE IF EXISTS #BUMBData;
	CREATE TABLE	#BUMBData (
			BUDay	SMALLDATETIME
		,	MBDay	SMALLDATETIME
	);

	INSERT INTO #BUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;

	SELECT	TOP(1)
			@BalanceUpDay	= BUDay
		,	@MoveBetsDay	= MBDay
	FROM #BUMBData WITH(NOLOCK);

	IF @ListCustId <> ''
		BEGIN
			INSERT INTO #tmpCustIdsOrg (CustId)
			SELECT ssk.Value
			FROM STRING_SPLIT(@ListCustId, ',') AS ssk
			OPTION (MAXRECURSION 0);
		END;

	INSERT INTO #tmpCustIds (CustId)
	SELECT tmp.CustId
	FROM #tmpCustIdsOrg AS tmp
		INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) on c.custid = tmp.custid
	WHERE c.srecommend NOT IN (41430709) 
		AND c.mrecommend NOT IN (27899314,11656504,12146012) 
		AND c.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)		
		AND c.username NOT LIKE '%CashOut' 
		AND c.site NOT IN ('Nextbet','9wickets','9wsports')
		AND c.Currency NOT IN (20,27,28);

	SET @DataFromDate = DATEADD(DAY, -7, @Today);

	DROP TABLE IF EXISTS #tmpRawTickets;
	CREATE TABLE	#tmpRawTickets(
			TransID				BIGINT
		,	TransDate_Int		BIGINT
		,	CustID				INT
		,	MatchID				INT
		,	EventDate			DATE
		,	LeagueId			INT
		,	HomeId				INT
		,	AwayId				INT
		,	BetType				SMALLINT
		,	BetTeam				NVARCHAR(10)
		,	LiveHomeScore		SMALLINT
		,	LiveAwayScore		SMALLINT
		,	TransDate			DATETIME
		,	UserName			VARCHAR(30)
		,	Odds				SMALLMONEY
		,	Stake				MONEY
		,	Status				NVARCHAR(10)
		,	INDEX IX_tmpRawTickets_TransID (TransID)
	);	

	DROP TABLE IF EXISTS #tmpAssociation;
	CREATE TABLE	#tmpAssociation(
			CustID1				INT
		,	CustID2				INT		
		,	MatchID				INT
		,	EventDate			DATE
		,	LeagueId			INT
		,	HomeId				INT
		,	AwayId				INT
		,	TransID1			BIGINT
		,	TransID2			BIGINT
		,	LiveHomeScore		SMALLINT
		,	LiveAwayScore		SMALLINT
	);

	DROP TABLE IF EXISTS #tmpRootCustIDMatches;
	CREATE TABLE	#tmpRootCustIDMatches(
			MatchID				INT PRIMARY KEY
	);	
	
	DROP TABLE IF EXISTS #tmpStakeThredsHold;
	CREATE TABLE	#tmpStakeThredsHold(
			SportType			SMALLINT NOT NULL PRIMARY KEY
		,	StakeRM				SMALLINT				
	);	
	
	INSERT INTO #tmpStakeThredsHold (SportType, StakeRM)
	SELECT 	SportType
		, 	CASE WHEN SportType = 1 THEN @CONST_STAKETHRESHOLD_SOCCER
				 WHEN SportType = 2 THEN @CONST_STAKETHRESHOLD_BASKETBALL
				 ELSE @CONST_STAKETHRESHOLD_OTHER						
			END
	FROM dbo.sports WITH (NOLOCK)
	WHERE SportType < 100;
	
	-- Get full data from bettrans
	INSERT INTO #tmpRawTickets(
			TransID
		,	TransDate_Int
		,	MatchID
		,	BetType
		,	CustID
		,	BetTeam
		,	EventDate
		,	LeagueId
		,	HomeId
		,	AwayId
		,	LiveHomeScore
		,	LiveAwayScore
		,	TransDate
		,	UserName
		,	Odds
		,	Stake
		,	Status
	)
	SELECT	b.transid
		,	DATEDIFF(ss, @CutOffDate, b.transdate)
		,	b.matchid
		,	b.bettype
		,	b.custid
		,	b.betteam
		,	m.kickofftime
		,	m.leagueid
		,	m.homeid
		,	m.awayid
		,	b.livehomescore
		,	b.liveawayscore
		,	b.transdate
		,	b.UserName
		,	b.Odds
		,	b.Stake
		,	b.Status
	FROM #tmpCustIds AS a WITH(NOLOCK)
		INNER JOIN dbo.bettrans AS b WITH(NOLOCK) ON a.CustID = b.custid		
		INNER JOIN dbo.match AS m WITH(NOLOCK) ON b.MatchID = m.matchid 
		INNER JOIN #tmpStakeThredsHold AS s WITH(NOLOCK) ON s.SportType = m.sporttype
		INNER JOIN dbo.league AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE b.winlostdate > @MoveBetsDay
		AND m.eventstatus = 'Completed'
		AND l.LeagueGroupID NOT IN (42,72,74,108,113,122) -- exclude SABA, Virtual Sport
		AND (b.stake * b.actualrate >= s.StakeRM);

	-- Get more data from bettrans 14
	INSERT INTO #tmpRawTickets(
			TransID
		,	TransDate_Int
		,	MatchID
		,	BetType
		,	CustID
		,	BetTeam
		,	EventDate
		,	LeagueId
		,	HomeId
		,	AwayId
		,	LiveHomeScore
		,	LiveAwayScore
		,	TransDate
		,	UserName
		,	Odds
		,	Stake
		,	Status
	)
	SELECT	b.transid
		,	DATEDIFF(ss, @CutOffDate, b.transdate)
		,	b.matchid
		,	b.bettype
		,	b.custid
		,	b.betteam
		,	m.kickofftime
		,	m.leagueid
		,	m.homeid
		,	m.awayid
		,	b.livehomescore
		,	b.liveawayscore
		,	b.transdate
		,	b.UserName
		,	b.Odds
		,	b.Stake
		,	b.Status
	FROM #tmpCustIds AS a WITH(NOLOCK)
		INNER JOIN dbo.bettrans14 AS b WITH(NOLOCK, INDEX=IX_memberStatement14) ON a.CustID = b.custid		
		INNER JOIN dbo.match14 AS m WITH(NOLOCK) ON b.MatchID = m.matchid
		INNER JOIN #tmpStakeThredsHold AS s WITH(NOLOCK) ON s.SportType = m.sporttype
		INNER JOIN dbo.league AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE	b.winlostdate <= @MoveBetsDay AND b.winlostdate > @DataFromDate
		AND m.eventstatus = 'Completed'
		AND l.LeagueGroupID NOT IN (42,72,74,108,113,122) -- exclude SABA, Virtual Sport		
		AND (b.stake * b.actualrate >= s.StakeRM)

	CREATE CLUSTERED INDEX CIX_tmpRawTickets
	ON #tmpRawTickets (MatchID, Bettype, Betteam, LiveHomeScore, LiveAwayScore, CustID); 

	;WITH cte_custPerMatch AS (
		SELECT DISTINCT c1.CustID AS CustID1, c1.MatchID, c1.Bettype, c1.BetTeam, c2.CustID AS CustID2
			,	c1.EventDate, c1.LeagueId, c1.HomeId, c1.AwayId, c1.LiveHomeScore, c1.LiveAwayScore
		FROM #tmpRawTickets AS c1
			INNER JOIN #tmpRawTickets AS c2 
				ON c1.MatchID = c2.MatchID AND c1.BetType = c2.BetType
					AND c1.BetTeam = c2.BetTeam AND c1.LiveHomeScore = c2.LiveHomeScore
					AND c1.LiveAwayScore = c2.LiveAwayScore AND  c1.CustID <> c2.CustID
	), 
	cte_SeekPerMatch AS (
		SELECT ck.CustID1, ck.CustID2
		FROM cte_custPerMatch AS ck
		GROUP BY ck.CustID1, ck.CustID2
		HAVING COUNT(DISTINCT ck.MatchID) >= @CONST_MATCHSHARED
	)
	INSERT INTO #tmpAssociation(CustID1,CustID2,TransID1,TransID2, MatchID, EventDate, LeagueId, HomeId, AwayId)
	SELECT DISTINCT CASE 
						WHEN c.CustID1 > c.CustID2 THEN c.CustID2
						ELSE c.CustID1
					END AS CustID1
				,	CASE 
						WHEN c.CustID1 > c.CustID2 THEN c.CustID1
						ELSE c.CustID2
					END AS CustID2
				,	CASE 
						WHEN t.TransID1 > t.TransID2 THEN t.TransID2
						ELSE t.TransID1
					END AS TransID1
				,	CASE 
						WHEN t.TransID1 > t.TransID2 THEN t.TransID1
						ELSE t.TransID2
					END AS TransID2
				,	m.MatchID
				,	m.EventDate
				,	m.LeagueId
				,	m.HomeId
				,	m.AwayId
	FROM cte_SeekPerMatch AS c
		INNER JOIN cte_custPerMatch AS m ON m.CustID1 = c.CustID1 AND m.CustID2 = c.CustID2
		CROSS APPLY (
			SELECT c1.TransID AS TransID1, c2.TransID AS TransID2
			FROM (
				SELECT t1.TransID, t1.TransDate_Int
				FROM #tmpRawTickets AS t1
				WHERE t1.MatchID = m.MatchID AND t1.BetType = m.BetType 
					AND t1.BetTeam = m.BetTeam AND t1.LiveHomeScore = m.LiveHomeScore
					AND t1.LiveAwayScore = m.LiveAwayScore AND t1.CustID IN (c.CustID1)
			) AS c1
			INNER JOIN (
				SELECT t2.TransID, t2.TransDate_Int
				FROM #tmpRawTickets AS t2
				WHERE t2.MatchID = m.MatchID AND t2.BetType = m.BetType 
					AND t2.BetTeam = m.BetTeam AND t2.LiveHomeScore = m.LiveHomeScore
					AND t2.LiveAwayScore = m.LiveAwayScore  AND t2.CustID IN (c.CustID2)
			) AS c2
				ON ABS(c1.TransDate_Int - c2.TransDate_Int) <= @CONST_MAXTIMEINTERVAL
		) AS t
	;	

	CREATE CLUSTERED INDEX CIX_tmpAssociation
	ON #tmpAssociation (MatchID, EventDate, TransID1, TransID2);

	CREATE NONCLUSTERED INDEX IX_tmpAssociation_CustID1CustID2
	ON #tmpAssociation (CustID1, CustID2);

	CREATE NONCLUSTERED INDEX CIX_tmpAssociation_CustID2
	ON #tmpAssociation (CustID2);

	;WITH cte_lessThan3Matches AS (
		SELECT CustID1, CustID2
		FROM #tmpAssociation
		GROUP BY CustID1, CustID2
		HAVING COUNT(DISTINCT MatchID) < @CONST_MATCHSHARED
	)
	DELETE a WITH(ROWLOCK)
	FROM cte_lessThan3Matches AS t
		INNER JOIN #tmpAssociation AS a ON t.CustID1 = a.CustID1 AND t.CustID2 = a.CustID2;

	IF (@QueryType = 1) 
		BEGIN			
			SELECT DISTINCT CustID1, CustID2
			FROM #tmpAssociation;
		END;
	ELSE IF (@QueryType = 2)
		BEGIN
			SELECT b.TransId, b.TransDate, b.UserName, b.BetType, b.BetTeam, b.Stake, b.Odds, b.LiveHomeScore, b.LiveAwayScore, b.status AS TicketStatus, b.MatchId, c.EventDate, c.HomeId, c.AwayId, c.LeagueId
			FROM #tmpAssociation AS c
				INNER JOIN #tmpRawTickets AS b WITH(NOLOCK) ON b.TransId = c.TransID1 OR b.TransId = c.TransID2
		END
	ELSE IF (@QueryType = 3)
		BEGIN
			SELECT DISTINCT CustID2 AS CustID
			FROM #tmpAssociation
			WHERE CustID1 = @RootCustId
			UNION ALL
			SELECT DISTINCT CustID1 AS CustID
			FROM #tmpAssociation
			WHERE CustID2 = @RootCustId;
		END
	ELSE 
		BEGIN	
			INSERT INTO #tmpRootCustIDMatches(MatchID)	
			SELECT DISTINCT MatchID
			FROM #tmpAssociation				
			WHERE CustID1 = @RootCustId OR CustID2 = @RootCustId;

			SELECT b.TransId, b.TransDate, b.UserName, b.BetType, b.BetTeam, b.Stake, b.Odds, b.LiveHomeScore, b.LiveAwayScore, b.status AS TicketStatus, b.MatchId, c.EventDate, c.HomeId, c.AwayId, c.LeagueId
			FROM #tmpRootCustIDMatches AS cte
				INNER JOIN #tmpAssociation AS c ON cte.MatchID = c.MatchID
				INNER JOIN #tmpRawTickets AS b WITH(NOLOCK) ON b.TransId = c.TransID1 OR b.TransId = c.TransID2
		END;
	
	DROP TABLE #BUMBData;
	DROP TABLE #tmpCustIdsOrg;
	DROP TABLE #tmpCustIds;
	DROP TABLE #tmpRawTickets;
	DROP TABLE #tmpAssociation;
	DROP TABLE #tmpRootCustIDMatches;
	DROP TABLE #tmpStakeThredsHold;
	
END;


