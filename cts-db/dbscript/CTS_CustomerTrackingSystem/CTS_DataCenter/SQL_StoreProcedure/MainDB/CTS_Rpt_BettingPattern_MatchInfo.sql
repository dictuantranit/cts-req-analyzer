/*<info serverAlias="DBCTS-bodb02" executers="bodbSPUNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CTS_Rpt_BettingPattern_MatchInfo]
		@MatchIds			VARCHAR(MAX) = ''
	,	@CustIds			VARCHAR(MAX) = ''
AS
/*
	Created: 20210304@John.Ngo
	Task : Match List Betting Pattern
	DB	 : bodb02

	Revisions:
		- 20210304@John.Ngo: Display betting pattern details [Redmine ID: #151156]
		- 20220425@Long.Luu: Add filtered by list of CustIDs [Redmine ID: #171222]

	Params Explaination:
		EXECUTE [dbo].[CTS_Rpt_BettingPattern_MatchInfo] @MatchIds = '40391219,40391223,1207560', @CustIds = '123,456';
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @CustListCounter	TINYINT;

	IF	OBJECT_ID('tempdb..#tmpMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatches;
	END;

	CREATE TABLE #tmpMatches(
			MatchId				INT NOT NULL PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpMatchesInfo') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchesInfo;
	END;

	CREATE TABLE #tmpMatchesInfo (
			MatchId				INT NOT NULL PRIMARY KEY
		,	EventDate			DATETIME
		,	HomeId				INT
		,	AwayId				INT
		,	LeagueId			INT
		,	DataSource			TINYINT /* 0: match, 1: match14, 2: match_bk */
	);

	CREATE NONCLUSTERED INDEX #IX_tmpMatchesInfo_DataSource ON #tmpMatchesInfo (
			DataSource			DESC
	);

	IF	OBJECT_ID('tempdb..#tmpFilteredMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpFilteredMatches;
	END;

	CREATE TABLE #tmpFilteredMatches (
			MatchId				INT NOT NULL PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpCustIds') IS NOT NULL
	BEGIN
		DROP TABLE #tmpCustIds;
	END;

	CREATE TABLE #tmpCustIds(
			CustId				INT NOT NULL PRIMARY KEY
	);

	INSERT INTO #tmpCustIds (CustId)
	SELECT ssk.value FROM STRING_SPLIT(@CustIds, ',') ssk;

	INSERT INTO #tmpMatches (MatchId)
	SELECT ssk.value FROM STRING_SPLIT (@MatchIds, ',') ssk;

	INSERT INTO #tmpMatchesInfo (MatchId, EventDate, HomeId, AwayId, LeagueId, DataSource)
	SELECT	tm.MatchId
		,	m.eventdate
		,	m.homeid
		,	m.awayid
		,	m.leagueid
		,	0
	FROM #tmpMatches AS tm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Match AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;

	DELETE tm
	FROM #tmpMatches AS tm
	INNER JOIN #tmpMatchesInfo AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;

	INSERT INTO #tmpMatchesInfo (MatchId, EventDate, HomeId, AwayId, LeagueId, DataSource)
	SELECT	tm.MatchId
		,	m.eventdate
		,	m.homeid
		,	m.awayid
		,	m.leagueid
		,	1
	FROM #tmpMatches AS tm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Match14 AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;
		
	DELETE tm
	FROM #tmpMatches AS tm
		INNER JOIN #tmpMatchesInfo AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;

	INSERT INTO #tmpMatchesInfo (MatchId, EventDate, HomeId, AwayId, LeagueId, DataSource)
	SELECT	tm.MatchId
		,	m.eventdate
		,	m.homeid
		,	m.awayid
		,	m.leagueid
		,	2
	FROM #tmpMatches AS tm WITH(NOLOCK)
		INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;
	
	SELECT @CustListCounter = COUNT(DISTINCT CustId) FROM #tmpCustIds;

	INSERT INTO #tmpFilteredMatches(MatchId)
	SELECT t.MatchId
	FROM #tmpMatchesInfo AS t
		INNER JOIN bodb02.dbo.bettrans AS b WITH(NOLOCK) ON t.MatchId = b.matchid
		INNER JOIN #tmpCustIds AS tc WITH(NOLOCK) ON b.custid = tc.CustId
	WHERE t.DataSource = 0
	GROUP BY t.MatchID
	HAVING COUNT(DISTINCT b.custid) = @CustListCounter;

	INSERT INTO #tmpFilteredMatches(MatchId)
	SELECT t.MatchId
	FROM #tmpMatchesInfo AS t
		INNER JOIN bodb02.dbo.bettrans14 AS b WITH(NOLOCK) ON t.MatchId = b.matchid AND t.Eventdate= b.winlostdate
		INNER JOIN #tmpCustIds AS tc WITH(NOLOCK) ON b.custid = tc.CustId
	WHERE t.DataSource = 1
	GROUP BY t.MatchID
	HAVING COUNT(DISTINCT b.custid) = @CustListCounter;

	INSERT INTO #tmpFilteredMatches(MatchId)
	SELECT t.MatchId
	FROM #tmpMatchesInfo AS t
		INNER JOIN bodb_Archive.dbo.bettrans_bk AS b WITH(NOLOCK) ON t.MatchId = b.matchid AND t.Eventdate= b.winlostdate
		INNER JOIN #tmpCustIds AS tc WITH(NOLOCK) ON b.custid = tc.CustId
	WHERE t.DataSource = 2
	GROUP BY t.MatchID
	HAVING COUNT(DISTINCT b.custid) = @CustListCounter;

	-- Return data
	SELECT	m.MatchId
		,	m.EventDate
		,	m.HomeId
		,	m.AwayId
		,	m.LeagueId
		,	h.teamname	 AS HomeName
		,	a.teamname	 AS AwayName
		,	l.leaguename AS LeagueName
	FROM #tmpFilteredMatches AS t WITH(NOLOCK)
		INNER JOIN #tmpMatchesInfo AS m WITH(NOLOCK) ON t.MatchId = m.MatchId
		INNER JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
        INNER JOIN bodb02.dbo.team AS h WITH (NOLOCK) ON h.teamid = m.homeid
        INNER JOIN bodb02.dbo.team AS a WITH (NOLOCK) ON a.teamid = m.awayid
	ORDER BY m.EventDate DESC;

	DROP TABLE #tmpCustIds;
	DROP TABLE #tmpMatches;
	DROP TABLE #tmpMatchesInfo
	DROP TABLE #tmpFilteredMatches;

END;

GO
/*<info serverAlias="DBCTS-bodb02" executers="bodbSPUNet" isFunction="0" isNested="0"></info>*/