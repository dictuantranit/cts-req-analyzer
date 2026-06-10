/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_GeneralNormalClassification_Balance_Reset]
	@CurrentDateTime		DATETIME,
	@YesterdayDate			DATE
AS
/*
	Created: 20230627@Jonas.Huynh
	Task : Update Reset Balance for Normal Inactive to New
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20230627@Jonas.Huynh: Reset Balance for Credit with Inactive Normal with new place-bet [Redmine ID: #189876]
		- 20240618@Jonas.Nguyen: Renovate CC - Phase 2 [Redmine ID: #205317]

	Param's Explanation:
		
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @CATEGORY_NORMALINACTIVE	INT = 40700;

	IF	OBJECT_ID('tempdb..#tmpResetBalance') IS NOT NULL
	DROP TABLE	#tmpResetBalance;

	CREATE TABLE #tmpResetBalance(
		CustId		 INT PRIMARY KEY
	);

	INSERT INTO #tmpResetBalance (CustId)
	SELECT a.CustId
	FROM #tmpCustomers AS a 
	WHERE a.CurrentCategoryId = @CATEGORY_NORMALINACTIVE 
		AND a.IsDeposit = 0
		AND a.IsActiveWithin30Days = 1
		AND a.IsNewCreated = 0; 

	UPDATE rb WITH(ROWLOCK, UPDLOCK)
	SET rb.ResetDate = @YesterdayDate,
		rb.CreatedTime = @CurrentDateTime
	FROM #tmpResetBalance AS a
		INNER JOIN dbo.CustomerClassification_ResetBalance AS rb ON rb.CustId = a.CustId

	INSERT INTO dbo.CustomerClassification_ResetBalance (CustId, ResetDate, CreatedTime)
	SELECT a.CustId, @YesterdayDate, @CurrentDateTime
	FROM #tmpResetBalance AS a
	WHERE NOT EXISTS (SELECT 1 FROM dbo.CustomerClassification_ResetBalance AS rb WITH(NOLOCK) WHERE rb.CustId = a.CustId);

	INSERT INTO dbo.CustomerClassification_ResetBalance_History (CustId, ResetDate, CreatedTime)
	SELECT CustId, @YesterdayDate, @CurrentDateTime 
	FROM #tmpResetBalance;
END;
GO

GRANT EXECUTE ON [dbo].[CTS_GeneralNormalClassification_Balance_Reset] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_GeneralNormalClassification_Balance_Reset] TO [wsv_cts]
GO

