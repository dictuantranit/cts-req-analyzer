/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CTS_TWGroupBetting_UpdateTotalTicket]
		@BatchSize				INT
	,	@LastSequenceId			BIGINT
	,	@LastSequenceId_New		BIGINT OUTPUT
AS
/*
	Created: 20220314@Harvey.Nguyen
	Task : Caculate Group betting ticket
	DB	 : DBCTS.WASAVerse

	Revisions:
		- 20220314@Harvey.Nguyen: Scan ticket 								[Redmine ID: #169671]
		- 20220614@Harvey.Nguyen: Add rowlock in updating 					[Redmine ID: #169671]
		- 20220711@Harvey.Nguyen: Change solution to scan on each ticket	[Redmine ID: #169671]
		- 20221122@Long.Luu:	  Exclude WC Leagues						[Redmine ID: #181229]
		- 20230626@Victoria.Le:	  Calculate TicketCount,RejectTicketCount,DesktopTicketCount,ParlayTicketCount
								  And only get sportttype < 100 			[Redmine ID: #189505]
		- 20231024@John.Ngo:	  [CTS] - Customer Classification - TW GB - Resolve Deadlock Problems [Redmine ID: #195866]
		- 20240130@Victoria.Le:	  Change tables - TWGB Migrate data from bodb02 to WASAVerse [Redmine ID: #191955]
		- 20240416@Victoria.Le:	  Exclude EC2024 [Redmine ID: #202847]
		- 20240405@Victoria.Le:	  Edit SP to improve performance [Redmine ID: #200842]
		- 20240405@Victoria.Le:	  GBTicketCount is being updated latency because schedule of service ScanTicket [Redmine ID: #200842]
		- 20240405@Victoria.Le:	  Not update GBTicketCount when table TWGroupBettingTicket is being deleted data by job [Redmine ID: #200842]

	Params Explaination:
		EXECUTE [dbo].[CTS_TWGroupBetting_UpdateTotalTicket] @LastScannedTime = '2022-03-10 03:39:12.230'
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 	@CleanTicketFlag_ParameterID			SMALLINT = 7
			,	@CleanTicketFlag_Value					SMALLINT
			,	@CleanTicketFlag_READY					SMALLINT = 0
			,	@CleanTicketFlag_WAITING				SMALLINT = -1
			,	@CleanTicketFlag_INPROGRESS				SMALLINT = 1
			,	@CleanTicketFlag_FINISH					SMALLINT = 2
			;
	
	DECLARE @TmpSpecialEventLeague AS TABLE (LeagueId INT PRIMARY KEY);
	DECLARE @TmpPlatformDesktop AS TABLE (BetFrom VARCHAR(5) PRIMARY KEY);

	IF OBJECT_ID('tempdb..#tmpScanningCust') IS NOT NULL
		DROP TABLE #tmpScanningCust;

	CREATE TABLE #tmpScanningCust(
			CustId			INT
		,	ScanDate		DATE
		,	GBTicketCount	INT DEFAULT 0
		,	IsInserted		BIT DEFAULT 0
	);
	
	IF OBJECT_ID('tempdb..#tmpTWGroupBettingTicket') IS NOT NULL
		DROP TABLE #tmpTWGroupBettingTicket;

	CREATE TABLE #tmpTWGroupBettingTicket(
			CustId			INT
		,	ScanDate		DATE
		,	GBTicketCount	INT
	);

	IF OBJECT_ID('tempdb..#Tmp_Trans') IS NOT NULL
		DROP TABLE #Tmp_Trans;

	CREATE TABLE #Tmp_Trans (
			ID 				INT IDENTITY(1,1)
		,	SequenceId		BIGINT
		,	Custid			INT
		,	Bettype			SMALLINT
		,	StatusID		TINYINT
		,	Matchid		    INT
		,	BetFrom		    NVARCHAR(4)
		,	ScanDate		DATE
	);
	
	IF OBJECT_ID('tempdb..#tmp_match') IS NOT NULL
		DROP TABLE #tmp_match;

	CREATE TABLE #tmp_match (
			MatchId		INT PRIMARY KEY
	);	

	INSERT INTO @TmpSpecialEventLeague(LeagueId)
	SELECT DISTINCT LeagueId
	FROM bodb02.dbo.league WITH(NOLOCK)
	WHERE ProgramID = '2024' AND DisplayMode = 3; -- EC
	-- WHERE ProgramID = '2022' AND DisplayMode = 2; -- WC
	
	INSERT INTO @TmpPlatformDesktop(BetFrom)
	SELECT b.BetFrom
	FROM DBWH.bodb_account.dbo.tbl_Betfrom AS b WITH (NOLOCK)
	WHERE b.platform2 = 'Desktop';

	INSERT INTO #Tmp_Trans (SequenceId,Custid,Matchid,Bettype,StatusID,BetFrom,ScanDate)
	SELECT TOP (@BatchSize) bt.sequenceid
		,	bt.custid
		,	bt.matchid
		,	bt.bettype
		,	bt.statusID
		,	bt.BetFrom
		,	bt.transdate
	FROM bodb02.dbo.bettrans AS bt WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Dep_CustSuper AS dCust WITH (NOLOCK) ON dCust.custid = bt.srecommend
	WHERE bt.sequenceid > @LastSequenceId
		AND bt.currency <> 20
		AND bt.bettype <> 10
	ORDER BY bt.sequenceid ASC;
	
	CREATE CLUSTERED INDEX #CIX_Tmp_Trans_CustId_ScanDate ON #Tmp_Trans (Custid,ScanDate);
	CREATE NONCLUSTERED INDEX #CIX_Tmp_Trans_Matchid ON #Tmp_Trans (Matchid);
	CREATE NONCLUSTERED INDEX #CIX_Tmp_Trans_SequenceId ON #Tmp_Trans (SequenceId);

	SELECT @LastSequenceId_New = MAX(SequenceId) FROM #Tmp_Trans;
	SET @LastSequenceId_New = ISNULL(@LastSequenceId_New,@LastSequenceId);

	WITH CTE_RN AS (
		SELECT 	ID
			,	ROW_NUMBER() OVER(PARTITION BY SequenceId ORDER BY SequenceId) AS RN
		FROM #Tmp_Trans
	)
	DELETE tmp_trans
	FROM #Tmp_Trans AS tmp_trans
		INNER JOIN CTE_RN AS c ON tmp_trans.ID = c.ID
	WHERE c.RN > 1;
	
	INSERT INTO #tmp_match (MatchId)
	SELECT DISTINCT tmp_trans.Matchid 
	FROM #Tmp_Trans AS tmp_trans
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON m.matchid = tmp_trans.MatchId
		LEFT JOIN @TmpSpecialEventLeague AS sl ON m.leagueid = sl.LeagueId
	WHERE tmp_trans.Matchid <> 29 
		AND m.Sporttype < 100
		AND sl.LeagueId IS NULL;
		
	DELETE tmp_trans
	FROM #Tmp_Trans AS tmp_trans
		LEFT JOIN #tmp_match AS tmp_match ON tmp_match.MatchId = tmp_trans.MatchId
	WHERE tmp_trans.Matchid <> 29 AND tmp_match.MatchId IS NULL;

	INSERT INTO #tmpScanningCust(CustId,ScanDate,IsInserted)
	SELECT DISTINCT 
			tmp_trans.Custid
		, 	tmp_trans.ScanDate
		, 	CASE WHEN tmp_trans.Custid IS NOT NULL AND gbc.CustId IS NULL THEN 1 ELSE 0 END AS 'IsInserted'
	FROM #Tmp_Trans AS tmp_trans
		LEFT JOIN dbo.TWGroupBettingCustomer AS gbc WITH(NOLOCK) ON gbc.CustId = tmp_trans.Custid AND gbc.ScanDate = tmp_trans.ScanDate;
	
	CREATE CLUSTERED INDEX #CIX_tmpScanningCust_CustId_ScanDate ON #tmpScanningCust (Custid,ScanDate);
	
	INSERT INTO dbo.TWGroupBettingCustomer(CustId,ScanDate,GBTicketCount,TicketCount,ParlayTicketCount,RejectTicketCount,DesktopTicketCount)
	SELECT	sc.CustId
		,	sc.ScanDate
		,	0
		,	0
		,	0
		,	0
		,	0 
	FROM #tmpScanningCust AS sc WITH(NOLOCK)
		LEFT JOIN dbo.TWGroupBettingCustomer AS gbc WITH(NOLOCK) ON sc.CustId = gbc.CustId AND sc.ScanDate = gbc.ScanDate
	WHERE gbc.CustId IS NULL AND sc.IsInserted = 1;
	
	SELECT 	@CleanTicketFlag_Value = s.ParameterValue
    FROM 	dbo.SystemParameter AS s WITH (NOLOCK)
    WHERE 	s.ParameterID = @CleanTicketFlag_ParameterID;
	
	INSERT INTO #tmpTWGroupBettingTicket (CustId,ScanDate,GBTicketCount)
	SELECT 	gbt.CustId
		,	gbt.TransDate
		,	COUNT(gbt.TransId)
	FROM dbo.TWGroupBettingTicket AS gbt WITH (NOLOCK)
	GROUP BY gbt.CustId,gbt.TransDate;
	
	UPDATE sc
	SET	sc.GBTicketCount = TEMP.GBTicketCount
	FROM #tmpScanningCust AS sc 
	INNER JOIN #tmpTWGroupBettingTicket AS TEMP ON TEMP.CustId = sc.CustId AND TEMP.ScanDate = sc.ScanDate;
	
	IF (@CleanTicketFlag_Value = @CleanTicketFlag_FINISH)
	BEGIN
		UPDATE 	gbc WITH(UPDLOCK, ROWLOCK)
		SET 	gbc.GBTicketCount = sc.GBTicketCount
			,	gbc.LastModifiedDate = GETDATE()
		FROM dbo.TWGroupBettingCustomer AS gbc
			INNER JOIN #tmpScanningCust AS sc ON sc.CustId = gbc.CustId AND sc.ScanDate = gbc.ScanDate
		WHERE gbc.GBTicketCount <> sc.GBTicketCount;
		
		UPDATE 	gbc WITH(UPDLOCK, ROWLOCK)
		SET 	gbc.GBTicketCount = gbt.GBTicketCount
			,	gbc.LastModifiedDate = GETDATE()
		FROM dbo.TWGroupBettingCustomer AS gbc
			INNER JOIN #tmpTWGroupBettingTicket AS gbt ON gbt.CustId = gbc.CustId AND gbt.ScanDate = gbc.ScanDate
			LEFT JOIN #tmpScanningCust AS sc ON sc.CustId = gbc.CustId AND sc.ScanDate = gbc.ScanDate
		WHERE sc.CustId IS NULL
			AND gbc.GBTicketCount <> gbt.GBTicketCount;
	
	END
	ELSE IF (@CleanTicketFlag_Value = @CleanTicketFlag_READY)
	BEGIN
		UPDATE 	gbc WITH(UPDLOCK, ROWLOCK)
		SET 	gbc.GBTicketCount = sc.GBTicketCount
			,	gbc.LastModifiedDate = GETDATE()
		FROM dbo.TWGroupBettingCustomer AS gbc
			INNER JOIN #tmpScanningCust AS sc ON sc.CustId = gbc.CustId AND sc.ScanDate = gbc.ScanDate
		WHERE gbc.GBTicketCount <> sc.GBTicketCount;
	
	END;

	;WITH cte_TicketCount AS (
		SELECT DISTINCT bt.Custid
			,	gbc.ScanDate
			,	COUNT(1) OVER (PARTITION BY bt.Custid,gbc.ScanDate) AS 'TicketCount'
			,	SUM(CASE WHEN bt.StatusID = 101 THEN 1 ELSE 0 END) OVER (PARTITION BY bt.Custid,gbc.ScanDate) AS 'RejectTicketCount'
			,	SUM(CASE WHEN b.BetFrom IS NOT NULL THEN 1 ELSE 0 END) OVER (PARTITION BY bt.Custid,gbc.ScanDate) AS 'DesktopTicketCount'		
			,	SUM(CASE WHEN bt.Bettype IN (29,38) THEN 1 ELSE 0 END) OVER (PARTITION BY bt.Custid,gbc.ScanDate) AS 'ParlayTicketCount'		
		FROM dbo.TWGroupBettingCustomer AS gbc WITH (NOLOCK)
			INNER JOIN #Tmp_Trans AS bt WITH (NOLOCK) ON gbc.CustId = bt.Custid	AND bt.ScanDate = gbc.ScanDate
			LEFT JOIN @TmpPlatformDesktop AS b ON b.BetFrom = bt.BetFrom
	)
	UPDATE gbc WITH(UPDLOCK, ROWLOCK)
	SET		gbc.TicketCount = CASE WHEN sc.IsInserted = 1 THEN ct.TicketCount ELSE (gbc.TicketCount + ct.TicketCount) END
		,	gbc.RejectTicketCount = CASE WHEN sc.IsInserted = 1 THEN ct.RejectTicketCount ELSE (gbc.RejectTicketCount + ct.RejectTicketCount) END 
		,	gbc.DesktopTicketCount = CASE WHEN sc.IsInserted = 1 THEN ct.DesktopTicketCount ELSE (gbc.DesktopTicketCount + ct.DesktopTicketCount) END 
		,	gbc.ParlayTicketCount = CASE WHEN sc.IsInserted = 1 THEN ct.ParlayTicketCount ELSE (gbc.ParlayTicketCount + ct.ParlayTicketCount) END 
		,	gbc.LastCountTotalTicketDate = GETDATE()
	FROM dbo.TWGroupBettingCustomer AS gbc
		INNER JOIN cte_TicketCount AS ct WITH (NOLOCK) ON gbc.CustId = ct.custid AND gbc.ScanDate = ct.ScanDate
		LEFT JOIN #tmpScanningCust AS sc ON sc.CustId = gbc.CustId AND sc.ScanDate = gbc.ScanDate;
		
	DROP TABLE IF EXISTS #tmpScanningCust;
	DROP TABLE IF EXISTS #Tmp_Trans;
	DROP TABLE IF EXISTS #tmp_match;
	DROP TABLE IF EXISTS #tmpTWGroupBettingTicket;

END;
