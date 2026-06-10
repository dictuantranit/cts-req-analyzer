/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CTS_TWGroupBetting_ScanTicket]
		@BatchSize				INT,
		@Step					INT,
		@LastSequenceId			BIGINT,
		@LastTransSec			BIGINT,
		@SkipTransCount			INT,

		@LastSequenceId_New		BIGINT	OUTPUT,
		@LastTransSec_New		BIGINT	OUTPUT,
		@SkipTransCount_New		INT		OUTPUT
AS
/*
	Created: 20220314@Harvey.Nguyen
	Task : Caculate TW Group betting %
	DB	 : DBCTS.WASAVerse

	Revisions:
		- 20220314@Harvey.Nguyen: Scan ticket								[Redmine ID: #169671]
		- 20220613@Harvey.Nguyen: Remove credit tickets						[Redmine ID: #169671]
		- 20220617@Harvey.Nguyen: Fix bug wrong inner join					[Redmine ID: #169671]
		- 20220711@Harvey.Nguyen: Change solution to scan on each ticket	[Redmine ID: #169671]
		- 20220801@Harvey.Nguyen: Enhance performance						[Redmine ID: #169671]
		- 20220831@Harvey.Nguyen: Update for Scale out DB Trans				[Redmine ID: #176472]
		- 20221122@Long.Luu:	  Exclude WC Leagues						[Redmine ID: #181229]
		- 20230417@Casey.Huynh: Change betfrom datatype	to NVARCHAR(4)		[Redmine ID: #187030]
		- 20230626@Victoria.Le: Add new columns	RulesType,IsRule1[tag by %RFM],IsRule2[tag by %CC],IsRule3[tag by %Betfrom]
																			[Redmine ID: #189505]
		- 20230719@Long.Luu:	  Addup Big Leagues for Soccer				[Redmine ID: #191399]
		- 20230811@Long.Luu:	  Addup Big Leagues for Soccer				[Redmine ID: #192614]
		- 20230829@Long.Luu:	  Addup Normal Account CC 4000				[Redmine ID: #192976]
		- 20231010@Long.Luu:	  Addup Big Leagues for Soccer				[Redmine ID: #1925163]
		- 20231030@Victoria.Le:	  New Group Betting - CC 2300 - Call SP from DW to send list fraud tickets [Redmine ID: #195060]
		- 20231123@Victoria.Le:	  Comment out the above code [Call SP from DW] and wait to update rule from BI TW team [Redmine ID: #195060]
		- 20231206@Victoria.Le:	  Remove - Comment out the above code [Call SP from DW] [Redmine ID: #197958]
		- 20240130@Victoria.Le:	  Change tables - TWGB Migrate data from bodb02 to WASAVerse [Redmine ID: #191955]
		- 20240416@Victoria.Le:	  Remove the statement which calling SP from DW - Exclude EC2024 - Adjustment rules [Redmine ID: #203848] [Redmine ID: #202847]
		- 20240405@Victoria.Le:	  Edit SP to improve performance [Redmine ID: #200842]
		- 20250303@John.Ngo:	  TWGB - Exclude TGXI and CC 2301, 2302, 2400, 2401, 2402 [Redmine ID: #217748]

	Params Explaination:
		EXECUTE [dbo].[CTS_TWGroupBetting_ScanTicket] '2022-02-15 23:10:15.983','2022-02-16 02:15:20.983',10900
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @GBTicketString VARCHAR(MAX)
		,	@CutOffDate		DATETIME = '2022-01-01';
	
	SELECT @BatchSize += @SkipTransCount;

	IF OBJECT_ID('tempdb..#TmpRawTicket') IS NOT NULL
        DROP TABLE #TmpRawTicket;

    CREATE TABLE #TmpRawTicket (
			GroupId					INT		IDENTITY(1,1)
		,	SequenceId				BIGINT	
		,	Transid					BIGINT
		,	TransdateSec			INT
		,	TransdateSecStep		INT
        ,	Custid					INT
        ,	Matchid					INT
        ,	Sporttype				SMALLINT
        ,	Bettype					SMALLINT
        ,	Betteam					NVARCHAR(10)
        ,	BetFrom					NVARCHAR(4)
        ,	Liveindicator			BIT
        ,	RFM						INT
        ,	CustomerClass			SMALLINT
        ,	IsBigLeague				BIT
    );

	IF OBJECT_ID('tempdb..#TmpSuspectTicket') IS NOT NULL
		DROP TABLE #TmpSuspectTicket;

	CREATE TABLE #TmpSuspectTicket (
			Transid				BIGINT
		,	TransdateSec		INT
		,	Custid				INT
		,	Matchid				INT
		,	Sporttype			SMALLINT
		,	Bettype				SMALLINT
		,	Betteam				NVARCHAR(10)
		,	BetFrom				NVARCHAR(4)
		,	Liveindicator		BIT
		,	RFM					INT
		,	CustomerClass		SMALLINT
		,	RuleId				INT
		,	IsBigLeague			BIT
		,	GroupId				INT
		,	TicketCount			INT
		,	IsViolateRFM		BIT
		,	IsViolateCC			BIT
		,	IsViolateBetFrom	BIT
		,	IsExists			BIT DEFAULT 0
	);

	DECLARE @TmpSpecialEventLeague AS TABLE (LeagueId INT PRIMARY KEY);
	DECLARE @TmpBigLeague AS TABLE (LeagueId INT PRIMARY KEY, Sporttype	TINYINT);
	---------------------------------------------------------------------------------
	INSERT INTO @TmpBigLeague (LeagueId,Sporttype)
	SELECT	*, 1 -- Soccer
	FROM (VALUES (3),(4),(5),(43),(1837),(356),(9540),(71697),(846),(27909),(57328),(99),(247),(130083),(126481)) AS X(a);

	INSERT INTO @TmpBigLeague (LeagueId,Sporttype)
	SELECT	*, 2 -- Basketball
	FROM (VALUES (56038),(56053),(95746),(86331),(56046),(56049),(78717),(7391),(44735),(11548),(63021),(44721),(44737),(11550),(81263),(52821),(88529),(93817),(102499),(82879),(82880),(82881),(101655),(82883),(82884),(82885),(82886),(82783),(82864),(82784),(101684),(82786),(82787),(82788),(82865),(82789),(82866),(82790),(101685),(82792),(82793),(82794),(82867),(82795),(82868),(82796),(101686),(82798),(82799),(82800),(82869),(82801),(82870),(82802),(101687),(82804),(82805),(82806),(82871),(82807),(82872),(82808),(101688),(82810),(82811),(82812),(82873),(82757),(96709),(56054),(56069),(99367),(99352),(56062),(99366),(56065),(56066),(56067),(56071),(99232),(99321),(99329),(99326),(99327),(99324),(99328),(99325),(56027),(24567),(75146),(48649),(93818),(102501),(7390),(7361),(7363),(44719),(95440),(104895),(95441),(104897),(93816),(102500),(99520),(99518),(82862),(82918),(55716),(83031),(83089),(83114),(82779),(82778),(101700),(101701),(64977),(95442),(104898),(95443),(104899),(99368),(99926),(82229),(92117),(100569),(92558),(99331),(99970),(99444),(100003),(100505),(99438),(100096),(99528),(95432),(103857),(95444),(104896),(95445),(104900),(99519)) AS X(a);

	INSERT INTO @TmpSpecialEventLeague(LeagueId)
	SELECT DISTINCT LeagueId
	FROM bodb02.dbo.league WITH(NOLOCK)
	WHERE ProgramID = '2024' AND DisplayMode = 3; -- EC
	-- WHERE ProgramID = '2022' AND DisplayMode = 2; -- WC

	INSERT INTO #TmpRawTicket (SequenceId, Transid, TransdateSec, TransdateSecStep, Custid, Matchid, Sporttype, Bettype, Betteam, BetFrom, Liveindicator, IsBigLeague, RFM, CustomerClass)
	SELECT	TOP(@BatchSize)
				b.sequenceid
			,	b.transid
			,	DATEDIFF(SECOND, @CutOffDate, b.transdate) AS TransdateSec
			,	(DATEDIFF(SECOND, @CutOffDate, b.transdate) - @Step) AS TransdateSecStep
			,	b.custid
			,	m.matchid
			,	m.sporttype
			,	b.bettype
			,	b.betteam
			,	b.betfrom
			,	b.liveindicator AS islive
			,	CASE 
					WHEN bl.LeagueId IS NOT NULL
						THEN 1
					ELSE 0
				END 'IsBigLeague'
			, 	pf.Tag AS RFM
			, 	cust.CustomerClass
	FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
		INNER JOIN bodb02.dbo.custinfo AS cust WITH (NOLOCK) ON  cust.custid = b.custid
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		LEFT JOIN bodb02.dbo.LicUserProfile AS pf WITH (NOLOCK) ON b.Custid = pf.CustId
		LEFT JOIN @TmpBigLeague AS bl ON bl.LeagueId = m.LeagueId
	WHERE b.sequenceid > @LastSequenceId
		AND b.refno = 100000000000
		AND b.currency <> 20
		AND b.bettype IN (1,3,7,8,609,610)
		AND m.sporttype IN (1,2)
		AND EXISTS (SELECT 1 FROM bodb02.dbo.Dep_CustSuper AS dCust WITH (NOLOCK) 
						WHERE dCust.custid = cust.srecommend 
						  AND dCust.site NOT IN ('TGXI','TGXICV','TGXICVSW','TGXISW'))
		AND 1 = (CASE WHEN m.LeagueId IN (SELECT LeagueId FROM @TmpSpecialEventLeague) THEN 0 ELSE 1 END)
	ORDER BY b.sequenceid ASC;

	CREATE CLUSTERED INDEX #CIX_TmpRawTicket_Transdate1 ON #TmpRawTicket (TransdateSec,TransdateSecStep);

	SET @SkipTransCount_New = 0;
	;WITH cte_stats AS (
		SELECT TOP(@Step) TransdateSec
			, COUNT(1) AS BetCount
			, MIN(SequenceId) AS MaxSequenceId
			, ROW_NUMBER() OVER (ORDER BY TransdateSec DESC) AS Rid
		FROM #TmpRawTicket
		GROUP BY TransdateSec
	)
	SELECT @LastSequenceId_New = MaxSequenceId
		, @LastTransSec_New = CASE WHEN Rid = 1 Then TransdateSec ELSE @LastTransSec_New END
		, @SkipTransCount_New += BetCount
	FROM cte_stats;

	WITH CTE_GetRuleID AS (	
		SELECT st.Transid,st.TransdateSec,st.Custid,st.Matchid,st.Sporttype,st.Bettype,st.Betteam,st.BetFrom,st.Liveindicator,st.RFM,st.CustomerClass,st.IsBigLeague,st.GroupId, gr.RuleId
		FROM 
		(	SELECT rawTrans.Transid,rawTrans.TransdateSec,rawTrans.Custid,rawTrans.Matchid,rawTrans.Sporttype,rawTrans.Bettype,rawTrans.Betteam,rawTrans.BetFrom,rawTrans.Liveindicator,rawTrans.RFM,rawTrans.CustomerClass,rawTrans.IsBigLeague,scannedTicket.GroupId
			FROM #TmpRawTicket AS scannedTicket WITH (NOLOCK)
				INNER JOIN #TmpRawTicket AS rawTrans WITH (NOLOCK) ON scannedTicket.TransdateSec > @LastTransSec AND 
					rawTrans.TransdateSec BETWEEN scannedTicket.TransdateSecStep AND scannedTicket.TransdateSec
		) AS st
			INNER JOIN dbo.TWGroupBettingGroupingRule AS gr WITH (NOLOCK) ON st.IsBigLeague = gr.IsBigLeague
																				AND st.Bettype = gr.Bettype
																				AND st.Liveindicator = gr.IsLive
																				AND st.Sporttype = gr.Sporttype
	),CTE_TicketCount AS (	
		SELECT r.RuleId,r.GroupId,r.Matchid,r.Bettype,r.Betteam,gbr.TicketCountLimit,COUNT(1) AS 'TicketCount'
		FROM CTE_GetRuleID AS r
			INNER JOIN dbo.TWGroupBettingRule AS gbr WITH (NOLOCK) ON r.RuleId = gbr.RuleId
		GROUP BY r.RuleId,r.GroupId,r.Matchid,r.Bettype,r.Betteam,gbr.TicketCountLimit
	)
	INSERT INTO #TmpSuspectTicket (Transid, TransdateSec, Custid, Matchid, Sporttype, Bettype, Betteam, BetFrom, Liveindicator, RFM, CustomerClass, IsBigLeague, GroupId, RuleId, TicketCount)
	SELECT DISTINCT cr.Transid,cr.TransdateSec,cr.Custid,cr.Matchid,cr.Sporttype,cr.Bettype,cr.Betteam,cr.BetFrom,cr.Liveindicator,cr.RFM,cr.CustomerClass,cr.IsBigLeague,cr.GroupId, cr.RuleId, ct.TicketCount
	FROM CTE_GetRuleID AS cr
		INNER JOIN CTE_TicketCount AS ct ON cr.RuleId = ct.RuleId AND cr.GroupId = ct.GroupId 
												AND cr.Matchid = ct.MatchId AND cr.Bettype = ct.Bettype	
												AND cr.Betteam = ct.Betteam 
		INNER JOIN dbo.TWGroupBettingRule AS gbr WITH (NOLOCK) ON cr.RuleId = gbr.RuleId
	WHERE ct.TicketCount > ct.TicketCountLimit;

	;WITH tempTable_BetFrom AS (
		SELECT tfs.RuleId,tfs.GroupId,tfs.MatchId,tfs.Bettype,tfs.Betteam
			,	CASE WHEN (tfs.RuleId >= 9 AND tfs.RuleId <= 17 AND COUNT(tfs.Transid) * 100 / tfs.TicketCount >= gbr.BetFromLimitPercent)
						OR (tfs.RuleId >= 1 AND tfs.RuleId <= 8 AND COUNT(tfs.Transid) * 100 / tfs.TicketCount > gbr.BetFromLimitPercent)
							THEN 1
					 ELSE 0 END AS 'IsViolateBetFrom'
		FROM #TmpSuspectTicket AS tfs
				INNER JOIN dbo.TWGroupBettingRule AS gbr WITH (NOLOCK) ON tfs.RuleId = gbr.RuleId
		WHERE tfs.BetFrom IN ('x','z')
		GROUP BY tfs.RuleId,tfs.GroupId,tfs.MatchId,tfs.Bettype,tfs.Betteam,tfs.TicketCount,gbr.BetFromLimitPercent
	), tempTable_RFM AS (
		SELECT	tfs.RuleId,tfs.GroupId,tfs.MatchId,tfs.Bettype,tfs.Betteam
			,	CASE WHEN (tfs.RuleId IN (1,2,4,13,15,17) AND COUNT(tfs.Transid) * 100 / tfs.TicketCount >= gbr.RFMLimitPercent)
						OR (tfs.RuleId NOT IN (1,2,4,13,15,17) AND COUNT(tfs.Transid) * 100 / tfs.TicketCount > gbr.RFMLimitPercent)
							THEN 1
					 ELSE 0 END AS 'IsViolateRFM'
		FROM #TmpSuspectTicket AS tfs
			INNER JOIN dbo.TWGroupBettingRule AS gbr WITH (NOLOCK) ON tfs.RuleId = gbr.RuleId
		WHERE tfs.RFM > gbr.RFMLimitValue
		GROUP BY tfs.RuleId,tfs.GroupId,tfs.MatchId,tfs.Bettype,tfs.Betteam,tfs.TicketCount,gbr.RFMLimitPercent
	), tempTable_CC AS (
		SELECT	tfs.RuleId,tfs.GroupId,tfs.MatchId,tfs.Bettype,tfs.Betteam
			,	CASE WHEN (tfs.RuleId >= 12 AND tfs.RuleId <= 17 AND COUNT(tfs.Transid) * 100 / tfs.TicketCount >= gbr.CustClassLimitPercent)
						OR (tfs.RuleId >= 1 AND tfs.RuleId <= 11 AND COUNT(tfs.Transid) * 100 / tfs.TicketCount > gbr.CustClassLimitPercent)
							THEN 1
					 ELSE 0 END AS 'IsViolateCC'
		FROM #TmpSuspectTicket AS tfs
			INNER JOIN dbo.TWGroupBettingRule AS gbr WITH (NOLOCK) ON tfs.RuleId = gbr.RuleId
		WHERE tfs.CustomerClass NOT IN (201,2101,2201,2001,202,2102,2202,2002,4000,2301,2302,2400,2401,2402)
		GROUP BY tfs.RuleId,tfs.GroupId,tfs.MatchId,tfs.Bettype,tfs.Betteam,tfs.TicketCount,gbr.CustClassLimitPercent
	)
	UPDATE tfs
	SET 	tfs.IsViolateBetFrom 	= CASE WHEN bf.RuleId IS NOT NULL THEN bf.IsViolateBetFrom ELSE tfs.IsViolateRFM END
		,	tfs.IsViolateRFM 		= CASE WHEN rfm.RuleId IS NOT NULL THEN rfm.IsViolateRFM ELSE tfs.IsViolateRFM END
		,	tfs.IsViolateCC 		= CASE WHEN cc.RuleId IS NOT NULL THEN cc.IsViolateCC ELSE tfs.IsViolateCC END
		,	tfs.IsExists 			= CASE WHEN gbt.Transid IS NOT NULL THEN 1 ELSE 0 END
	FROM #TmpSuspectTicket AS tfs WITH(UPDLOCK, ROWLOCK)
		LEFT JOIN tempTable_BetFrom AS bf ON bf.RuleId = tfs.RuleId AND bf.Betteam = tfs.Betteam AND bf.GroupId = tfs.GroupId AND bf.MatchId = tfs.MatchId AND bf.Bettype = tfs.Bettype
		LEFT JOIN tempTable_RFM AS rfm ON rfm.RuleId = tfs.RuleId AND rfm.GroupId = tfs.GroupId AND rfm.MatchId = tfs.MatchId AND rfm.Bettype = tfs.Bettype AND rfm.Betteam = tfs.Betteam
		LEFT JOIN tempTable_CC AS cc ON cc.RuleId = tfs.RuleId AND cc.GroupId = tfs.GroupId AND cc.MatchId = tfs.MatchId AND cc.Bettype = tfs.Bettype AND cc.Betteam = tfs.Betteam
		LEFT JOIN dbo.TWGroupBettingTicket AS gbt ON gbt.Transid = tfs.Transid;
								
	WITH CTE_1 AS
	(
		SELECT 	tfs.Custid AS 'CustId'
			,	tfs.Transid AS 'TransId'
			,	CONVERT(DATE, DATEADD(SECOND, tfs.TransdateSec, @CutOffDate)) AS 'TransDate'
			,	RuleId AS 'RuleId'
			,	IsViolateRFM AS 'IsViolateRFM'
			,	IsViolateCC AS 'IsViolateCC'
			,	IsViolateBetFrom AS 'IsViolateBetFrom'
			,	(ISNULL(CONVERT(SMALLINT,IsViolateRFM),0) + ISNULL(CONVERT(SMALLINT,IsViolateCC),0) + ISNULL(CONVERT(SMALLINT,IsViolateBetFrom),0)) AS 'SumIsViolate'
		FROM #TmpSuspectTicket AS tfs WITH (NOLOCK)
		WHERE tfs.IsExists = 0 AND (tfs.IsViolateBetFrom = 1 OR tfs.IsViolateRFM = 1 OR tfs.IsViolateCC = 1)
				
	), CTE_2 AS
	(
		SELECT 	CustId,TransId,TransDate,RuleId,IsViolateRFM,IsViolateCC,IsViolateBetFrom
			,	ROW_NUMBER() OVER (PARTITION BY CustId,TransId,TransDate,RuleId ORDER BY SumIsViolate DESC) AS RN
		FROM CTE_1
	)
	SELECT @GBTicketString = (	SELECT CustId,TransId,TransDate,RuleId,IsViolateRFM,IsViolateCC,IsViolateBetFrom
								FROM CTE_2
								WHERE RN = 1
								FOR JSON PATH);

	EXEC dbo.CTS_TWGroupBetting_SyncDataGroupBettingTicket @GBTicketString, @LastSequenceId_New;

	DROP TABLE IF EXISTS #TmpRawTicket;
	DROP TABLE IF EXISTS #TmpSuspectTicket;
END;