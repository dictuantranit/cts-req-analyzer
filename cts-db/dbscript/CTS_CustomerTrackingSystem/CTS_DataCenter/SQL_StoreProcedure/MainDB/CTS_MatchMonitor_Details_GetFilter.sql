/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CTS_MatchMonitor_Details_GetFilter]
		@MatchID					INT = 0
	,	@EventDate					DATETIME = '1900-09-22'
	,	@ListSportBettype			VARCHAR(MAX)
	,	@IsLive						BIT = 0
	,	@ListSuspiciousTransId		VARCHAR(MAX) = ''
	,	@ViewMode					TINYINT = 0
	,	@IsExclTestCurr				BIT = 0
	,	@FromTransDate				DATETIME = NULL
	,	@ToTransDate				DATETIME = NULL
	,	@UserNameList				VARCHAR(MAX) = ''

	,	@MaxSequenceId				BIGINT		OUTPUT
	,	@MaxTransDate				DATETIME	OUTPUT
	,	@TotalTicketAll				BIGINT		OUTPUT
	,	@TotalTicketLicensee		BIGINT		OUTPUT
	,	@TotalTicketCredit			BIGINT		OUTPUT

AS
/*
	Created: 20230601@Victoria.Le
	Task : CTS - Match Monitor Details - Get ALL Tickets - Get Distinct Currency,HDP,Score 
	DB	 : bodb02

	Revisions:
		- 20230601@Victoria.Le:		Initial Writing [Redmine ID: #185793]		
		- 20230721@Victoria.Le:		Get CurrencyName from table Exchange [Redmine ID: #191422]
		- 20230724@Victoria.Le:		Add condition BetID with BetType = Quarter X HDP/OU/MoneyLine [Redmine ID: #191703]
		- 20230724@Victoria.Le:		Bettype Selection - Return interdependence of columns  [Redmine ID: #191401]
		- 20230911@Casey.Huynh:		Support Filter For Suspicious Trans AND CustomerClass and  [Redmine ID: #193029]
		- 20231116@Long.Luu: 		Support filter by FromTransDate-ToTransDate [Redmine ID: 195042]
		- 20231122@Casey.Huynh:		Create SportBetType Setting and New E-Sports Bettypes [Redmine ID: #196396]
		- 20240129@Casey.Huynh:		Support Danger Monitor Details In 7 days [Redmine ID: #196361]
		- 20240129@Thomas.Nguyen:	Return more column IsCashout [Redmine ID: #199634]
		- 20240322@Vitoria.Le: 		Exclude Internal Account for Danger Monitor [Redmine ID: #201380]
		- 20240521@Thomas.Nguyen:	Remove hardcode 2 Agent WINRM and M999RM00 as internal accounts for Danger Monitor [Redmine ID: #205239]
		- 20240904@Casey.Huynh:		Rename @TicketType To @ViewMode [Redmine ID: #207397]
		- 20241226@Thomas.Nguyen: 	Add Username Filter [Redmine ID: #210128]
		- 20241217@Victoria.Le: 	Super/Master Direct Member [Redmine ID: #214585]
		- 20250225@Casey.Huynh:		Handle @ListSportBetType (Criket BetID IS NULL) [Redmine ID: #218383]
		- 20250318@Casey.Huynh:		Match Monitor Badminton, Rename from CTS_TicketDetails_Info [Redmine ID: #219681]
		- 20250428@Thomas.Nguyen:	Upgrade CurrencyID datatype [Redmine ID: #225335]
        - 20250923@Long.Luu: 		Add Agents ORI6RM & ORI20RM  as internal account [Redmine ID: #239117]

	Params Explaination:
		@ListSuspiciousTransId: format JSON
			@ListSuspiciousTransId = '[{"TransId":1, "Reason":'HED', "GroupId":1},{"TransId":1, "Reason":'GB', "GroupId":1},{"TransId":2, "Reason":'GB', "GroupId":1},{"TransId":3, "Reason":'HED', "Group":1}]'
		@ViewMode	: TINYINT
			@ViewMode=0: Ticket Type = 'All-MatchMonitor'			
			@ViewMode=1: Ticket Type = 'Suspicious'
			@ViewMode=2: Ticket Type = 'All-Danger Monitor'
		@ListSportBettype: JSON
			,@ListSportBettype='[	{"SportTypeID":1, "BetTypeID":1, "BetChoiceType":2}
								,	{"SportTypeID":2, "BetTypeID":3, "BetChoiceType":2}
								,	{"SportTypeID":43, "BetTypeID":9001, "BetChoiceType":2}]'	

	Example:
		DECLARE @MaxSequenceId BIGINT,@TotalTicketAll BIGINT,@TotalTicketLicensee BIGINT,@TotalTicketCredit BIGINT;
		EXEC [dbo].[CTS_MatchMonitor_Details_GetFilter] 
			72186342 -- @MatchID
		,	NULL -- @EventDate
		,	'[		{"SportTypeID":1, "BetTypeID":1, "BetChoiceType":2}
								,	{"SportTypeID":43, "BetTypeID":9001, "BetChoiceType":2}
								,	{"SportTypeID":43, "BetTypeID":9003, "BetChoiceType":2}]'
		--,	1 -- @BetType
		,	1 -- @IsLive
		,	'' -- @ListSuspiciousTransId
		,	0  --@ViewMode (0:All, 1: Suspicious)
		,	0 -- @IsExclTestCurr
		--,	0 -- @BetID
		,	@MaxSequenceId OUTPUT
		,	@TotalTicketAll OUTPUT
		,	@TotalTicketLicensee OUTPUT
		,	@TotalTicketCredit OUTPUT

		SELECT @MaxSequenceId AS MaxSequenceId,@TotalTicketAll AS TotalTicketAll,@TotalTicketLicensee AS TotalTicketLicensee,@TotalTicketCredit AS TotalTicketCredit

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0;
		
	SET @ToTransDate = DATEADD(SECOND,1,@ToTransDate);
	---====================================================================================
	DECLARE @tmpBUMBData AS TABLE (BUDay DATETIME,	MBDay DATETIME);
	---====================================================================================
	
	IF	OBJECT_ID('tempdb..#tmpTrans') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTrans;
	END;

	CREATE TABLE #tmpTrans(
			TransId				BIGINT PRIMARY KEY
		,	CustId				INT
		,	Hdp1				SMALLMONEY
		,	Hdp2				SMALLMONEY
		,	LiveHomeScore		SMALLINT
		,	LiveAwayScore		SMALLINT
		,	BetTeam				NVARCHAR(10)
		,	CurrencyId			SMALLINT
		,	CurrencyName		NVARCHAR(100)
		,	Hdp					SMALLMONEY DEFAULT 0
		,	IsLicensee			BIT DEFAULT NULL
		,	BetType				SMALLINT
		,	TicketStatus		SMALLINT
		,	Danger1				TINYINT
		,	Danger2				TINYINT
		,	Danger3				TINYINT
		,	Danger4				TINYINT
		,	Danger5				TINYINT
		,	CustomerClass		SMALLINT
		,	SequenceId			BIGINT
		,	TransDate			DATETIME
		,	IsCashout			BIT
	);
	CREATE NONCLUSTERED INDEX #IX_tmpTickets_SequenceId ON #tmpTrans (
			SequenceId			ASC
	);

	CREATE NONCLUSTERED INDEX #IX_tmpTickets_TransDate ON #tmpTrans (
			TransDate			ASC
	);

	IF	OBJECT_ID('tempdb..#tmpSuspiciousTrans') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpSuspiciousTrans;
	END;

	CREATE TABLE	#tmpSuspiciousTrans(
			TransId					BIGINT NOT NULL
		,	SuspiciousReason		VARCHAR(50)
		,	SuspiciousGroupId		INT
	);

	CREATE NONCLUSTERED INDEX #IX_tmptmpSuspiciousTrans_TransId ON #tmpSuspiciousTrans (
			TransID		ASC
	);

	IF	OBJECT_ID('tempdb..#tmpSuspiciousDistinctTrans') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpSuspiciousDistinctTrans;
	END;

	CREATE TABLE	#tmpSuspiciousDistinctTrans(
			TransId					BIGINT PRIMARY KEY NOT NULL
	);

	IF	OBJECT_ID('tempdb..#tmpSportBettype') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpSportBettype;
	END;

	CREATE TABLE	#tmpSportBettype(
			SportTypeID				SMALLINT
		,	BetTypeID				INT
		,	BetChoiceType			TINYINT
		,	BetIDPattern			NVARCHAR(20)
		,	BetID					BIGINT
	);

	CREATE NONCLUSTERED INDEX #IX_tmpSportBettype_SportTypeBettype ON #tmpSportBettype (
			SportTypeID	ASC
		,	BetTypeID		ASC
	);

	DROP TABLE IF EXISTS #tmpUsername;
	CREATE TABLE	#tmpUsername(
			UserName	VARCHAR(50)  PRIMARY KEY	
	);

	DROP TABLE IF EXISTS #tmpCustomer;
	CREATE TABLE	#tmpCustomer(
			CustId		INT PRIMARY KEY	
	);

	IF ISNULL(@UserNameList,'') <> ''
	BEGIN
		INSERT INTO #tmpUsername(UserName)
		SELECT DISTINCT ssk.value FROM STRING_SPLIT (@UserNameList, ',') AS ssk;

		INSERT INTO #tmpCustomer(CustId)
		SELECT cs.custid
		FROM bodb02.dbo.Customer AS cs WITH (NOLOCK) 
			INNER JOIN #tmpUsername AS un WITH(NOLOCK) ON un.username = cs.username;
	END;

	--=============================================================================================
	
	--=======GET BALANCE UP/ MOVE BET DAY===========================================================
	INSERT INTO @tmpBUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;
	
	SELECT	TOP(1) @BalanceUpDay	= BUDay , @MoveBetsDay	= MBDay FROM @tmpBUMBData ;

	IF @EventDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1;
	END
	ELSE IF @EventDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1;
	END
	ELSE 
	BEGIN
		SELECT @IsGetDataFromOrigin = 1;
	END;

	--====================DEFINE SPORT BETTYPES=================================================================================================================
	IF @ListSportBettype <> ''
	BEGIN

		INSERT INTO #tmpSportBettype(SportTypeID,BetTypeID,BetChoiceType,BetIDPattern,BetID)
		SELECT	j.SportTypeID
			,	j.BetTypeID
			,	j.BetChoiceType
			,	j.BetIDPattern
			,	j.BetID
		FROM OPENJSON (@ListSportBettype) WITH (
				SportTypeID			SMALLINT		'$.SportTypeID'
			,	BetTypeID			INT				'$.BetTypeID'
			,	BetChoiceType		TINYINT			'$.BetChoiceType'
			,	BetIDPattern		NVARCHAR(20)	'$.BetIDPattern'
			,	BetID				BIGINT			'$.BetID'
			) AS j;


	END;
	
	--========================================================================================
	IF @ListSuspiciousTransId <> ''
	BEGIN

		INSERT INTO #tmpSuspiciousTrans (TransId,SuspiciousReason,SuspiciousGroupId)
		SELECT	j.TransID
			,	j.Reason
			,	j.GroupId
		FROM OPENJSON (@ListSuspiciousTransId) WITH (
				TransID		BIGINT '$.TransId'
			,	Reason		VARCHAR(50) '$.Reason'
			,	GroupId		INT '$.GroupId'
			) AS j;

		INSERT INTO #tmpSuspiciousDistinctTrans
		SELECT DISTINCT tmpTs.TransId 
		FROM #tmpSuspiciousTrans AS tmpTs WITH(NOLOCK);
		
	END;
	
	IF @ViewMode = 1 --GET Suspicious Ticket Only
	BEGIN
		IF @IsGetDataFromOrigin = 1
		BEGIN
			INSERT INTO #tmpTrans (
					TransId
				,	CustId
				,	Hdp1
				,	Hdp2
				,	LiveHomeScore
				,	LiveAwayScore
				,	BetTeam
				,	CurrencyName
				,	CurrencyId
				,	BetType
				,	Hdp
				,	TicketStatus
				,	IsCashout)
			SELECT	b.TransId
				,	b.custid
				,	b.Hdp1
				,	b.Hdp2
				,	b.LiveHomeScore
				,	b.LiveAwayScore
				,	b.BetTeam
				,	e.currency
				,	e.ExchangeId
				,	b.bettype
				,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
				,	b.statusID
				,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
			FROM #tmpSuspiciousDistinctTrans AS tmpTs WITH(NOLOCK)
				INNER JOIN bodb02.dbo.bettrans AS b WITH(NOLOCK) ON tmpTs.TransId = b.TransId
				INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #tmpSportBettype AS st WITH(NOLOCK) ON m.sporttype = st.SportTypeID AND b.bettype = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
				INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
			WHERE b.matchid = @MatchID
				AND b.liveindicator = @IsLive
				AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
				AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
				AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
		END;
		
		IF @IsGetDataFrom14 = 1
		BEGIN
			INSERT INTO #tmpTrans (
					TransId
				,	CustId
				,	Hdp1
				,	Hdp2
				,	LiveHomeScore
				,	LiveAwayScore
				,	BetTeam
				,	CurrencyName
				,	CurrencyId
				,	BetType
				,	hdp
				,	TicketStatus
				,	IsCashout)
			SELECT	b.TransId
				,	b.custid
				,	b.Hdp1
				,	b.Hdp2
				,	b.LiveHomeScore
				,	b.LiveAwayScore
				,	b.BetTeam
				,	e.currency
				,	e.ExchangeId
				,	b.bettype
				,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS Hdp
				,	b.statusID
				,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
			FROM #tmpSuspiciousDistinctTrans AS tmpTs WITH(NOLOCK)
				INNER JOIN bodb02.dbo.bettrans14 AS b WITH(NOLOCK) ON tmpTs.TransId = b.TransId
				INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #tmpSportBettype AS st WITH(NOLOCK) ON m.sporttype = st.SportTypeID AND b.bettype = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
				INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
			WHERE b.matchid = @MatchID
				AND b.liveindicator = @IsLive
				AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
				AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
				AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
		END;
		
		IF @IsGetDataFromBK = 1
		BEGIN
			INSERT INTO #tmpTrans (
					TransId
				,	CustId
				,	Hdp1
				,	Hdp2
				,	LiveHomeScore
				,	LiveAwayScore
				,	BetTeam
				,	CurrencyName
				,	CurrencyId
				,	BetType
				,	Hdp
				,	TicketStatus
				,	IsCashout)
			SELECT	b.TransId
				,	b.custid
				,	b.Hdp1
				,	b.Hdp2
				,	b.LiveHomeScore
				,	b.LiveAwayScore
				,	b.BetTeam
				,	e.currency
				,	e.ExchangeId
				,	b.bettype
				,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS Hdp
				,	b.statusID
				,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
			FROM #tmpSuspiciousDistinctTrans AS tmpTs WITH(NOLOCK)
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS b WITH(NOLOCK) ON tmpTs.TransId = b.TransId
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #tmpSportBettype AS st WITH(NOLOCK) ON m.sporttype = st.SportTypeID AND b.bettype = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
				INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
			WHERE b.matchid = @MatchID
				AND b.liveindicator = @IsLive
				AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
				AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
				AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
		END;

	END;
	
	IF @ViewMode = 0 --GET All Ticket - MM
	BEGIN
		INSERT INTO #tmpTrans (
				TransId
			,	CustId
			,	Hdp1
			,	Hdp2
			,	LiveHomeScore
			,	LiveAwayScore
			,	BetTeam
			,	CurrencyName
			,	CurrencyId
			,	BetType
			,	Hdp
			,	TicketStatus				
			,	SequenceId
			,	IsCashout)
		SELECT	b.TransId
			,	b.custid
			,	b.Hdp1
			,	b.Hdp2
			,	b.LiveHomeScore
			,	b.LiveAwayScore
			,	b.BetTeam
			,	e.currency
			,	e.ExchangeId
			,	b.bettype
			,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS Hdp
			,	b.statusID				
			,	SequenceId
			,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
		FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
			INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
			INNER JOIN #tmpSportBettype AS st WITH(NOLOCK) ON m.sporttype = st.SportTypeID AND b.bettype = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
			INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
		WHERE b.matchid = @MatchID
			AND b.liveindicator = @IsLive
			AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
			AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
			AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
	END;
	
	IF @ViewMode = 2 --GET All Ticket - Danger Monitor
	BEGIN
		IF @IsGetDataFromOrigin = 1
		BEGIN
			INSERT INTO #tmpTrans (
					TransId
				,	CustId
				,	Hdp1
				,	Hdp2
				,	LiveHomeScore
				,	LiveAwayScore
				,	BetTeam
				,	CurrencyName
				,	CurrencyId
				,	BetType
				,	Hdp
				,	TicketStatus				
				,	SequenceId
				,	IsCashout)
			SELECT	b.TransId
				,	b.custid
				,	b.Hdp1
				,	b.Hdp2
				,	b.LiveHomeScore
				,	b.LiveAwayScore
				,	b.BetTeam
				,	e.currency
				,	e.ExchangeId
				,	b.bettype
				,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS Hdp
				,	b.statusID				
				,	SequenceId
				,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
			FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
				INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
				INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON b.custid = c.custid
				INNER JOIN #tmpSportBettype AS st WITH(NOLOCK) ON m.sporttype = st.SportTypeID AND b.bettype = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
				INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
			WHERE b.matchid = @MatchID
				AND b.liveindicator = @IsLive
				AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
				AND c.site NOT IN ('Nextbet','9wickets','9wsports')
				AND c.username NOT LIKE '%Cashout%'
				AND c.mrecommend NOT IN (27899314,11656504,12146012) 
				AND c.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
				AND c.srecommend NOT IN (41430709)
				AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
				AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
		END;
		
		IF @IsGetDataFrom14 = 1
		BEGIN
			INSERT INTO #tmpTrans (
					TransId
				,	CustId
				,	Hdp1
				,	Hdp2
				,	LiveHomeScore
				,	LiveAwayScore
				,	BetTeam
				,	CurrencyName
				,	CurrencyId
				,	BetType
				,	Hdp
				,	TicketStatus				
				,	TransDate)
			SELECT	b.TransId
				,	b.custid
				,	b.Hdp1
				,	b.Hdp2
				,	b.LiveHomeScore
				,	b.LiveAwayScore
				,	b.BetTeam
				,	e.currency
				,	e.ExchangeId
				,	b.bettype
				,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS Hdp
				,	b.statusID				
				,	b.TransDate
			FROM bodb02.dbo.bettrans14 AS b WITH(NOLOCK)
				INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.matchid = m.matchid
				INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON b.custid = c.custid
				INNER JOIN #tmpSportBettype AS st WITH(NOLOCK) ON m.sporttype = st.SportTypeID AND b.bettype = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
				INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
			WHERE b.matchid = @MatchID
				AND b.liveindicator = @IsLive
				AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
				AND c.site NOT IN ('Nextbet','9wickets','9wsports')
				AND c.username NOT LIKE '%Cashout%'
				AND c.mrecommend NOT IN (27899314,11656504,12146012) 
				AND c.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
				AND c.srecommend NOT IN (41430709)
				AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
				AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
		END;
	END;
	
	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET 	t.IsLicensee = 1
		,	t.Danger1 = ISNULL(c.danger,0)
		,	t.Danger2 = ISNULL(c.danger2,0)
		,	t.Danger3 = ISNULL(c.danger3,0)
		,	t.Danger4 = ISNULL(c.Danger4,0)
		,	t.Danger5 = ISNULL(c.Danger5,0)
		,	t.CustomerClass = ISNULL(c.CustomerClass,0)
	FROM #tmpTrans AS t
		INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON t.CustId = c.custid
		INNER JOIN bodb02.dbo.Dep_CustSuper AS cs WITH (NOLOCK) ON cs.custid = c.srecommend;

	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET 	t.IsLicensee = 0
		,	t.Danger1 = ISNULL(c.danger,0)
		,	t.Danger2 = ISNULL(c.danger2,0)
		,	t.Danger3 = ISNULL(c.danger3,0)
		,	t.Danger4 = ISNULL(c.Danger4,0)
		,	t.Danger5 = ISNULL(c.Danger5,0)
		,	t.CustomerClass = ISNULL(c.CustomerClass,0)
	FROM #tmpTrans AS t
		INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON t.CustId = c.custid
		INNER JOIN bodb02.dbo.CustProductStatus AS s WITH (NOLOCK) ON s.custid = c.custid
	WHERE t.IsLicensee IS NULL;
	
	-- CREATE INDEX IX_tmpTickets_IsLicensee ON #tmpTrans (IsLicensee, LiveHomeScore, LiveAwayScore, TicketStatus, CurrencyId, CurrencyName, Hdp, BetTeam, Danger1, Danger2, Danger3, Danger4, Danger5);
	CREATE NONCLUSTERED INDEX IX_tmpTrans_IsLicensee ON #tmpTrans (IsLicensee) INCLUDE (LiveHomeScore,LiveAwayScore,CustomerClass,Danger1,Danger2,Danger3,Danger4,Danger5,CurrencyId,CurrencyName,Hdp,Betteam,TicketStatus);
	
	/*Return Output*/
	SELECT @MaxSequenceId = (MAX(SequenceId) + 1) FROM #tmpTrans WITH(NOLOCK);
	SELECT @MaxTransDate = DATEADD(SECOND,1,MAX(TransDate)) FROM #tmpTrans WITH(NOLOCK);
	SELECT @TotalTicketAll = COUNT(1) FROM #tmpTrans;
	SELECT @TotalTicketLicensee = COUNT(1) FROM #tmpTrans WHERE IsLicensee = 1;
	SELECT @TotalTicketCredit = COUNT(1) FROM #tmpTrans  WHERE IsLicensee = 0;
	
	SELECT	DISTINCT 
			tmpTs.LiveHomeScore
		,	tmpTs.LiveAwayScore
		,	tmpTs.IsLicensee		
		,	tmpTs.CustomerClass
		,	tmpTs.Danger1
		,	tmpTs.Danger2
		,	tmpTs.Danger3
		,	tmpTs.Danger4
		,	tmpTs.Danger5
		,	tmpTs.CurrencyId
		,	tmpTs.CurrencyName
		,	tmpSt.SuspiciousReason
		,	tmpSt.SuspiciousGroupId
		,	tmpTs.Hdp
		,	tmpTs.Betteam
		,	tmpTs.TicketStatus
		,	tmpTs.IsCashout
	FROM #tmpTrans AS tmpTs
		LEFT JOIN #tmpSuspiciousTrans AS tmpSt ON tmpSt.TransId = tmpTs.TransId
	;
	
	DROP TABLE IF EXISTS #tmpSportBettype;
	DROP TABLE IF EXISTS #tmpTrans;
	DROP TABLE IF EXISTS #tmpSuspiciousTrans;
END;