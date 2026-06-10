/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_NormalClassification_TWGroupBetting_CheckChanges]
AS
/*
	Created: 	20231030@Victoria.Le
	Task : 		Check Customers who have data changed from a range of time
	DB: 		bodb_VR2Model
	Original:	
	Revisions:
		- 20231030@Victoria.Le: 	Initial Writing  [Redmine ID: #195060]
		- 20240628@Thomas.Nguyen: 	Renovate CC phase 2 - Not update infor when JobScannedType = 2 [Redmine ID: #205317]
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @Batchsize								INT = 2000;
	DECLARE @CountRount								INT = 0;
	DECLARE @Today									DATETIME2 = GETDATE();
	DECLARE	@LastModifiedDate		 				DATETIME2;
	DECLARE	@NextScannedDatetime	 				DATETIME2;
	DECLARE @SystemParameter_LastModifiedDate    	TINYINT = 8;
	DECLARE @SPORT_SOCCER							TINYINT = 1;
	DECLARE @SPORT_BASEKETBALL						TINYINT = 2;
	DECLARE @SPORT_MIX								TINYINT = NULL;
	DECLARE @TYPE_SCANNING							TINYINT = 0;
	DECLARE @TYPE_FAILED							TINYINT = 1;
	DECLARE @TYPE_PASSED							TINYINT = 2;
	
	IF	OBJECT_ID('tempdb..#tmpRawData') IS NOT NULL
		DROP TABLE	#tmpRawData;

	CREATE TABLE #tmpRawData(
			CustId			INT
		,	SportType		INT
		,	TransId			BIGINT
		,	TransDate		DATETIME	
		,	IsFraud			BIT
		,	TicketRank		TINYINT
	);
	
	IF	OBJECT_ID('tempdb..#tmpScannedNewCust') IS NOT NULL
		DROP TABLE	#tmpScannedNewCust;

	CREATE TABLE #tmpScannedNewCust(
			CustId					INT	PRIMARY KEY
		,	TotalTicketCount		INT DEFAULT 0
		,	GBTicketCount			INT DEFAULT 0
		,	SportType				INT	NULL
		,	JobScannedType			TINYINT DEFAULT 0
		,	IsExist					BIT DEFAULT 0
		,	IsChecked				BIT DEFAULT 0
	);
	
	IF	OBJECT_ID('tempdb..#tmpBatch') IS NOT NULL
		DROP TABLE	#tmpBatch;
		
	CREATE TABLE #tmpBatch(
			CustId					INT	PRIMARY KEY
		,	TotalTicketCount		INT
		,	GBTicketCount			INT 
		,	SportType				INT	
		,	JobScannedType			TINYINT 
		,	IsExist					BIT 
	);
	
	-- ----------------------------------------------------------
	SELECT @LastModifiedDate = CONVERT(DATETIME2, [Value], 121)
	FROM dbo.CustomerClassification_Parameter WITH(NOLOCK)
	WHERE DataId = @SystemParameter_LastModifiedDate;
	
	INSERT INTO #tmpRawData(CustId, SportType, TransId, TransDate, IsFraud, TicketRank)
	EXEC dbo.CTS_TWGB_GetDWData @PreviousModifiedTime = @LastModifiedDate, @NewModifiedTime = @NextScannedDatetime OUTPUT;
	
	CREATE CLUSTERED INDEX CIX_tmpRawData_CustId ON #tmpRawData (CustId);
	
	INSERT INTO #tmpScannedNewCust (CustId,TotalTicketCount,GBTicketCount)
	SELECT tr.CustId, MAX(tr.TicketRank), SUM(CASE WHEN tr.TicketRank <= 5 THEN tr.IsFraud ELSE 0 END)
	FROM #tmpRawData AS tr WITH(NOLOCK)
	WHERE tr.CustId IN (SELECT CustId
						FROM #tmpRawData WITH(NOLOCK)
						GROUP BY CustId
						HAVING MAX(TicketRank) > 2)
	GROUP BY tr.CustId
	;
	
	UPDATE ts
	SET IsExist = CASE WHEN cs.CustId IS NOT NULL THEN 1 ELSE 0 END
	FROM #tmpScannedNewCust AS ts WITH(NOLOCK)
		LEFT JOIN dbo.CustomerClassification_ScannedNewCust AS cs WITH (NOLOCK) ON cs.CustId = ts.CustId
	;

	UPDATE ts
	SET IsChecked = 0
	FROM #tmpScannedNewCust AS ts WITH(NOLOCK)
	WHERE ts.IsExist = 0
	;

	UPDATE ts
	SET IsChecked = CASE WHEN cs.GBTicketCount <> ts.GBTicketCount THEN 0 ELSE 1 END
	FROM #tmpScannedNewCust AS ts WITH(NOLOCK)
		INNER JOIN dbo.CustomerClassification_ScannedNewCust AS cs WITH (NOLOCK) ON cs.CustId = ts.CustId
	WHERE ts.IsExist = 1
	;
	
	UPDATE ts
	SET SportType = @SPORT_SOCCER
	FROM #tmpScannedNewCust AS ts
	WHERE ts.GBTicketCount >= 3
		AND NOT EXISTS (SELECT 1 
						FROM #tmpRawData AS tr WITH(NOLOCK)
						WHERE tr.CustId = ts.CustId 
							AND tr.TicketRank <= 5
							AND tr.IsFraud = 1
							AND tr.SportType <> @SPORT_SOCCER)
	;
	
	UPDATE ts
	SET SportType = @SPORT_BASEKETBALL
	FROM #tmpScannedNewCust AS ts
	WHERE ts.GBTicketCount >= 3
		AND NOT EXISTS (SELECT 1 FROM #tmpRawData AS tr WITH(NOLOCK)
									WHERE tr.CustId = ts.CustId 
										AND tr.TicketRank <= 5
										AND tr.IsFraud = 1
										AND tr.SportType <> @SPORT_BASEKETBALL)
	;
	
	UPDATE ts
	SET SportType = @SPORT_MIX
	FROM #tmpScannedNewCust AS ts
	WHERE ts.GBTicketCount >= 3
		AND EXISTS (SELECT 1 FROM #tmpRawData AS tr1 
								WHERE tr1.CustId = ts.CustId 
									AND tr1.TicketRank <= 5
									AND tr1.IsFraud = 1
									AND tr1.SportType = @SPORT_SOCCER)
		AND EXISTS (SELECT 1 FROM #tmpRawData AS tr2 
								WHERE tr2.CustId = ts.CustId 
									AND tr2.TicketRank <= 5
									AND tr2.IsFraud = 1
									AND tr2.SportType = @SPORT_BASEKETBALL)

	;

	WHILE(1=1)
	BEGIN
		SELECT @CountRount = COUNT(1) FROM #tmpScannedNewCust WHERE IsChecked = 0;
		IF (@CountRount = 0) BREAK;
		
		TRUNCATE TABLE #tmpBatch;
		INSERT INTO #tmpBatch (CustId,TotalTicketCount,GBTicketCount,SportType,JobScannedType,IsExist)
		SELECT TOP (@Batchsize) CustId,TotalTicketCount,GBTicketCount,SportType,JobScannedType,IsExist
		FROM #tmpScannedNewCust
		WHERE IsChecked = 0
		ORDER BY CustId
		;
	
		UPDATE cs WITH (UPDLOCK,ROWLOCK)
		SET 	TotalTicketCount 	= 	tb.TotalTicketCount
			,	GBTicketCount 		= 	tb.GBTicketCount
			,	SportType 			= 	tb.SportType
			,	JobScannedType		=	CASE WHEN tb.SportType = @SPORT_SOCCER AND tb.GBTicketCount >= 4 THEN @TYPE_PASSED
											 WHEN tb.SportType = @SPORT_BASEKETBALL AND tb.GBTicketCount >= 3 THEN @TYPE_PASSED
											 WHEN tb.SportType = @SPORT_SOCCER AND tb.TotalTicketCount > 5 AND tb.GBTicketCount < 4 THEN @TYPE_FAILED
											 WHEN tb.SportType = @SPORT_BASEKETBALL AND tb.TotalTicketCount > 5 AND tb.GBTicketCount < 3 THEN @TYPE_FAILED
											 ELSE @TYPE_SCANNING END
			,	LastJobScannedTime	= 	@Today
		FROM dbo.CustomerClassification_ScannedNewCust AS cs
			INNER JOIN #tmpBatch AS tb ON tb.CustId = cs.CustId
		WHERE tb.IsExist = 1 AND tb.SportType IN (@SPORT_SOCCER,@SPORT_BASEKETBALL) AND cs.JobScannedType <> 2;
		
		UPDATE cs WITH (UPDLOCK,ROWLOCK)
		SET 	TotalTicketCount 	= 	tb.TotalTicketCount
			,	GBTicketCount 		= 	tb.GBTicketCount
			,	SportType 			= 	tb.SportType
			,	JobScannedType		=	CASE WHEN tb.GBTicketCount >= 4 THEN @TYPE_PASSED
											 WHEN tb.TotalTicketCount > 5 AND tb.GBTicketCount < 4 THEN @TYPE_FAILED
											 ELSE @TYPE_SCANNING END
			,	LastJobScannedTime	= 	@Today
		FROM dbo.CustomerClassification_ScannedNewCust AS cs
			INNER JOIN #tmpBatch AS tb ON tb.CustId = cs.CustId
		WHERE tb.IsExist = 1 AND tb.SportType IS NULL AND cs.JobScannedType <> 2;

		INSERT INTO dbo.CustomerClassification_ScannedNewCust (CustId,TotalTicketCount,GBTicketCount,SportType,CreatedTime,JobScannedType,LastJobScannedTime)
		SELECT 	tb.CustId
			,	tb.TotalTicketCount
			,	tb.GBTicketCount
			,	tb.SportType
			,	@Today
			,	CASE WHEN tb.SportType = @SPORT_SOCCER AND tb.GBTicketCount >= 4 THEN @TYPE_PASSED
					 WHEN tb.SportType = @SPORT_BASEKETBALL AND tb.GBTicketCount >= 3 THEN @TYPE_PASSED
					 WHEN tb.SportType = @SPORT_SOCCER AND tb.TotalTicketCount > 5 AND tb.GBTicketCount < 4 THEN @TYPE_FAILED
					 WHEN tb.SportType = @SPORT_BASEKETBALL AND tb.TotalTicketCount > 5 AND tb.GBTicketCount < 3 THEN @TYPE_FAILED
					 ELSE @TYPE_SCANNING END
			,	@Today
		FROM #tmpBatch AS tb
		WHERE tb.IsExist = 0 AND tb.SportType IN (@SPORT_SOCCER,@SPORT_BASEKETBALL);
		
		INSERT INTO dbo.CustomerClassification_ScannedNewCust (CustId,TotalTicketCount,GBTicketCount,SportType,CreatedTime,JobScannedType,LastJobScannedTime)
		SELECT 	tb.CustId
			,	tb.TotalTicketCount
			,	tb.GBTicketCount
			,	tb.SportType
			,	@Today
			,	CASE WHEN tb.GBTicketCount >= 4 THEN @TYPE_PASSED
					 WHEN tb.TotalTicketCount > 5 AND tb.GBTicketCount < 4 THEN @TYPE_FAILED
					 ELSE @TYPE_SCANNING END
			,	@Today
		FROM #tmpBatch AS tb
		WHERE tb.IsExist = 0 AND tb.SportType IS NULL;

		UPDATE ts
		SET ts.IsChecked = 1
		FROM #tmpScannedNewCust AS ts
			INNER JOIN #tmpBatch AS tb ON ts.CustId = tb.CustId
		;

	END;
	
	IF @NextScannedDatetime IS NOT NULL AND @NextScannedDatetime > @LastModifiedDate
	BEGIN
		UPDATE dbo.CustomerClassification_Parameter WITH(UPDLOCK,ROWLOCK)
		SET [Value] = CONVERT(VARCHAR(200), @NextScannedDatetime)
		WHERE DataId = @SystemParameter_LastModifiedDate;
	END;

	DROP TABLE IF EXISTS #tmpRawData;
	DROP TABLE IF EXISTS #tmpScannedNewCust;
	DROP TABLE IF EXISTS #tmpBatch;
	
END;