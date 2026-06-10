/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
/****** Object:  StoredProcedure [dbo].[CTS_BySportNormalClassification_NormalPool_Classify] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_BySportNormalClassification_NormalPool_Classify]
	@CustomersXML	XML
AS
/*
	Created: 20230630@Jonas.Huynh
	Task : Insert customers to normal pool for classification bySport
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20230630@Jonas.Huynh: Created [Redmine ID: #189875]
		- 20230726@Jonas.Huynh: Saba Classification [Redmine ID: #185320]
		- 20240318@Jonas.Huynh: Renovate Non-Sport Rules [Redmine ID: #201359]
		- 20240320@Thomas.Nguyen: Classify customers without performance that were removed special CC from manual action [Redmine ID: #201360]
		- 20240426@Jonas.Huynh: Exclude New Parlay SportGroup [Redmine ID: #203600]
		- 20240618@Jonas.Nguyen: Renovate CC - Phase 2 [Redmine ID: #205317]
		- 20250515@Long.Luu: 	Add new 3 special licensees "Winbox, SM88, and SL88SW" [Redmine ID: #226846]

	Param's Explanation:
		@CustomersXML	 : This parameter is used to classify customer perf which bases on currentCategory

    Script:
        EXEC bodb_VR2Model.dbo.CTS_BySportNormalClassification_NormalPool_Classify
			@CustomersXML = N'<Root>
								<r CustId="5002646" SportGroup="2" CategoryId="201" IsCheckBetCount= "0" IsProbationLastDay="0"/>
								<r CustId="5022391" SportGroup="2" CategoryId="0" IsCheckBetCount= "1" IsProbationLastDay="0"/>
								<r CustId="1275" SportGroup="2" CategoryId="205" IsCheckBetCount= "1" IsProbationLastDay="1"/>
								<r CustId="1280" SportGroup="2" CategoryId="202" IsCheckBetCount= "1" IsProbationLastDay="1"/>
							</Root>';
*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE	@CATEGORY_NULL				INT = 0,
			@CATEGORY_NEW				INT = 40100,
			@CATEGORY_NORMAL			INT = 40300,
			@CATEGORY_GOOD				INT = 40200,
			@CATEGORY_PROBATION			INT = 40400,
			@CATEGORY_SMART				INT = 40500,
			@CATEGORY_RISKY				INT = 40600,
			@CATEGORY_CCRESET			INT = -1;

	DECLARE @SPORT_SOCCER				SMALLINT = 1,
			@SPORT_BASKETBALL			SMALLINT = 2,
			@SPORT_ESPORT				SMALLINT = 43,
			@SPORT_OTHERSPORT			SMALLINT = 99,
			@SPORT_PARLAY				SMALLINT = 107,
			@SPORT_NONSPORT				SMALLINT = 229;

	DECLARE @CurrentDateTime			DATETIME = GETDATE();
	DECLARE @CurrentDate				DATE	 = GETDATE();
	DECLARE	@ToDate						DATE	 = GETDATE();
	DECLARE @From30Date					DATE	 = DATEADD(DAY, -29, @ToDate);
	DECLARE @Priority_ManualAction		TINYINT = 10;  
	DECLARE @FunctionId_ManualAction	TINYINT = 5;  
	DECLARE @ListCustIds				VARCHAR(MAX);

	IF OBJECT_ID('tempdb..#tmpCustomers') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustomers;
	END

	CREATE TABLE #tmpCustomers(
		CustId			       INT,
		SportGroup			   SMALLINT,
		CurrentCategoryId      INT		NOT NULL,
		IsCheckBetCount		   BIT	    NOT NULL DEFAULT 0,
		IsProbationLastDay	   BIT		NOT NULL DEFAULT 0,
		IsPlaceBetWithin30Days BIT		NOT NULL DEFAULT 0,
		PRIMARY KEY (CustId, SportGroup)
	);

	CREATE NONCLUSTERED INDEX IX_tmpCustomers_IsCheckBetCount_CurrentCategory ON #tmpCustomers(
		IsCheckBetCount DESC,
		CurrentCategoryId
	);

	IF	OBJECT_ID('tempdb..#tmpRawData') IS NOT NULL
		DROP TABLE	#tmpRawData;

	CREATE TABLE #tmpRawData(
		CustId				 INT			NOT NULL,
		SportGroup			 SMALLINT		NOT NULL,
		TurnoverRM			 DECIMAL(19, 4)	NOT NULL,
		WinlossRM			 DECIMAL(19, 4)	NOT NULL,
		TurnoverORG			 DECIMAL(19, 4)	NOT NULL,
		WinlossORG			 DECIMAL(19, 4)	NOT NULL,
		BetCount			 BIGINT			NOT NULL,
		ActiveDaysCustID	 INT			NOT NULL,
        ActiveDaysSportGroup INT			NOT NULL,
        WindaysCustID		 INT			NOT NULL,
        WinDaysSportGroup	 INT			NOT NULL,
		ProcessedTime        DATETIME       NOT NULL
	);

	CREATE CLUSTERED INDEX CIX_tmpRawData_CustId ON #tmpRawData(CustId, SportGroup);

	CREATE NONCLUSTERED INDEX IX_tmpRawData_BetCount ON #tmpRawData(
		BetCount
	);

	IF	OBJECT_ID('tempdb..#tmpCustomerAccummulatedInfo') IS NOT NULL
		DROP TABLE	#tmpCustomerAccummulatedInfo;

	CREATE TABLE #tmpCustomerAccummulatedInfo(
		CustId				   INT			  NOT NULL,
		SportGroup			   SMALLINT		  NOT NULL,
		CurrentCategoryId	   INT			  NOT NULL DEFAULT 0,
		NewCategoryId		   INT			  NULL,
		IsProbationLastDay	   BIT			  NOT NULL DEFAULT 0,
		IsCheckBetCount		   BIT			  NOT NULL DEFAULT 0,
		IsSpecialSite		   BIT			  DEFAULT 0,
		IsDeposit			   BIT			  NOT NULL DEFAULT 0,
		SRecommend			   INT,
		TurnoverRM			   DECIMAL(19, 4) NOT NULL,
		WinlossRM			   DECIMAL(19, 4) NOT NULL,
		Margin				   DECIMAL(19, 4) NOT NULL,
		BetCount			   BIGINT		  NOT NULL,
		ActiveDays			   INT			  NOT NULL,
		WinDaysRate			   DECIMAL(5,2)	  NULL,
		PerformanceTime        DATETIME       NOT NULL
		PRIMARY KEY (CustId, SportGroup)
	);

	CREATE NONCLUSTERED INDEX IX_tmpCustomerAccummulatedInfo_CurrentCategoryId ON #tmpCustomerAccummulatedInfo(
		CurrentCategoryId
	);

	IF	OBJECT_ID('tempdb..#tmpBetCount') IS NOT NULL
		DROP TABLE	#tmpBetCount;

	CREATE TABLE #tmpBetCount(
		CustId		INT,
		SportGroup	SMALLINT,
		CategoryId	INT		  NOT NULL,
		BetCount	BIGINT	  NULL,
		PRIMARY KEY (CustId, SportGroup)
	);

	CREATE NONCLUSTERED INDEX IX_tmpBetCount_CategoryId ON #tmpBetCount(
		CategoryId
	);

	
	IF	OBJECT_ID('tempdb..#tmpRelatedCustInfo') IS NOT NULL
	DROP TABLE	#tmpRelatedCustInfo;

	CREATE TABLE #tmpRelatedCustInfo(
		CustId			INT PRIMARY KEY,
		SiteName		VARCHAR(10),
		IsDeposit		BIT NOT NULL DEFAULT 0,
		SRecommend		INT
	);

	-- #1: Get list customers
	INSERT INTO #tmpCustomers(CustId, SportGroup, CurrentCategoryId, IsCheckBetCount, IsProbationLastDay)
	SELECT	T.C.value('./@CustId', 'INT')				AS CustId
		,	T.C.value('./@SportGroup', 'SMALLINT')		AS SportGroup
		,	T.C.value('./@CategoryId', 'INT')			AS CurrentCategoryId
		,	T.C.value('./@IsCheckBetCount', 'BIT')		AS IsCheckBetCount
		,	T.C.value('./@IsProbationLastDay', 'BIT')	AS IsProbationLastDay
	FROM @CustomersXML.nodes('//r') AS T(C)
	OPTION (OPTIMIZE FOR (@CustomersXML = NULL));
	
	-- #2: Remove realtime classification with category not in (null, new, good, normal)
	DELETE r WITH(ROWLOCK)
	FROM #tmpCustomers AS r
	WHERE r.IsCheckBetCount = 1 
		AND r.CurrentCategoryId NOT IN (@CATEGORY_NULL, @CATEGORY_NEW, @CATEGORY_NORMAL, @CATEGORY_GOOD);

	-- #3: Get accummulated performance
	SELECT @ListCustIds = STUFF(( SELECT DISTINCT ',', CONVERT(VARCHAR(15), CustId) 
								  FROM #tmpCustomers WITH (NOLOCK)
								  FOR XML PATH('')), 1, 1, '');

	INSERT INTO #tmpRawData(CustId, SportGroup, TurnoverRM, WinlossRM, TurnoverORG, WinlossORG, BetCount, ActiveDaysCustID, ActiveDaysSportGroup, WindaysCustID, WinDaysSportGroup, ProcessedTime)
	EXEC bodb_dwrs.dbo.Acc_Rpt_CTS_GetCustAccumulatedInfo @ListCustID = @ListCustIds, @isResetBalance = 0;

	-- #4: Remove SportType with no perf (void/reject/exclude/... tickets)
	DELETE r WITH(ROWLOCK)
	FROM #tmpRawData AS r
	WHERE r.BetCount = 0 
		OR r.SportGroup = @SPORT_PARLAY;
	
	-- #5: Calculate accumulated customer performance data
	INSERT INTO #tmpCustomerAccummulatedInfo(CustId, SportGroup, TurnoverRM, WinlossRM, Margin, BetCount, ActiveDays, WinDaysRate, PerformanceTime, CurrentCategoryId, IsCheckBetCount, IsProbationLastDay)
	SELECT a.CustId,
		   a.SportGroup,
		   a.TurnoverRM,
		   a.WinlossRM,
		   CASE WHEN a.TurnoverRM = 0 THEN 0 ELSE a.WinlossRM / a.TurnoverRM * 100 END,
		   a.BetCount,
		   a.ActiveDaysSportGroup,
		   CASE WHEN  a.ActiveDaysSportGroup = 0 THEN 0 ELSE ((a.WinDaysSportGroup * 1.0) / a.ActiveDaysSportGroup) * 100 END,
		   a.ProcessedTime,
		   c.CurrentCategoryId,
		   c.IsCheckBetCount,
		   c.IsProbationLastDay				
	FROM #tmpRawData AS a
		INNER JOIN #tmpCustomers AS c ON c.CustId = a.CustId AND c.SportGroup = a.SportGroup;

	-- #6: Mapping customer info
	UPDATE a WITH(ROWLOCK, UPDLOCK)
	SET a.IsPlaceBetWithin30Days = 1
	FROM #tmpCustomers AS a
		INNER JOIN dbo.CustomerClassification_BySport_LatestActiveDay AS c WITH(NOLOCK) ON a.CustId = c.CustId AND a.SportGroup = c.SportGroup
	WHERE c.LastTransDate >= @From30Date;

	-- #7: Remove accounts with settle bet count has not reach the schedule (FOR REALTIME ONLY)
	---- less than 100 settle tickets compared to last scan for Good Member
	---- less than 20 settle tickets compared to last scan for Normal Member
	DELETE a WITH (ROWLOCK)
	FROM #tmpCustomerAccummulatedInfo AS a
		INNER JOIN dbo.CustomerClassification_BySport_BetCount AS b WITH(NOLOCK) ON a.CustId = b.CustId AND a.SportGroup = b.SportId
	WHERE a.IsCheckBetCount = 1 
		  AND ((a.CurrentCategoryId = @CATEGORY_GOOD AND a.BetCount - b.BetCount < 100)
		  OR (a.CurrentCategoryId = @CATEGORY_NORMAL AND a.BetCount - b.BetCount < 20));
	
	-- #8: Insert scanned cust daily
	UPDATE b WITH(ROWLOCK, UPDLOCK)
	SET	b.CreatedDate = @CurrentDate
	FROM #tmpCustomerAccummulatedInfo AS a
		INNER JOIN dbo.CustomerClassification_BySport_ScannedDailyCust AS b ON b.CustId = a.CustId AND b.SportGroup = a.SportGroup;

	INSERT INTO dbo.CustomerClassification_BySport_ScannedDailyCust(CustId, SportGroup, CreatedDate)
	SELECT a.CustId, a.SportGroup, @CurrentDate
	FROM #tmpCustomerAccummulatedInfo AS a
	WHERE NOT EXISTS (SELECT 1 FROM dbo.CustomerClassification_BySport_ScannedDailyCust AS b WITH(NOLOCK) WHERE b.CustId = a.CustId AND b.SportGroup = a.SportGroup);

	-- #9: Get relevant customer info
	INSERT INTO #tmpRelatedCustInfo (CustId)
	SELECT DISTINCT CustId
	FROM #tmpCustomerAccummulatedInfo;
	
	UPDATE a WITH(ROWLOCK, UPDLOCK)
	SET	   a.SRecommend = c.srecommend,
		   a.SiteName = c.Site
	FROM #tmpRelatedCustInfo AS a
		INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON c.CustId = a.CustId;

	UPDATE a WITH(ROWLOCK, UPDLOCK)
	SET a.IsDeposit = 1
	FROM #tmpRelatedCustInfo AS a
		INNER JOIN bodb02.dbo.Dep_CustSuper AS c WITH(NOLOCK) ON c.custid = a.SRecommend;

	UPDATE a WITH(ROWLOCK, UPDLOCK)
	SET a.IsDeposit = c.IsDeposit,
		a.IsSpecialSite = CASE
							WHEN a.SportGroup = @SPORT_NONSPORT THEN NULL
							WHEN a.SportGroup = @SPORT_ESPORT AND c.SiteName IN ('haifa','manbetx','HC6YAYOU','US8YAYOU','BPLE','Okada','Winbox', 'SM88', 'SL88SW','WINHX1') THEN 1
							WHEN a.SportGroup <> @SPORT_ESPORT AND c.SiteName IN ('haifa','manbetx','HC6YAYOU','US8YAYOU','BPLE','Okada','Winbox', 'SM88', 'SL88SW') THEN 1
							ELSE 0	
						  END	
	FROM #tmpCustomerAccummulatedInfo AS a
		INNER JOIN #tmpRelatedCustInfo AS c WITH(NOLOCK) ON c.custid = a.CustId;

	-- #10: Classify customer without performance 
	INSERT INTO dbo.CustomerClassification_BySport(CustId, SportId, CategoryId, CurrentCategoryId, CreatedDate, CreatedTime, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime)
	SELECT t.CustId
		,  t.SportGroup
		,  @CATEGORY_NEW
		,  @CATEGORY_NULL
		,  @ToDate
		,  @CurrentDateTime
		,  NULL
		,  NULL
		,  NULL
		,  NULL
		,  @CurrentDateTime
	FROM #tmpCustomers AS t
	WHERE t.CurrentCategoryId = @CATEGORY_NULL AND t.IsPlaceBetWithin30Days = 1
		AND NOT EXISTS (SELECT 1 FROM #tmpCustomerAccummulatedInfo AS c WHERE c.CustId = t.CustId AND c.SportGroup = t.SportGroup);

	INSERT INTO dbo.CustomerClassification_BySport(CustId, SportId, CategoryId, CurrentCategoryId, CreatedDate, CreatedTime, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime)
	SELECT t.CustId
		,  t.SportGroup
		,  @CATEGORY_CCRESET
		,  t.CurrentCategoryId
		,  @ToDate
		,  @CurrentDateTime
		,  NULL
		,  NULL
		,  NULL
		,  NULL
		,  @CurrentDateTime
	FROM #tmpCustomers AS t
	WHERE t.IsPlaceBetWithin30Days = 0
		AND EXISTS (SELECT TOP 1 1   
					FROM CustomerClassification_BySport_NormalPool cb WITH(NOLOCK)   
					WHERE cb.CustId = t.CustId AND cb.SportGroup = t.SportGroup AND cb.FunctionId = @FunctionId_ManualAction AND cb.[Priority] = @Priority_ManualAction)
		AND NOT EXISTS (SELECT 1 FROM #tmpCustomerAccummulatedInfo AS c WHERE c.CustId = t.CustId AND c.SportGroup = t.SportGroup);

	-- #11: Classify classification by general rule
	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET t.NewCategoryId = b.CategoryId
	FROM (
			SELECT  a.CustId
				,	a.SportGroup
				,   r.CategoryId
				,	ROW_NUMBER() OVER(PARTITION BY a.CustId, a.SportGroup ORDER BY r.Prioity ASC) AS RowNum
			 FROM #tmpCustomerAccummulatedInfo AS a WITH(NOLOCK) 
				INNER JOIN dbo.CustomerClassification_BySport_Rule AS r WITH(NOLOCK) ON a.SportGroup = r.SportId 
			 WHERE	-- New
					   (r.RuleGroupId = 1 AND a.CurrentCategoryId = r.CurrentCategory AND a.BetCount < r.BetCount)												
					OR (r.RuleGroupId = 2 AND a.IsSpecialSite = r.IsSpecialSite AND a.BetCount >= r.BetCount AND a.Margin < r.Margin AND a.WinlossRM > r.WinlossRM)	
					-- Good	
					OR (r.RuleGroupId = 100 AND a.BetCount > r.BetCount AND a.Margin < r.Margin AND a.TurnoverRM > r.TurnoverRM AND a.ActiveDays >= r.ActiveDays)							
					OR (r.RuleGroupId = 101 AND a.BetCount >= r.BetCount AND a.Margin <= r.Margin  AND a.ActiveDays >= r.ActiveDays)							
					OR (r.RuleGroupId = 102 AND a.BetCount >= r.BetCount AND a.WinlossRM <= r.WinlossRM AND a.ActiveDays >= r.ActiveDays)	
					OR (r.RuleGroupId = 103 AND a.BetCount >= r.BetCount AND a.Margin < r.Margin)	
					-- Normal
					OR (r.RuleGroupId = 200 AND (a.IsSpecialSite IS NULL OR a.IsSpecialSite = r.IsSpecialSite) AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.Margin < r.Margin2)						
					OR (r.RuleGroupId = 201 AND (a.IsSpecialSite IS NULL OR a.IsSpecialSite = r.IsSpecialSite) AND a.BetCount >= r.BetCount AND a.Margin < r.Margin AND NOT (a.BetCount > r.BetCount2 AND a.TurnoverRM > r.TurnoverRM AND a.ActiveDays >= r.ActiveDays))
					OR (r.RuleGroupId = 202 AND a.IsSpecialSite = r.IsSpecialSite AND a.BetCount >= r.BetCount AND a.Margin < r.Margin AND a.WinlossRM <= r.WinlossRM)											
					OR (r.RuleGroupId = 203 AND a.IsDeposit = r.IsDeposit AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.WinlossRM < r.WinlossRM)												
					OR (r.RuleGroupId = 204 AND a.BetCount >= r.BetCount AND NOT (a.BetCount >= r.BetCount2 AND a.Margin <= r.Margin AND a.ActiveDays >= r.ActiveDays))														
					OR (r.RuleGroupId = 205 AND a.BetCount >= r.BetCount AND NOT (a.BetCount >= r.BetCount2 AND a.WinlossRM <= r.WinlossRM AND a.ActiveDays >= r.ActiveDays))		
					OR (r.RuleGroupId = 206 AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.WinlossRM < r.WinlossRM)
					-- Probation
					OR (r.RuleGroupId = 300 AND a.CurrentCategoryId = r.CurrentCategory AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.Margin <= r.Margin2 AND a.WinlossRM <= r.WinlossRM)			
					OR (r.RuleGroupId = 301 AND a.CurrentCategoryId = r.CurrentCategory AND a.BetCount >= r.BetCount AND a.WinlossRM < r.WinlossRM AND a.Margin >= r.Margin AND a.Margin <= r.Margin2)			
					OR (r.RuleGroupId = 302 AND a.CurrentCategoryId = r.CurrentCategory AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.Margin <= r.Margin2 AND a.WinlossRM <= r.WinlossRM)			
					OR (r.RuleGroupId = 303 AND a.CurrentCategoryId = r.CurrentCategory AND a.BetCount >= r.BetCount AND a.WinlossRM < r.WinlossRM AND a.Margin > r.Margin)										
					OR (r.RuleGroupId = 304 AND a.CurrentCategoryId = r.CurrentCategory AND a.IsDeposit = r.IsDeposit AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin)										
					OR (r.RuleGroupId = 305 AND a.CurrentCategoryId = r.CurrentCategory AND a.IsDeposit = r.IsDeposit AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.WinlossRM >= r.WinlossRM)	
					OR (r.RuleGroupId = 306 AND a.CurrentCategoryId = r.CurrentCategory AND a.BetCount > r.BetCount AND a.Margin > r.Margin)					
					OR (r.RuleGroupId = 307 AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin)
					OR (r.RuleGroupId = 308 AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.WinlossRM >= r.WinlossRM)					
					-- Smart
					OR (r.RuleGroupId = 400 AND a.CurrentCategoryId = r.CurrentCategory AND (r.IsProbationLastDay IS NULL OR a.IsProbationLastDay = r.IsProbationLastDay) AND a.Margin >= r.Margin AND a.Margin <= r.Margin2 AND a.BetCount >= r.BetCount AND a.WinlossRM > r.WinlossRM)
					OR (r.RuleGroupId = 402 AND a.CurrentCategoryId = r.CurrentCategory AND (r.IsProbationLastDay IS NULL OR a.IsProbationLastDay = r.IsProbationLastDay) AND a.BetCount >= r.BetCount AND a.WinlossRM >= r.WinlossRM AND a.Margin >= r.Margin AND a.Margin <= r.Margin2)
					OR (r.RuleGroupId = 403 AND a.CurrentCategoryId = r.CurrentCategory AND (r.IsProbationLastDay IS NULL OR a.IsProbationLastDay = r.IsProbationLastDay) AND a.BetCount >= r.BetCount AND a.Margin > r.Margin AND a.WinlossRM > r.WinlossRM AND a.WinlossRM <= r.WinlossRM2)
					OR (r.RuleGroupId = 404 AND a.CurrentCategoryId = r.CurrentCategory AND a.Margin > r.Margin AND a.BetCount >= r.BetCount AND a.WinlossRM > r.WinlossRM AND a.WinlossRM <= r.WinlossRM2)
					OR (r.RuleGroupId = 406 AND a.CurrentCategoryId = r.CurrentCategory AND a.Margin > r.Margin AND a.WinlossRM > r.WinlossRM AND a.WinlossRM <= r.WinlossRM2)
					OR (r.RuleGroupId = 407 AND a.CurrentCategoryId = r.CurrentCategory AND a.Margin >= r.Margin AND a.Margin <= r.Margin2 AND a.WinlossRM > r.WinlossRM)		
					OR (r.RuleGroupId = 408 AND a.CurrentCategoryId = r.CurrentCategory AND (r.IsProbationLastDay IS NULL OR a.IsProbationLastDay = r.IsProbationLastDay) AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.WinlossRM >= r.WinlossRM AND a.WinDaysRate >= r.WinDaysRate)
					-- Risky
					OR (r.RuleGroupId = 500 AND a.CurrentCategoryId = r.CurrentCategory AND (r.IsProbationLastDay IS NULL OR a.IsProbationLastDay = r.IsProbationLastDay) AND a.Margin > r.Margin AND a.BetCount >= r.BetCount AND a.WinlossRM > r.WinlossRM)
					OR (r.RuleGroupId = 502 AND a.CurrentCategoryId = r.CurrentCategory AND (r.IsProbationLastDay IS NULL OR a.IsProbationLastDay = r.IsProbationLastDay) AND a.BetCount >= r.BetCount AND a.WinlossRM >= r.WinlossRM AND a.Margin > r.Margin)
					OR (r.RuleGroupId = 503 AND a.CurrentCategoryId = r.CurrentCategory AND a.Margin > r.Margin AND a.WinlossRM > r.WinlossRM)
					OR (r.RuleGroupId = 504 AND a.CurrentCategoryId = r.CurrentCategory AND (r.IsProbationLastDay IS NULL OR a.IsProbationLastDay = r.IsProbationLastDay) AND a.BetCount >= r.BetCount AND a.WinlossRM >= r.WinlossRM AND a.Margin >= r.Margin AND a.WinDaysRate >= r.WinDaysRate)
		) AS b
		INNER JOIN #tmpCustomerAccummulatedInfo AS t ON t.CustId = b.CustId AND t.SportGroup = b.SportGroup
	 WHERE b.RowNum = 1;

	--#12: Insert to CustomerClassification BySport
	INSERT INTO dbo.CustomerClassification_BySport(CustId, SportId, CategoryId, CurrentCategoryId, CreatedDate, CreatedTime, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime)
	OUTPUT INSERTED.CustId, INSERTED.SportId, INSERTED.CategoryId, INSERTED.BetCount INTO #tmpBetCount  
	SELECT  a.CustId
		, 	a.SportGroup
		,   CASE 
				WHEN a.NewCategoryId IS NULL THEN a.CurrentCategoryId 
				WHEN a.NewCategoryId IN (@CATEGORY_SMART, @CATEGORY_RISKY) AND a.CurrentCategoryId NOT IN (@CATEGORY_PROBATION, @CATEGORY_SMART, @CATEGORY_RISKY) THEN @CATEGORY_PROBATION
			ELSE a.NewCategoryId END
		,	a.CurrentCategoryId
		,	@CurrentDate
		,	@CurrentDateTime
		,	a.TurnoverRM
		,	a.WinlossRM
		,	a.BetCount
		,	a.ActiveDays
		,  ISNULL(a.PerformanceTime, @CurrentDateTime)
	FROM #tmpCustomerAccummulatedInfo AS a WITH(NOLOCK)

	-- #13: Update last settle betcounts
	EXEC dbo.CTS_NormalClassification_BetCount_Update @CurrentDateTime = @CurrentDateTime, @IsGeneralFlow = 0;

	DROP TABLE #tmpCustomerAccummulatedInfo;
	DROP TABLE #tmpCustomers;
	DROP TABLE #tmpRawData;		
	DROP TABLE #tmpBetCount;
END;
GO

GRANT EXECUTE ON [dbo].[CTS_BySportNormalClassification_NormalPool_Classify] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_BySportNormalClassification_NormalPool_Classify] TO [wsv_cts]
GO