/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_MatchMonitorParlay_GetNewTicket]
		@LastScannedSequenceID		BIGINT = 0
	,	@IsLive						BIT = 1
	,	@BatchSize					INT = 500
	,	@ListSportBettype			VARCHAR(MAX)

AS
/*
	Created: 20240822@Casey.Huynh
	Task : CTS - Match Monitor Parlay, Get New Ticket
	DB	 : bodb02

	Revisions:
		- 20240822@Casey.Huynh: Created [Redmine ID: 152883]
		- 20241217@Victoria.Le: Super/Master Direct Member [Redmine ID: #214585]
        - 20250923@Long.Luu: 	Add Agents ORI6RM & ORI20RM  as internal account [Redmine ID: #239117]

	Params Explaination:

	Example:

		EXEC [CTS_MatchMonitorParlay_GetNewTicket] 
			 @LastScannedSequenceID=1
			,@IsLive=0
			,@BatchSize=500
			,@ListSportBettype='[		{"SportTypeID":1, "BetTypeID":1}
									,	{"SportTypeID":1, "BetTypeID":3}
									,	{"SportTypeID":1, "BetTypeID":7}
									,	{"SportTypeID":1, "BetTypeID":8}
									,	{"SportTypeID":2, "BetTypeID":1}
									,	{"SportTypeID":2, "BetTypeID":3}
									,	{"SportTypeID":2, "BetTypeID":7}
									,	{"SportTypeID":2, "BetTypeID":8}
									,	{"SportTypeID":2, "BetTypeID":20}
									,	{"SportTypeID":2, "BetTypeID":609}
									,	{"SportTypeID":2, "BetTypeID":610}
									,	{"SportTypeID":2, "BetTypeID":612}]';
*/
BEGIN
	SET NOCOUNT ON;
	
	IF	OBJECT_ID('tempdb..#tmpParlayTrans') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpParlayTrans;
	END;

	CREATE TABLE #tmpParlayTrans(
			Refno		BIGINT
		,	SequenceID	BIGINT		
		,	TransID		BIGINT
	)
	
	CREATE CLUSTERED INDEX CIX_tmpParlayTrans_Refno ON #tmpParlayTrans(Refno);
	CREATE NONCLUSTERED INDEX IX_tmpParlayTrans_SequenceID ON #tmpParlayTrans(SequenceID);

	--===========================================================================
	IF	OBJECT_ID('tempdb..#tmpSportBettype') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpSportBettype;
	END;

	CREATE TABLE #tmpSportBettype(
			SportTypeID	SMALLINT
		,	BetTypeID	INT 
	)
	
	CREATE CLUSTERED INDEX CIX_tmpSportBettype_SportTypeIDBetTypeID ON #tmpSportBettype(SportTypeID,BetTypeID);
	
	--==================================================================
	IF @ListSportBettype <> ''
	BEGIN
		INSERT INTO #tmpSportBettype(SportTypeID,BetTypeID)
		SELECT DISTINCT	j.SportTypeID
					,	j.BetTypeID
		FROM OPENJSON (@ListSportBettype) WITH (
				SportTypeID	SMALLINT	'$.SportTypeID'
			,	BetTypeID	INT			'$.BetTypeID'
			) AS j;
	END;

	--========================================================================================
	INSERT INTO #tmpParlayTrans(Refno,SequenceId,Transid)
	SELECT TOP(@BatchSize)
			bt.refno		AS Refno	
		,	bt.sequenceid 	AS SequenceId
		,	bt.transid 		AS TransId
	FROM bodb02.dbo.bettrans AS bt WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON bt.custid = c.custid
	WHERE	bt.sequenceid > @LastScannedSequenceID
		AND bt.Currency NOT IN (20,27,28)
		AND bt.srecommend NOT IN (41430709) 
		AND bt.mrecommend NOT IN (27899314,11656504,12146012) 
		AND bt.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
		AND c.site NOT IN ('Nextbet','9wickets','9wsports')
		AND c.Username NOT LIKE '%Cashout%'
		AND (CAST(bt.BetCheck AS INT) & 2 = 2  -- Combo 2 bit 2
			OR CAST(bt.BetCheck AS INT) & 4 = 4) -- Combo 3 bit 3
		AND bt.Betteam = 1						-- 1:Mix Parlay
		AND bt.Bettype = 29
		AND bt.MatchID = 29
	ORDER BY bt.sequenceid ASC;
	--==========================================================================================
	SELECT Max(pt.SequenceId) AS MaxSequenceID 
	FROM #tmpParlayTrans AS pt WITH(NOLOCK);

	SELECT	
			pt.sequenceid 				AS SequenceID
		,	pt.transid 					AS TransID
		,	b.Refno						AS Refno
		,	b.transid 					AS TransIDm
		,	b.transdate 				AS TransDate
		,	b.matchid 					AS MatchID
		,	m.sporttype 				AS SportType
		,	b.livehomescore 			AS LiveHomeScore
		,	b.liveawayscore 			AS LiveAwayScore
		,	b.bettype 					AS BetTypeID
		,	(CASE WHEN b.BetCheck = '' THEN 0 ELSE b.BetCheck END) AS BetID			
		,	b.betteam 					AS BetTeam
		,	b.custid 					AS CustID
		,	m.eventdate 				AS EventDate
		,	m.GlobalShowTime 			AS KickOffTime
		,	m.Eventstatus 				AS EventStatus			
		,	m.homeid 					AS HomeID
		,	m.awayid 					AS AwayID
		,	m.leagueid 					AS LeagueID
		,	l.leaguename 				AS LeagueName
	FROM #tmpParlayTrans AS pt WITH(NOLOCK)
		INNER JOIN bodb02.dbo.bettransm AS b WITH(NOLOCK) ON b.Refno = pt.Refno
		INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
		INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN #tmpSportBettype AS tmp WITH(NOLOCK) ON m.sporttype = tmp.SportTypeID AND b.bettype = tmp.BetTypeID
	WHERE	pt.sequenceid > @LastScannedSequenceID
		AND	m.eventstatus <> 'completed'
		AND b.LiveIndicator = @IsLive
		AND b.BetFrom NOT IN ('p','m','w','0','3','6')
		AND l.LeagueGroupID NOT IN (42,74,108,113,122,151)
	ORDER BY pt.sequenceid, b.refno;

	DROP TABLE IF EXISTS #tmpSportBettype;

END;
GO
