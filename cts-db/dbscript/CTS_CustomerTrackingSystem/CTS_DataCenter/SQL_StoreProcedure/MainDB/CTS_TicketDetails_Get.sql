/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_TicketDetails_Get]
		@ListTransId		VARCHAR(MAX) = ''
	,	@MatchSize			INT	= NULL
	,	@TransSize			INT = NULL	

AS
/*
	Created: @Victoria.Le
	Task : DBCTS-AssociatedAccount-Get Fraud Tickets
	DB	 : WASAVerse

	Revisions:
		- 20230116@Victoria.Le: Initial Writing [Redmine ID: #181994]
		- 20230328@Victoria.Le: Add New Param, Modify SP to split 5G3S And OTGB [Redmine ID: #181994]
		- 20250428@Thomas.Nguyen: Upgrade CurrencyID datatype, switch SP to WASAVerse [Redmine ID: #225335]

	Params Explaination:
		
		@MatchSize & @TransSize: NULL OR = 0 ==> 5G3S
		@MatchSize & @TransSize: NOT NULL OR > 0 ==> OTGB
		@ListTransId: 
			+ 5G3S: List transid (string split by ',')
			+ OTGB: List transid & matchid (JSON format)

	Example:
		EXECUTE [dbo].[CTS_TicketDetails_Get] @ListTransId = '1,3'
		EXECUTE [dbo].[CTS_TicketDetails_Get]
			@ListTransId = '[{"TransID":100269516218433536,"MatchID":70086357},{"TransID":100269516218433537,"MatchID":70086357},{"TransID":100269516218433538,"MatchID":70086357},{"TransID":100269516218433539,"MatchID":70086357},{"TransID":100269516218433540,"MatchID":70086357},{"TransID":100267759576809472,"MatchID":70086356},{"TransID":100267759576809473,"MatchID":70086356},{"TransID":100266870518579200,"MatchID":70086353},{"TransID":100263498969251840,"MatchID":70086349},{"TransID":100263498969251841,"MatchID":70086349},{"TransID":6106724087889920,"MatchID":70085351},{"TransID":6102421067530240,"MatchID":70085315},{"TransID":93209148329558021,"MatchID":70084546},{"TransID":93209148329558017,"MatchID":70084546},{"TransID":93209186988457985,"MatchID":70084546},{"TransID":93209148329558019,"MatchID":70084546},{"TransID":93209148329558022,"MatchID":70084546},{"TransID":93209148329558018,"MatchID":70084546},{"TransID":93209186988457984,"MatchID":70084546},{"TransID":93209148329558020,"MatchID":70084546}]'
		,	@MatchSize = 3
		,	@TransSize = 4
*/
BEGIN
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmpTickets') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTickets;
	END;

	CREATE TABLE	#tmpTickets(
			TransId				BIGINT PRIMARY KEY
		,	TransDate			DATETIME
		,	MatchId				INT
		,	EventDate			DATETIME
		,	EventStatus			NVARCHAR(50)
		,	KickOffTime			DATETIME
		,	HomeId				INT
		,	AwayId				INT
		,	LeagueId			INT
		,	BetType				SMALLINT
		,	CustId				INT
		,	BetTeam				NVARCHAR(10)
		,	Stake				MONEY
		,	Odds				SMALLMONEY
		,	Hdp1				SMALLMONEY
		,	Hdp2				SMALLMONEY
		,	LiveHomeScore		SMALLINT
		,	LiveAwayScore		SMALLINT
		,	LiveIndicator		BIT
		,	TicketStatus		SMALLINT
		,	Currency			SMALLINT
		,	IP					VARCHAR(45)
		,	ActualRate			FLOAT
	);	
	
	IF ISNULL(@MatchSize,0) = 0 AND ISNULL(@TransSize,0) = 0
	BEGIN

		IF	OBJECT_ID('tempdb..#tmpTransIds') IS NOT NULL
		BEGIN
			DROP TABLE #tmpTransIds;
		END;

		CREATE TABLE #tmpTransIds(
				TransId				BIGINT			NOT NULL	PRIMARY KEY
		);

		INSERT INTO #tmpTransIds (TransId)
		SELECT value FROM STRING_SPLIT(@ListTransId, ',');

		INSERT INTO #tmpTickets
		(
			TransId,
			TransDate,
			MatchId,
			EventDate,
			EventStatus,
			KickOffTime,
			HomeId,
			AwayId,
			LeagueId,
			BetType,
			CustId,
			BetTeam,
			Stake,
			Odds,
			Hdp1,
			Hdp2,
			LiveHomeScore,
			LiveAwayScore,
			TicketStatus, 
			LiveIndicator,
			Currency,
			IP,
			ActualRate
		)
		SELECT	b.transid
			,	b.transdate
			,	b.matchid
			,	m.eventdate
			,	m.Eventstatus
			,	m.kickofftime
			,	m.homeid
			,	m.awayid
			,	m.leagueid
			,	b.bettype
			,	b.custid
			,	b.betteam
			,	b.stake
			,	b.odds
			,	b.hdp1
			,	b.hdp2
			,	b.livehomescore
			,	b.liveawayscore
			,	b.statusID
			,	b.liveindicator
			,	b.currency
			,	b.ip
			,	b.actualrate
		FROM #tmpTransIds AS t WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettrans AS b WITH(NOLOCK) ON t.TransId = b.transid
			INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
		;

		DELETE t WITH(ROWLOCK)
		FROM #tmpTransIds AS t
			INNER JOIN #tmpTickets AS b WITH(NOLOCK) ON  t.TransId = b.transid;

		INSERT INTO #tmpTickets
		(
			TransId,
			TransDate,
			MatchId,
			EventDate,
			EventStatus,
			KickOffTime,
			HomeId,
			AwayId,
			LeagueId,
			BetType,
			CustId,
			BetTeam,
			Stake,
			Odds,
			Hdp1,
			Hdp2,
			LiveHomeScore,
			LiveAwayScore,
			TicketStatus, 
			LiveIndicator,
			Currency,
			IP,
			ActualRate
		)
		SELECT	b.transid
			,	b.transdate
			,	b.matchid
			,	m.eventdate
			,	m.Eventstatus
			,	m.kickofftime
			,	m.homeid
			,	m.awayid
			,	m.leagueid
			,	b.bettype
			,	b.custid
			,	b.betteam
			,	b.stake
			,	b.odds
			,	b.hdp1
			,	b.hdp2
			,	b.livehomescore
			,	b.liveawayscore
			,	b.statusID
			,	b.liveindicator
			,	b.currency
			,	b.ip
			,	b.actualrate
		FROM #tmpTransIds AS t WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettrans14 AS b WITH(NOLOCK) ON t.TransId = b.transid
			INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.matchid = m.matchid
		;

		DELETE t WITH(ROWLOCK)
		FROM #tmpTransIds AS t
			INNER JOIN #tmpTickets AS b WITH(NOLOCK) ON  t.TransId = b.transid;

		INSERT INTO #tmpTickets
		(
			TransId,
			TransDate,
			MatchId,
			EventDate,
			EventStatus,
			KickOffTime,
			HomeId,
			AwayId,
			LeagueId,
			BetType,
			CustId,
			BetTeam,
			Stake,
			Odds,
			Hdp1,
			Hdp2,
			LiveHomeScore,
			LiveAwayScore,
			TicketStatus, 
			LiveIndicator,
			Currency,
			IP,
			ActualRate
		)
		SELECT	b.transid
			,	b.transdate
			,	b.matchid
			,	m.eventdate
			,	m.Eventstatus
			,	m.kickofftime
			,	m.homeid
			,	m.awayid
			,	m.leagueid
			,	b.bettype
			,	b.custid
			,	b.betteam
			,	b.stake
			,	b.odds
			,	b.hdp1
			,	b.hdp2
			,	b.livehomescore
			,	b.liveawayscore
			,	b.statusID
			,	b.liveindicator
			,	b.currency
			,	dp.ip
			,	b.actualrate
		FROM #tmpTransIds AS t WITH(NOLOCK)
			INNER JOIN bodb_Archive.dbo.bettrans_bk AS b WITH(NOLOCK) ON t.TransId = b.transid
			CROSS APPLY bodb02.dbo.f_IP_Decompress(b.ip) AS dp
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON b.matchid = m.matchid
		;
	END
	ELSE
	BEGIN
		DECLARE @TopTransRemaining	INT = 0
			,	@TopTransDeleted	INT = 0
			,	@IsExit				INT = 0
			,	@MinEventDate		DATETIME = NULL
			,	@MinMatchId			INT = NULL
			;
		
		
		IF	OBJECT_ID('tempdb..#tmpTransMatch') IS NOT NULL
		BEGIN
			DROP TABLE #tmpTransMatch;
		END;

		CREATE TABLE #tmpTransMatch(
				TransId				BIGINT			NOT NULL	PRIMARY KEY
			,	MatchId				INT				NULL
			,	EventDate			DATETIME		NULL
			,	EventStatus			NVARCHAR(50)	NULL
			,	KickOffTime			DATETIME		NULL
			,	HomeId				INT				NULL
			,	AwayId				INT				NULL
			,	LeagueId			INT				NULL
			,	INDEX IX_tmpTransIds_EventDate_MatchId (EventDate,MatchId)
		);

		IF	OBJECT_ID('tempdb..#tmpMatchIds') IS NOT NULL
		BEGIN
			DROP TABLE #tmpMatchIds;
		END;

		CREATE TABLE #tmpMatchIds(
				MatchId		INT			NOT NULL	PRIMARY KEY
		);

		INSERT INTO #tmpTransMatch
		(
				TransId
			,	MatchId
		)
		SELECT	JSON_VALUE(t.value, '$.TransID') AS TransId
			,	JSON_VALUE(t.value, '$.MatchID') AS MatchId
		FROM OPENJSON (@ListTransId) AS t;

		UPDATE t WITH (UPDLOCK)
		SET		EventDate	= m.eventdate
			,	EventStatus = m.eventstatus
			,	KickOffTime = m.kickofftime
			,	HomeId		= m.homeid
			,	AwayId		= m.awayid
			,	LeagueId	= m.leagueid
		FROM #tmpTransMatch AS t
			INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON t.MatchId = m.matchid;

		UPDATE t WITH (UPDLOCK)
		SET		EventDate	= m.eventdate
			,	EventStatus = m.eventstatus
			,	KickOffTime = m.kickofftime
			,	HomeId		= m.homeid
			,	AwayId		= m.awayid
			,	LeagueId	= m.leagueid
		FROM #tmpTransMatch AS t
			INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON t.MatchId = m.matchid
		WHERE t.EventDate IS NULL;

		UPDATE t WITH (UPDLOCK)
		SET		EventDate	= m.eventdate
			,	EventStatus = m.eventstatus
			,	KickOffTime = m.kickofftime
			,	HomeId		= m.homeid
			,	AwayId		= m.awayid
			,	LeagueId	= m.leagueid
		FROM #tmpTransMatch AS t
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON t.MatchId = m.matchid
		WHERE t.EventDate IS NULL;

		WITH CTE_Match AS
		(
			SELECT	MatchId
				,	MAX(EventDate) AS EventDate
			FROM #tmpTransMatch
			GROUP BY MatchId
		)
		INSERT INTO #tmpMatchIds (MatchId)
		SELECT TOP (@MatchSize) MatchId 
		FROM CTE_Match
		ORDER BY EventDate DESC, MatchId DESC;

		DELETE t1 WITH (ROWLOCK)
		FROM #tmpTransMatch AS t1
			LEFT JOIN #tmpMatchIds AS t2 WITH(NOLOCK) ON t2.MatchId = t1.MatchId
		WHERE t2.MatchId IS NULL;

		SELECT TOP (1)	@MinEventDate = t.EventDate
					,	@MinMatchId = t.MatchId
		FROM #tmpTransMatch AS t
			CROSS APPLY (	SELECT TOP (@TransSize) EventDate, MatchId
							FROM #tmpTransMatch
							ORDER BY EventDate DESC, MatchId DESC) AS c
		WHERE t.EventDate = c.EventDate
			AND t.MatchId = c.MatchId
		ORDER BY t.EventDate ASC, t.MatchId ASC;

		DELETE t WITH (ROWLOCK)
		FROM #tmpTransMatch AS t
		WHERE t.EventDate <= @MinEventDate
			AND t.MatchId < @MinMatchId;

		INSERT INTO #tmpTickets
		(
			TransId,
			TransDate,
			MatchId,
			EventDate,
			EventStatus,
			KickOffTime,
			HomeId,
			AwayId,
			LeagueId,
			BetType,
			CustId,
			BetTeam,
			Stake,
			Odds,
			Hdp1,
			Hdp2,
			LiveHomeScore,
			LiveAwayScore,
			TicketStatus, 
			LiveIndicator,
			Currency,
			IP,
			ActualRate
		)
		SELECT TOP (@TransSize)
				b.transid
			,	b.transdate
			,	b.matchid
			,	t.EventDate
			,	t.EventStatus
			,	t.KickOffTime
			,	t.HomeId
			,	t.AwayId
			,	t.LeagueId
			,	b.bettype
			,	b.custid
			,	b.betteam
			,	b.stake
			,	b.odds
			,	b.hdp1
			,	b.hdp2
			,	b.livehomescore
			,	b.liveawayscore
			,	b.statusID
			,	b.liveindicator
			,	b.currency
			,	b.ip
			,	b.actualrate
		FROM #tmpTransMatch AS t WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettrans AS b WITH(NOLOCK) ON t.TransId = b.transid
		ORDER BY t.EventDate DESC, b.matchid DESC, b.transdate DESC
		;

		DELETE t WITH(ROWLOCK)
		FROM #tmpTransMatch AS t
			INNER JOIN #tmpTickets AS b WITH(NOLOCK) ON  t.TransId = b.transid;

		SET @TopTransDeleted = @@ROWCOUNT;

		IF @TopTransDeleted >= @TransSize
		BEGIN
			SET @IsExit = 1;
		END
		ELSE
		BEGIN
			SET @TopTransRemaining = @TransSize - @TopTransDeleted;
		END;

		INSERT INTO #tmpTickets
		(
			TransId,
			TransDate,
			MatchId,
			EventDate,
			EventStatus,
			KickOffTime,
			HomeId,
			AwayId,
			LeagueId,
			BetType,
			CustId,
			BetTeam,
			Stake,
			Odds,
			Hdp1,
			Hdp2,
			LiveHomeScore,
			LiveAwayScore,
			TicketStatus, 
			LiveIndicator,
			Currency,
			IP,
			ActualRate
		)
		SELECT TOP (@TopTransRemaining)
				b.transid
			,	b.transdate
			,	b.matchid
			,	t.EventDate
			,	t.EventStatus
			,	t.KickOffTime
			,	t.HomeId
			,	t.AwayId
			,	t.LeagueId
			,	b.bettype
			,	b.custid
			,	b.betteam
			,	b.stake
			,	b.odds
			,	b.hdp1
			,	b.hdp2
			,	b.livehomescore
			,	b.liveawayscore
			,	b.statusID
			,	b.liveindicator
			,	b.currency
			,	b.ip
			,	b.actualrate
		FROM #tmpTransMatch AS t WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettrans14 AS b WITH(NOLOCK) ON t.TransId = b.transid
		WHERE @IsExit = 0
		ORDER BY t.EventDate DESC, b.matchid DESC, b.transdate DESC
		;

		DELETE t WITH(ROWLOCK)
		FROM #tmpTransMatch AS t
			INNER JOIN #tmpTickets AS b WITH(NOLOCK) ON  t.TransId = b.transid;

		SET @TopTransDeleted = @TopTransDeleted + @@ROWCOUNT;

		IF @TopTransDeleted >= @TransSize
		BEGIN
			SET @IsExit = 1;
		END
		ELSE
		BEGIN
			SET @TopTransRemaining = @TransSize - @TopTransDeleted;
		END
		;

		INSERT INTO #tmpTickets
		(
			TransId,
			TransDate,
			MatchId,
			EventDate,
			EventStatus,
			KickOffTime,
			HomeId,
			AwayId,
			LeagueId,
			BetType,
			CustId,
			BetTeam,
			Stake,
			Odds,
			Hdp1,
			Hdp2,
			LiveHomeScore,
			LiveAwayScore,
			TicketStatus, 
			LiveIndicator,
			Currency,
			IP,
			ActualRate
		)
		SELECT TOP (@TopTransRemaining)
				b.transid
			,	b.transdate
			,	b.matchid
			,	t.EventDate
			,	t.EventStatus
			,	t.KickOffTime
			,	t.HomeId
			,	t.AwayId
			,	t.LeagueId
			,	b.bettype
			,	b.custid
			,	b.betteam
			,	b.stake
			,	b.odds
			,	b.hdp1
			,	b.hdp2
			,	b.livehomescore
			,	b.liveawayscore
			,	b.statusID
			,	b.liveindicator
			,	b.currency
			,	dp.ip
			,	b.actualrate
		FROM #tmpTransMatch AS t WITH(NOLOCK)
			INNER JOIN bodb_Archive.dbo.bettrans_bk AS b WITH(NOLOCK) ON t.TransId = b.transid
			CROSS APPLY bodb02.dbo.f_IP_Decompress(b.ip) AS dp
		WHERE @IsExit = 0
		ORDER BY t.EventDate DESC, b.matchid DESC, b.transdate DESC
		;

	END;

	-- Return data
	SELECT DISTINCT t.TransId
		,	t.TransDate
		,	t.MatchId
		,	t.EventDate
		,	t.EventStatus
		,	t.KickOffTime
		,	t.HomeId
		,	t.AwayId
		,	t.LeagueId
		,	t.BetType
		,	bt.typenamee AS TypeName
		,	c.CustId
		,	c.username AS UserName
		,	t.BetTeam
		,	t.Stake
		,	(t.Stake * t.ActualRate) AS StakeRM
		,	e.currency AS CurrencyName
		,	t.Odds
		,	t.Hdp1
		,	t.Hdp2
		,	t.LiveHomeScore
		,	t.LiveAwayScore
		,	t.TicketStatus
		,	t.LiveIndicator
		,	t.IP
	FROM #tmpTickets AS t WITH(NOLOCK)
		INNER JOIN 	bodb02.dbo.custInfo AS c WITH(NOLOCK) ON c.custid = t.CustId
		INNER JOIN 	bodb02.dbo.bettype AS bt WITH(NOLOCK) ON bt.typeid = t.BetType
		LEFT JOIN 	bodb02.dbo.Exchange AS e WITH(NOLOCK) ON e.ExchangeId = t.Currency;

	DROP TABLE IF EXISTS #tmpTickets;
	DROP TABLE IF EXISTS #tmpTransIds;
	DROP TABLE IF EXISTS #tmpTransMatch;
	DROP TABLE IF EXISTS #tmpMatchIds;

END;
GO