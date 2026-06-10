/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
/****** Object:  StoredProcedure [dbo].[CTS_GeneralNormalClassification_NormalPool_Classify]    Script Date: 20/04/2023 11:05:2022 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_GeneralNormalClassification_NormalPool_Classify]
		@CustomersXML		XML
AS
/*
	Created: 20230421@Jonas.Huynh
	Task : Insert customers to normal pool for classification
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20230421@Jonas.Huynh: Created [Redmine ID: #186678]
		- 20230519@Jonas.Huynh: HF Wrong inactive category with new placebet [Redmine ID: #188464]
		- 20230601@Jonas.Huynh: Normal Renovation (Phase2) [Redmine ID: #186684]
		- 20230627@Jonas.Huynh: Reset Balance for Credit with Inactive Normal with new place-bet [Redmine ID: #189876]
		- 20230807@Jonas.Huynh: HF exclude Non-sport for General [Redmine ID: #192388]
		- 20230726@Jonas.Huynh: Saba Classification [Redmine ID: #185320]
		- 20230816@Jonas.Huynh: Tagging Classification [Redmine ID: #191400]
		- 20230915@Jonas.Huynh: HF Wrong Inactive Category for New and Realtime flow exclude S/R/P with not latest category [Redmine ID: #193050]
		- 20231030@Victoria.Le: New Member Classify Tagging [Redmine ID: #195060]
		- 20240424@Thomas.Nguyen: Remove logic New Member Classify Tagging [Redmine ID: #200854]
		- 20240618@Jonas.Huynh: Renovate CC - Phase 2 [Redmine ID: #205317]
		- 20241223@Jonas.Huynh: HF Incorrect Inactive Category [Redmine ID: #215615]
		- 20250515@Long.Luu: 	Add new 3 special licensees "Winbox, SM88, and SL88SW" [Redmine ID: #226846]
		- 20250515@Thomas.Nguyen: Add logic for Special Lic Sub [Redmine ID: #226847]

	Param's Explanation:
		@CustomersXML		: This parameter is used to classify customer perf which bases on currentCategory
		@IsScanOnlyTagging  : 0-Performance Classification, 1-Behaviour Classification (Tagging)
    Script:
        EXEC bodb_VR2Model.dbo.[CTS_GeneralNormalClassification_NormalPool_Classify] 
			@CustomersXML = N'<Root>
								<r CustId="5002646" CategoryId="201" IsNewCreated="0" IsRealtimeOnly= "0" IsProbationLastDay="0" ScanTaggingType="0" ScanSpecialLicSubType="1" IsSpecialLicSubCC="0"/>
								<r CustId="5022391" CategoryId="0"  IsNewCreated="1" IsRealtimeOnly= "1" IsProbationLastDay="0" ScanTaggingType="0" ScanSpecialLicSubType="1" IsSpecialLicSubCC="0"/>
								<r CustId="1275" CategoryId="205"  IsNewCreated="0" IsRealtimeOnly= "1" IsProbationLastDay="1" ScanTaggingType="0"  ScanSpecialLicSubType="0" IsSpecialLicSubCC="0"/>
								<r CustId="1280" CategoryId="202"  IsNewCreated="1" IsRealtimeOnly= "1" IsProbationLastDay="1" ScanTaggingType="0"  ScanSpecialLicSubType="0" IsSpecialLicSubCC="1"/>
							</Root>';
*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @GENERAL_SPORTID				SMALLINT = 200;
	DECLARE @CurrentDateTime				DATETIME = GETDATE();
	DECLARE	@ToDate							DATE	  = GETDATE();
	DECLARE @YesterdayDate					DATE	  = DATEADD(DAY, -1, @ToDate);
	DECLARE @From30Date						DATE	  = DATEADD(DAY, -29, @ToDate);

	DECLARE @CATEGORY_NULL					INT = 0,
			@CATEGORY_NORMALINACTIVE		INT = 40700,
	   	    @CATEGORY_SMARTINACTIVE			INT = 40701,
			@CATEGORY_NEW					INT = 40100,
			@CATEGORY_GOOD					INT = 40200,
			@CATEGORY_NORMAL				INT = 40300,
			@CATEGORY_PROBATION				INT = 40400,
			@CATEGORY_SMART					INT = 40500,
			@CATEGORY_RISKY					INT = 40600;

	DECLARE @SportGroup_SabaVRSoccer		SMALLINT = 145,
			@SportGroup_SabaVRBasketball	SMALLINT = 912,
			@SportGroup_NonSport			SMALLINT = 229;

	DECLARE @ScanTaggingType_NotExist		TINYINT = 0,
			@ScanTaggingType_Exist			TINYINT = 1,
			@ScanTaggingType_ExistOnly		TINYINT = 2,
			@ScanSpecialLicSubType_Exist	TINYINT = 1;

	DECLARE @ListCustIds					VARCHAR(MAX);

	IF OBJECT_ID('tempdb..#tmpCustomers') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustomers;
	END

	CREATE TABLE #tmpCustomers(
		CustId			       INT PRIMARY KEY,
		CurrentCategoryId      INT		NOT NULL,
		IsNewCreated	       BIT	    NOT NULL DEFAULT 0,
		IsRealtimeOnly		   BIT	    NOT NULL DEFAULT 0,
		IsProbationLastDay	   BIT		NOT NULL DEFAULT 0,
		ScanTaggingType		   TINYINT	NOT NULL DEFAULT 0,
		IsActiveWithin30Days   BIT		NOT NULL DEFAULT 0,
		IsDeposit			   BIT		NOT NULL DEFAULT 0,
		IsSpecialSite		   BIT		NOT NULL DEFAULT 0,
		SRecommend			   INT,
		ScanSpecialLicSubType  TINYINT	NOT NULL DEFAULT 0,
		IsIgnoreInactive  	   BIT		NULL DEFAULT 0,
	);
	
	CREATE NONCLUSTERED INDEX IX_tmpCustomers_IsRealtimeOnly_CurrentCategoryId_ScanTaggingType ON #tmpCustomers(
		IsRealtimeOnly,
		CurrentCategoryId,
		ScanTaggingType
	);
	
	IF OBJECT_ID('tempdb..#tmpScanTaggingCustomer') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpScanTaggingCustomer;
	END

	CREATE TABLE #tmpScanTaggingCustomer(
		CustId			       INT PRIMARY KEY,
		CurrentCategoryId      INT		NOT NULL,
		ScanTaggingType		   TINYINT	NOT NULL DEFAULT 0,
		ScanSpecialLicSubType  TINYINT	NOT NULL DEFAULT 0

	);

	IF	OBJECT_ID('tempdb..#tmpRawData') IS NOT NULL
		DROP TABLE	#tmpRawData;

	CREATE TABLE #tmpRawData(
		CustId				 INT			NOT NULL,
		SportGroup			 INT			NOT NULL,
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

	CREATE CLUSTERED INDEX CIX_tmpRawData_CustId ON #tmpRawData(CustId);

	IF	OBJECT_ID('tempdb..#tmpCustomerAccummulatedInfo') IS NOT NULL
		DROP TABLE	#tmpCustomerAccummulatedInfo;

	CREATE TABLE #tmpCustomerAccummulatedInfo(
		CustId				   INT			  NOT NULL,
		CurrentCategoryId	   INT			  NOT NULL DEFAULT 0,
		NewCategoryId		   INT			  NULL,
		IsActiveWithin30Days   BIT			  NOT NULL DEFAULT 0,
		IsProbationLastDay	   BIT			  NOT NULL DEFAULT 0,
		IsRealtimeOnly		   BIT			  NOT NULL DEFAULT 0,
		ScanTaggingType		   TINYINT		  NOT NULL DEFAULT 0,
		IsSpecialSite		   BIT			  NOT NULL DEFAULT 0,
		IsDeposit			   BIT			  NOT NULL DEFAULT 0,
		SRecommend			   INT,
		TurnoverRM			   DECIMAL(19, 4) NOT NULL,
		WinlossRM			   DECIMAL(19, 4) NOT NULL,
		Margin				   DECIMAL(19, 4) NOT NULL,
		BetCount			   BIGINT		  NOT NULL,
		ActiveDays			   INT			  NOT NULL,
		PerformanceTime        DATETIME       NOT NULL
	);

	CREATE CLUSTERED INDEX CIX_tmpCustomerAccummulatedInfo_CustId ON #tmpCustomerAccummulatedInfo(
		CustId
	);

	CREATE NONCLUSTERED INDEX IX_tmpCustomerAccummulatedInfo_CurrentCategoryId ON #tmpCustomerAccummulatedInfo(
		CurrentCategoryId
	);

	CREATE NONCLUSTERED INDEX IX_tmpCustomerAccummulatedInfo_SRecommend ON #tmpCustomerAccummulatedInfo(
		SRecommend
	);

	IF	OBJECT_ID('tempdb..#tmpBetCount') IS NOT NULL
		DROP TABLE	#tmpBetCount;

	CREATE TABLE #tmpBetCount(
		CustId		INT	PRIMARY KEY,
		SportGroup	SMALLINT,
		CategoryId	INT	NOT NULL,
		BetCount	BIGINT NULL
	);

	CREATE NONCLUSTERED INDEX IX_tmpBetCount_CategoryId ON #tmpBetCount(
		CategoryId
	);

	IF	OBJECT_ID('tempdb..#tmpRemoveCust') IS NOT NULL
	DROP TABLE	#tmpRemoveCust;

	CREATE TABLE #tmpRemoveCust(
		CustId INT PRIMARY KEY
	);

	-- #1: Get list customers
	INSERT INTO #tmpCustomers(CustId, CurrentCategoryId, IsNewCreated, IsRealtimeOnly, IsProbationLastDay, ScanTaggingType, ScanSpecialLicSubType, IsIgnoreInactive)
	SELECT	T.C.value('./@CustId', 'INT')						AS CustId
		,	T.C.value('./@CategoryId', 'INT')					AS CurrentCategoryId
		,	T.C.value('./@IsNewCreated', 'BIT')					AS IsNewCreated
		,	T.C.value('./@IsRealtimeOnly', 'BIT')				AS IsRealtimeOnly
		,	T.C.value('./@IsProbationLastDay', 'BIT')			AS IsProbationLastDay
		,	T.C.value('./@ScanTaggingType', 'TINYINT')			AS ScanTaggingType
		,	T.C.value('./@ScanSpecialLicSubType', 'TINYINT')	AS ScanSpecialLicSubType
		,	T.C.value('./@IsSpecialLicSubCC', 'BIT')			AS IsIgnoreInactive
	FROM @CustomersXML.nodes('//r') AS T(C)
	OPTION (OPTIMIZE FOR (@CustomersXML = NULL));
	
	-- #2: Remove realtime classification with category not in (null, new, good, normal)
	UPDATE a WITH(ROWLOCK, UPDLOCK)
	SET	 a.ScanTaggingType = @ScanTaggingType_ExistOnly,
		 a.IsRealtimeOnly = 0
	FROM #tmpCustomers AS a
	WHERE   a.IsRealtimeOnly = 1 
		AND a.CurrentCategoryId IN (@CATEGORY_SMART, @CATEGORY_RISKY, @CATEGORY_PROBATION)
		AND a.ScanTaggingType = @ScanTaggingType_Exist;

	DELETE a WITH (ROWLOCK)
	FROM #tmpCustomers AS a
	WHERE   a.IsRealtimeOnly = 1 
		AND a.CurrentCategoryId IN (@CATEGORY_SMART, @CATEGORY_RISKY, @CATEGORY_PROBATION)
		AND a.ScanTaggingType = @ScanTaggingType_NotExist;

			
	-- #3: Get list customers to retrieve performances
	SELECT @ListCustIds = STUFF(( SELECT DISTINCT ',', CONVERT(VARCHAR(15), CustId) 
								  FROM #tmpCustomers WITH (NOLOCK)
								  FOR XML PATH('')), 1, 1, '');

	-- #4: Scan tagging only
	DELETE a WITH (ROWLOCK)
	OUTPUT DELETED.CustId,DELETED.CurrentCategoryId, DELETED.ScanTaggingType, DELETED.ScanSpecialLicSubType INTO #tmpScanTaggingCustomer(CustId, CurrentCategoryId, ScanTaggingType, ScanSpecialLicSubType)
	FROM #tmpCustomers AS a
	WHERE ScanTaggingType = @ScanTaggingType_ExistOnly OR ScanSpecialLicSubType = @ScanSpecialLicSubType_Exist;

	IF (EXISTS (SELECT 1 FROM #tmpCustomers))
	BEGIN
		-- #5: Get customer info
		UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET	   a.SRecommend = c.srecommend,
			   a.IsSpecialSite = CASE WHEN c.Site IN ('haifa','manbetx','HC6YAYOU','US8YAYOU','BPLE','Okada','Winbox', 'SM88', 'SL88SW') THEN 1 ELSE 0 END
		FROM #tmpCustomers AS a
			INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON a.CustId = c.custid;

		UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.IsDeposit = 1
		FROM #tmpCustomers AS a
			INNER JOIN bodb02.dbo.Dep_CustSuper AS c WITH(NOLOCK) ON a.SRecommend = c.custid;

		UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.IsActiveWithin30Days = 1
		FROM #tmpCustomers AS a
			LEFT JOIN dbo.CustomerClassification_LatestActiveDay AS c WITH(NOLOCK) ON a.CustId = c.CustId
		WHERE ((c.CustId IS NOT NULL AND c.LastTransDate >= @From30Date)
				OR a.IsNewCreated = 1)
				OR a.IsIgnoreInactive = 1;
	
		-- #6: Update reset balance for credit - normal inactive with new placebet
		EXEC dbo.CTS_GeneralNormalClassification_Balance_Reset @CurrentDateTime = @CurrentDateTime, @YesterdayDate = @YesterdayDate;
	END;

	-- #7: Get accummulated performance
	INSERT INTO #tmpRawData(CustId, SportGroup, TurnoverRM, WinlossRM, TurnoverORG, WinlossORG, BetCount, ActiveDaysCustID, ActiveDaysSportGroup, WindaysCustID, WinDaysSportGroup, ProcessedTime)
	EXEC bodb_dwrs.dbo.Acc_Rpt_CTS_GetCustAccumulatedInfo @ListCustID = @ListCustIds, @isResetBalance = 1;

	DELETE a WITH (ROWLOCK)
	FROM #tmpRawData AS a
	WHERE a.SportGroup IN (@SportGroup_NonSport, @SportGroup_SabaVRSoccer, @SportGroup_SabaVRBasketball);
		
	INSERT INTO #tmpCustomerAccummulatedInfo(CustId, TurnoverRM, WinlossRM, Margin, BetCount, ActiveDays, PerformanceTime)
	SELECT a.CustId,
			SUM(a.TurnoverRM),
			SUM(a.WinlossRM),
			CASE WHEN SUM(a.TurnoverRM) = 0 THEN 0 ELSE SUM(a.WinlossRM) / SUM(a.TurnoverRM) * 100 END,
			SUM(a.BetCount),
			MAX(a.ActiveDaysCustID),
			MAX(a.ProcessedTime)
	FROM #tmpRawData AS a
	GROUP BY a.CustId;

	IF (EXISTS (SELECT 1 FROM #tmpScanTaggingCustomer))
	BEGIN
		-- #8.1: Classify Tagging (link Association, TWGB,...)
		INSERT INTO dbo.CustomerClassification(CustId, SportId, CategoryId, CurrentCategoryId, CreatedDate, CreatedTime, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime, ScanTaggingType, ScanSpecialLicSubType)
		SELECT t.CustId
			,  @GENERAL_SPORTID
			,  t.CurrentCategoryId
			,  t.CurrentCategoryId
			,  @ToDate AS CreatedDate
			,  @CurrentDateTime AS CreatedTime
			,  c.TurnoverRM
			,  c.WinlossRM
			,  c.BetCount
			,  c.ActiveDays
			,  ISNULL(c.PerformanceTime, @CurrentDateTime)
			,  t.ScanTaggingType
			,  t.ScanSpecialLicSubType
		FROM #tmpScanTaggingCustomer AS t
			LEFT JOIN #tmpCustomerAccummulatedInfo AS c ON t.CustId = c.CustId;

		-- #8.2: Remove Scan Tagging Performance
		DELETE a WITH (ROWLOCK)
		FROM #tmpCustomerAccummulatedInfo AS a
			INNER JOIN #tmpScanTaggingCustomer AS t ON t.CustId = a.CustId;
	END
	
	IF (EXISTS (SELECT 1 FROM #tmpCustomers))
	BEGIN
		-- #9: Map relevant customer info
		UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.CurrentCategoryId = c.CurrentCategoryId,
			a.IsRealtimeOnly = c.IsRealtimeOnly,
			a.IsActiveWithin30Days = c.IsActiveWithin30Days,
			a.IsProbationLastDay = c.IsProbationLastDay,
			a.ScanTaggingType = c.ScanTaggingType,
			a.SRecommend = c.SRecommend,
			a.IsSpecialSite = c.IsSpecialSite,
			a.IsDeposit = c.IsDeposit
		FROM #tmpCustomerAccummulatedInfo AS a
			INNER JOIN #tmpCustomers AS c ON a.CustId = c.custid;

		-- #10: Remove accounts with settle bet count has not reach the schedule (FOR REALTIME ONLY)
		---- less than 100 settle tickets compared to last scan for Good Member
		---- less than 20 settle tickets compared to last scan for Normal Member
		INSERT INTO #tmpRemoveCust(CustId)
		SELECT a.CustId
		FROM #tmpCustomerAccummulatedInfo AS a
			INNER JOIN dbo.CustomerClassification_BetCount AS b WITH(NOLOCK) ON a.CustId = b.CustId
		WHERE a.IsRealtimeOnly = 1 
				AND ((a.CurrentCategoryId = @CATEGORY_GOOD AND a.BetCount - b.BetCount < 100)
				OR (a.CurrentCategoryId = @CATEGORY_NORMAL AND a.BetCount - b.BetCount < 20));

		-- #11.1: Classify Tagging (link Association, TWGB,...) If having any from tagging function
		INSERT INTO dbo.CustomerClassification(CustId, SportId, CategoryId, CurrentCategoryId, CreatedDate, CreatedTime, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime, ScanTaggingType)
		SELECT r.CustId
			,  @GENERAL_SPORTID
			,  a.CurrentCategoryId
			,  a.CurrentCategoryId
			,  @ToDate AS CreatedDate
			,  @CurrentDateTime AS CreatedTime
			,  a.TurnoverRM
			,  a.WinlossRM
			,  a.BetCount
			,  a.ActiveDays
			,  ISNULL(a.PerformanceTime, @CurrentDateTime)
			,  @ScanTaggingType_ExistOnly
		FROM #tmpRemoveCust AS r
			INNER JOIN #tmpCustomerAccummulatedInfo AS a ON a.CustId = r.CustId
		WHERE a.ScanTaggingType = @ScanTaggingType_Exist;

		-- #11.2: Remove invalid realtime conditions data
		DELETE a WITH (ROWLOCK)
		FROM #tmpCustomerAccummulatedInfo AS a
			INNER JOIN #tmpRemoveCust AS b ON a.CustId = b.CustId;

		DELETE a WITH (ROWLOCK)
		FROM #tmpCustomers AS a
			INNER JOIN #tmpRemoveCust AS b ON a.CustId = b.CustId;

		-- #12: Insert scanned cust daily
		UPDATE b WITH(ROWLOCK, UPDLOCK)
		SET	b.CreatedDate = @ToDate
		FROM #tmpCustomers AS a
			INNER JOIN dbo.CustomerClassification_ScannedDailyCust AS b ON b.CustId = a.CustId;

		INSERT INTO dbo.CustomerClassification_ScannedDailyCust(CustId, CreatedDate)
		SELECT a.CustId, @ToDate
		FROM #tmpCustomers AS a
			LEFT JOIN dbo.CustomerClassification_ScannedDailyCust AS b WITH(NOLOCK) ON b.CustId = a.CustId
		WHERE b.CustId IS NULL;

		-- #13: Classify customer without performance 
		INSERT INTO dbo.CustomerClassification(CustId, SportId, CategoryId, CurrentCategoryId, CreatedDate, CreatedTime, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime, ScanTaggingType)
		SELECT t.CustId
			,  @GENERAL_SPORTID
			,  CASE WHEN t.IsActiveWithin30Days = 1 THEN @CATEGORY_NEW ELSE @CATEGORY_NORMALINACTIVE END
			,  @CATEGORY_NULL
			,  @ToDate AS CreatedDate
			,  @CurrentDateTime AS CreatedTime
			,  NULL
			,  NULL
			,  NULL
			,  NULL
			,  @CurrentDateTime
			,  t.ScanTaggingType
		FROM #tmpCustomers AS t
			LEFT JOIN #tmpCustomerAccummulatedInfo AS c ON t.CustId = c.CustId
		WHERE c.CustId IS NULL;	

		-- #14: Classify classification by general rule
		UPDATE t WITH(ROWLOCK, UPDLOCK)
		SET t.NewCategoryId = b.CategoryId,
			t.CurrentCategoryId = ISNULL(t.CurrentCategoryId, b.CategoryId)
		FROM (
				SELECT  a.CustId
					,   r.CategoryId
					,	ROW_NUMBER() OVER(PARTITION BY a.CustId ORDER BY r.Prioity ASC) AS RowNum
					FROM #tmpCustomerAccummulatedInfo AS a WITH(NOLOCK) 
						INNER JOIN dbo.CustomerClassification_Rule AS r WITH(NOLOCK) ON a.CurrentCategoryId = r.CurrentCategory 
					WHERE 	   (r.RuleGroupId = 1 AND a.BetCount < r.BetCount
						OR (r.RuleGroupId = 2 AND a.IsSpecialSite = r.IsSpecialSite AND a.BetCount >= r.BetCount AND a.Margin < r.Margin AND a.WinlossRM > r.WinlossRM)			-- NEW MEMBER	
						OR (r.RuleGroupId = 3 AND a.BetCount > r.BetCount AND a.Margin < r.Margin AND a.TurnoverRM > r.TurnoverRM AND a.ActiveDays >= r.ActiveDays)				-- GOOD
						OR (r.RuleGroupId = 4 AND a.IsSpecialSite = r.IsSpecialSite AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.Margin < r.Margin2)				-- NORMAL
						OR (r.RuleGroupId = 5 AND a.IsSpecialSite = r.IsSpecialSite AND a.BetCount >= r.BetCount AND a.Margin < r.Margin AND NOT (a.BetCount > r.BetCount2 AND a.TurnoverRM > r.TurnoverRM AND a.ActiveDays >= r.ActiveDays))	-- NORMAL
						OR (r.RuleGroupId = 6 AND a.IsSpecialSite = r.IsSpecialSite AND a.BetCount >= r.BetCount AND a.Margin < r.Margin AND a.WinlossRM <= r.WinlossRM)		-- NORMAL
						OR (r.RuleGroupId = 7 AND a.IsDeposit = r.IsDeposit AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.WinlossRM < r.WinlossRM)				-- NORMAL
						OR (r.RuleGroupId = 8 AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.Margin <= r.Margin2 AND a.WinlossRM <= r.WinlossRM)					-- PROBATION
						OR (r.RuleGroupId = 9 AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.Margin <= r.Margin2 AND a.WinlossRM <= r.WinlossRM)					-- PROBATION
						OR (r.RuleGroupId = 10 AND a.IsDeposit = r.IsDeposit AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin)												-- PROBATION
						OR (r.RuleGroupId = 11 AND a.IsDeposit = r.IsDeposit AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.WinlossRM >= r.WinlossRM)				-- PROBATION
						OR (r.RuleGroupId = 12 AND (r.IsProbationLastDay IS NULL OR (r.IsProbationLastDay IS NOT NULL AND a.IsProbationLastDay = r.IsProbationLastDay)) AND a.BetCount >= r.BetCount AND a.Margin >= r.Margin AND a.Margin <= r.Margin2 AND a.WinlossRM > r.WinlossRM) -- SMART
						OR (r.RuleGroupId = 13 AND a.BetCount >= r.BetCount AND a.Margin > r.Margin AND a.WinlossRM > r.WinlossRM AND a.WinlossRM <= r.WinlossRM2)				-- SMART
						OR (r.RuleGroupId = 14 AND a.Margin > r.Margin AND a.WinlossRM > r.WinlossRM AND a.WinlossRM <= r.WinlossRM2)											-- SMART
						OR (r.RuleGroupId = 15 AND a.Margin >= r.Margin AND a.Margin <= r.Margin2 AND a.WinlossRM > r.WinlossRM)												-- SMART
						OR (r.RuleGroupId = 16 AND (r.IsProbationLastDay IS NULL OR (r.IsProbationLastDay IS NOT NULL AND a.IsProbationLastDay = r.IsProbationLastDay)) AND a.BetCount >= r.BetCount AND a.Margin > r.Margin AND a.WinlossRM > r.WinlossRM) -- RISKY
						OR (r.RuleGroupId = 17 AND a.Margin > r.Margin AND a.WinlossRM > r.WinlossRM))																			-- RISKY
			) AS b
			INNER JOIN #tmpCustomerAccummulatedInfo AS t ON t.CustId = b.CustId
			WHERE b.RowNum = 1;

		--#15: Insert to CustomerClassification
		INSERT INTO dbo.CustomerClassification(CustId, SportId, CategoryId, CurrentCategoryId, CreatedDate, CreatedTime, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime, ScanTaggingType)
		OUTPUT INSERTED.CustId, @GENERAL_SPORTID, INSERTED.CategoryId, INSERTED.BetCount INTO #tmpBetCount
		SELECT a.CustId
			,  @GENERAL_SPORTID
			,  CASE 
					WHEN a.NewCategoryId IS NULL THEN a.CurrentCategoryId 
					WHEN a.NewCategoryId IN (@CATEGORY_SMART, @CATEGORY_RISKY) AND a.CurrentCategoryId NOT IN (@CATEGORY_PROBATION, @CATEGORY_SMART, @CATEGORY_RISKY) THEN @CATEGORY_PROBATION
					ELSE a.NewCategoryId END
			,  a.CurrentCategoryId
			,  @ToDate AS CreatedDate
			,  @CurrentDateTime AS CreatedTime
			,  a.TurnoverRM
			,  a.WinlossRM
			,  a.BetCount
			,  a.ActiveDays
			,  ISNULL(a.PerformanceTime, @CurrentDateTime)
			,  a.ScanTaggingType
		FROM #tmpCustomerAccummulatedInfo AS a WITH(NOLOCK)
		WHERE a.IsActiveWithin30Days = 1;

		INSERT INTO dbo.CustomerClassification(CustId, SportId, CategoryId, CurrentCategoryId, CreatedDate, CreatedTime, TurnoverRM, WinlossRM, BetCount, ActiveDays, PerformanceTime, ScanTaggingType)
		SELECT a.CustId
			,  @GENERAL_SPORTID
			,  CASE
					WHEN a.NewCategoryId IS NOT NULL AND a.NewCategoryId IN (@CATEGORY_SMART, @CATEGORY_RISKY, @CATEGORY_PROBATION) THEN @CATEGORY_SMARTINACTIVE
					WHEN a.CurrentCategoryId IS NOT NULL AND a.CurrentCategoryId IN (@CATEGORY_SMART, @CATEGORY_RISKY, @CATEGORY_PROBATION) THEN @CATEGORY_SMARTINACTIVE 
					ELSE @CATEGORY_NORMALINACTIVE 
			   END AS CategoryId
			,  a.CurrentCategoryId
			,  @ToDate AS CreatedDate
			,  @CurrentDateTime AS CreatedTime
			,  a.TurnoverRM
			,  a.WinlossRM
			,  a.BetCount
			,  a.ActiveDays
			,  ISNULL(a.PerformanceTime, @CurrentDateTime)
			,  a.ScanTaggingType
		FROM #tmpCustomerAccummulatedInfo AS a WITH(NOLOCK)
		WHERE a.IsActiveWithin30Days = 0;
	
		-- #16: Update last settle betcounts
		EXEC dbo.CTS_NormalClassification_BetCount_Update @CurrentDateTime = @CurrentDateTime, @IsGeneralFlow = 1;
	END;

	DROP TABLE #tmpCustomerAccummulatedInfo;
	DROP TABLE #tmpCustomers;
	DROP TABLE #tmpRawData;		
	DROP TABLE #tmpBetCount;
	DROP TABLE #tmpRemoveCust;
	DROP TABLE #tmpScanTaggingCustomer;
END;
GO