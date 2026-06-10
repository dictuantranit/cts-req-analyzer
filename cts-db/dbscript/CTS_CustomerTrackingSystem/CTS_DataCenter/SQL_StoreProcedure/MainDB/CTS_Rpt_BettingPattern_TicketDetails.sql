/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CTS_Rpt_BettingPattern_TicketDetails]
		@EventDate			DATETIME
	,	@MatchId			INT
	,	@CustIds			VARCHAR(2000) = ''
	,	@Bettypes			VARCHAR(2000) = ''

AS
/*
	Created: 20210304@John.Ngo
	Task : Match List Betting Pattern - Match Details
	DB	 : WASAVerse

	Revisions:
		- 20210304@John.Ngo: Display betting pattern details [Redmine ID: #151156]
		- 20220408@Long.Luu: Get more data from AssociationGroupByAI [Redmine ID: #171222]
		- 20230111@John.Ngo: Get more data for Association betting pattern details [Redmine ID: #181994]
		- 20250428@Thomas.Nguyen: Upgrade CurrencyID datatype, switch SP to WASAVerse [Redmine ID: #225335]

	Params Explaination:
		EXECUTE [dbo].[CTS_Rpt_BettingPattern_TicketDetails] @EventDate = '2021-02-23 00:00:00.000', @MatchId = 40391219, @CustId1 = 46777100, @CustId2 = 47717138, @Bettypes = '1,3'
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME;

	IF	OBJECT_ID('tempdb..#BUMBData') IS NOT NULL
	BEGIN;
		DROP TABLE	#BUMBData;
	END;

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

	-- Initialize date range
	DECLARE @IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0;

	IF @EventDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1;
	END
	ELSE IF @EventDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1;
	END
	ELSE IF @EventDate > @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFromOrigin = 1;
	END;

	IF	OBJECT_ID('tempdb..#tmpCustIds') IS NOT NULL
	BEGIN
		DROP TABLE #tmpCustIds;
	END;

	CREATE TABLE #tmpCustIds(
			CustId				INT NOT NULL PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpBettypes') IS NOT NULL
	BEGIN
		DROP TABLE #tmpBettypes;
	END;

	CREATE TABLE #tmpBettypes(
			BettypeId			INT NOT NULL PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpMatchDetails') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpMatchDetails;
	END;

	CREATE TABLE	#tmpMatchDetails(
			CustId				INT
		,	MatchId				INT
		,	EventDate			DATETIME
		,	TransDate			DATETIME
		,	TransId				BIGINT
		,	BetType				SMALLINT
		,	BetTeam				NVARCHAR(10)
		,	Stake				MONEY
		,	Odds				SMALLMONEY
		,	LiveHomeScore		SMALLINT
		,	LiveAwayScore		SMALLINT
		,	Currency			SMALLINT
		,	IP					VARCHAR(45)
		,	ActualRate			FLOAT
	);	
	
	CREATE CLUSTERED INDEX #CIX_tmpMatchDetailsIdx ON #tmpMatchDetails (
			EventDate			DESC
	);

	IF @Bettypes <> ''
	BEGIN
		INSERT INTO #tmpBettypes (BettypeId)
		SELECT ssk.value FROM STRING_SPLIT(@Bettypes, ',') ssk;
	END;

	IF @CustIds <> ''
	BEGIN
		INSERT INTO #tmpCustIds (CustId)
		SELECT ssk.value FROM STRING_SPLIT(@CustIds, ',') ssk;
	END;	

	-- START --
	IF @IsGetDataFromBK = 1
	BEGIN
		INSERT INTO #tmpMatchDetails(	
				CustId
			,	MatchId
			,	EventDate
			,	TransDate
			,	TransId
			,	BetType
			,	BetTeam
			,	Stake
			,	Odds
			,	LiveHomeScore
			,	LiveAwayScore
			,	Currency
			,	IP
			,	ActualRate)
		SELECT	b.custid
			,	b.matchid
			,	b.winlostdate
			,	b.transdate
			,	b.transid
			,	b.bettype
			,	b.betteam
			,	b.stake
			,	b.odds
			,	b.livehomescore
			,	b.liveawayscore
			,	b.currency
			,	dp.ip
			,	b.actualrate
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH(NOLOCK)
			CROSS APPLY bodb02.dbo.f_IP_Decompress(b.ip) AS dp
			INNER JOIN #tmpCustIds AS c WITH(NOLOCK) ON b.custid = c.CustId
			LEFT JOIN #tmpBettypes AS tbt WITH(NOLOCK) ON tbt.BettypeId = b.bettype
		WHERE	b.winlostdate = @EventDate
			AND b.matchid = @MatchId
			AND (@Bettypes = '' OR tbt.BettypeId IS NOT NULL);
	END;

	IF	@IsGetDataFrom14 = 1
	BEGIN
		INSERT INTO #tmpMatchDetails(	
				CustId
			,	MatchId
			,	EventDate
			,	TransDate
			,	TransId
			,	BetType
			,	BetTeam
			,	Stake
			,	Odds
			,	LiveHomeScore
			,	LiveAwayScore
			,	Currency
			,	IP
			,	ActualRate)
		SELECT	b.custid
			,	b.matchid
			,	b.winlostdate
			,	b.transdate
			,	b.transid
			,	b.bettype
			,	b.betteam
			,	b.stake
			,	b.odds
			,	b.livehomescore
			,	b.liveawayscore
			,	b.currency
			,	b.ip
			,	b.actualrate
		FROM bodb02.dbo.bettrans14 AS b WITH(NOLOCK)
			INNER JOIN #tmpCustIds AS c WITH(NOLOCK) ON b.custid = c.CustId
			LEFT JOIN #tmpBettypes AS tbt WITH(NOLOCK) ON tbt.BettypeId = b.bettype
		WHERE	b.winlostdate = @EventDate
			AND b.matchid = @MatchId
			AND (@Bettypes = '' OR tbt.BettypeId IS NOT NULL);
	END;

	IF	@IsGetDataFromOrigin = 1
	BEGIN
		INSERT INTO #tmpMatchDetails(	
				CustId
			,	MatchId
			,	EventDate
			,	TransDate
			,	TransId
			,	BetType
			,	BetTeam
			,	Stake
			,	Odds
			,	LiveHomeScore
			,	LiveAwayScore
			,	Currency
			,	IP
			,	ActualRate)
		SELECT	b.custid
			,	b.matchid
			,	b.winlostdate
			,	b.transdate
			,	b.transid
			,	b.bettype
			,	b.betteam
			,	b.stake
			,	b.odds
			,	b.livehomescore
			,	b.liveawayscore
			,	b.currency
			,	b.ip
			,	b.actualrate
		FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
			INNER JOIN #tmpCustIds AS c WITH(NOLOCK) ON b.custid = c.CustId
			LEFT JOIN #tmpBettypes AS tbt WITH(NOLOCK) ON tbt.BettypeId = b.bettype
		WHERE	b.winlostdate = @EventDate
			AND b.matchid = @MatchId
			AND (@Bettypes = '' OR tbt.BettypeId IS NOT NULL);
	END;

	-- Return data
	SELECT	c.custid AS CustID
		,	c.username AS UserName
		,	m.TransDate
		,	m.TransId
		,	bt.typenamee AS TypeName
		,	m.BetTeam
		,	m.Stake*m.ActualRate AS StakeRM
		,	m.Stake
		,	e.currency AS CurrencyName
		,	m.Odds
		,	m.LiveHomeScore
		,	m.LiveAwayScore
		,	m.IP
	FROM #tmpMatchDetails AS m WITH(NOLOCK)
		INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON c.custid = m.CustId
		INNER JOIN bodb02.dbo.bettype AS bt WITH(NOLOCK) ON bt.typeid = m.BetType
		LEFT JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) ON e.ExchangeId = m.Currency
	ORDER BY m.TransDate DESC;
	
	DROP TABLE #tmpMatchDetails;

END;

GO