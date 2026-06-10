/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
/****** Object:  StoredProcedure [dbo].[CTS_Monitoring_CustomerClassificationPool_Get]    ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_Monitoring_CustomerClassificationPool_Get]
AS
/*
	Created: 20240102@Jonas.Huynh
	Task : Enhance job monitoring
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20240102@Jonas.Huynh: Created [Redmine ID: #197999]
		- 20241213@Jonas.Huynh: Monitoring Realtime Pool [Redmine ID: 214157]

	Param's Explanation:

    Script:
        EXEC bodb_VR2Model.dbo.[CTS_Monitoring_CustomerClassificationPool_Get];
*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE	@CLASSIFICATION_GENERALPOOL					SMALLINT = 200
		,	@CLASSIFICATION_BYSPORTPOOL					SMALLINT = 201
		,	@CLASSIFICATION_GENERALNORMALINSERT			SMALLINT = 203
		,	@CLASSIFICATION_BYSPORTNORMALINSERT			SMALLINT = 204
		,	@REALTIME_GENERALCHANGES					SMALLINT = 102
		,	@REALTIME_BYSPORTCHANGES					SMALLINT = 103

	DECLARE @CONSTGENERAL_LASTSCANNEDID		TINYINT = 3
		,	@CONSTBYSPORT_LASTSCANNEDROW	TINYINT = 2;

	DECLARE @General_LastScannedID			BIGINT
		,	@BySport_LastScannedRow			ROWVERSION;

	IF OBJECT_ID('tempdb..#tmpMonitoring') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpMonitoring;
	END

	CREATE TABLE #tmpMonitoring(
		IssueTypeID		       SMALLINT PRIMARY KEY,
		NumberOfRecord		   BIGINT
	);

	-- 1. Normal Pool
	INSERT INTO #tmpMonitoring (IssueTypeID, NumberOfRecord)
	SELECT @CLASSIFICATION_GENERALPOOL, COUNT(1)
	FROM [dbo].CustomerClassification_NormalPool WITH (NOLOCK);
	
	INSERT INTO #tmpMonitoring (IssueTypeID, NumberOfRecord)
	SELECT @CLASSIFICATION_BYSPORTPOOL, COUNT(1)
	FROM [dbo].CustomerClassification_BySport_NormalPool WITH (NOLOCK);

	-- 2. Normal Insert Account
	SELECT @General_LastScannedID = CAST([Value] AS BIGINT) FROM dbo.CustomerClassification_Parameter WITH(NOLOCK) WHERE [DataId] = @CONSTGENERAL_LASTSCANNEDID;
	SELECT @BySport_LastScannedRow = CAST(CAST([Value] AS BIGINT) AS ROWVERSION) FROM dbo.CustomerClassification_Parameter WITH(NOLOCK) WHERE [DataId] = @CONSTBYSPORT_LASTSCANNEDROW;
	
	INSERT INTO #tmpMonitoring (IssueTypeID, NumberOfRecord)
	SELECT @CLASSIFICATION_GENERALNORMALINSERT, COUNT(1)
	FROM [dbo].CustomerClassification WITH (NOLOCK)
	WHERE ID > @General_LastScannedID;

	INSERT INTO #tmpMonitoring (IssueTypeID, NumberOfRecord)
	SELECT @CLASSIFICATION_BYSPORTNORMALINSERT, COUNT(1)
	FROM [dbo].CustomerClassification_BySport WITH (NOLOCK)
	WHERE [RowVersion] > @BySport_LastScannedRow;

	-- 3. Realtime Check Changes
	INSERT INTO #tmpMonitoring (IssueTypeID, NumberOfRecord)
	SELECT @REALTIME_GENERALCHANGES, COUNT(1)
	FROM [dbo].CustomerClassification_RealtimeChanges WITH (NOLOCK);

	INSERT INTO #tmpMonitoring (IssueTypeID, NumberOfRecord)
	SELECT @REALTIME_BYSPORTCHANGES, COUNT(1)
	FROM [dbo].CustomerClassification_BySport_RealtimeChanges WITH (NOLOCK);

	-- 4. Return result
	SELECT	IssueTypeID
		,	NumberOfRecord  
	FROM #tmpMonitoring;

	DROP TABLE #tmpMonitoring;
END;
GO

GRANT EXECUTE ON [dbo].[CTS_Monitoring_CustomerClassificationPool_Get] TO wsv_cts
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_Monitoring_CustomerClassificationPool_Get] TO wsv_cts
GO