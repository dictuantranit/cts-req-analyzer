/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
/****** Object:  StoredProcedure [dbo].[CTS_NormalClassification_BetCount_Update]    Script Date: 03/04/2023 14:24:2022 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_NormalClassification_BetCount_Update]
	@CurrentDateTime		DATETIME,
	@IsGeneralFlow			BIT
AS
/*
	Created: 20230403@Jonas.Huynh
	Task : Modify betcount schedule for Normal & Good Member
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20230403@Jonas.Huynh: Modify betcount schedule for Normal & Good Member [Redmine ID: #185633]
		- 20230421@Jonas.Huynh: Realtime Renovation [Redmine ID: #186678]
		- 20230630@Jonas.Huynh: Normal renovation by Sport [Redmine ID: #189875]
		- 20240618@Jonas.Nguyen: Renovate CC - Phase 2 [Redmine ID: #205317]
	
	Param's Explanation:
		
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @GENERAL_SPORTID	SMALLINT = 200;

	DECLARE @CATEGORY_GOOD		INT	= 40200,
			@CATEGORY_NORMAL	INT	= 40300;

	DELETE a WITH(ROWLOCK)
	FROM #tmpBetCount AS a
	WHERE a.CategoryId NOT IN (@CATEGORY_NORMAL, @CATEGORY_GOOD);

	IF (@IsGeneralFlow = 1)
		BEGIN
			UPDATE b WITH(ROWLOCK, UPDLOCK)
			SET		b.BetCount = a.BetCount
				,	b.LastScannedDate = @CurrentDateTime
			FROM #tmpBetCount AS a WITH(NOLOCK)
				INNER JOIN dbo.CustomerClassification_BetCount AS b ON b.CustId = a.CustId

			INSERT INTO dbo.CustomerClassification_BetCount(CustId, SportId, BetCount, LastScannedDate)
			SELECT a.CustId, @GENERAL_SPORTID, a.BetCount, @CurrentDateTime
			FROM #tmpBetCount AS a WITH(NOLOCK) 
				LEFT JOIN dbo.CustomerClassification_BetCount AS b WITH(NOLOCK) ON b.CustId = a.CustId
			WHERE b.CustId IS NULL  

		END;
	ELSE
		BEGIN
			UPDATE b WITH(ROWLOCK, UPDLOCK)
			SET		b.BetCount = a.BetCount
				,	b.LastScannedDate = @CurrentDateTime
			FROM #tmpBetCount AS a WITH(NOLOCK)
				INNER JOIN dbo.CustomerClassification_BySport_BetCount AS b ON b.CustId = a.CustId AND b.SportId = a.SportGroup

			INSERT INTO dbo.CustomerClassification_BySport_BetCount(CustId, SportId, BetCount, LastScannedDate)
			SELECT a.CustId, a.SportGroup, a.BetCount, @CurrentDateTime
			FROM #tmpBetCount AS a WITH(NOLOCK)
				LEFT JOIN dbo.CustomerClassification_BySport_BetCount AS b WITH(NOLOCK) ON b.CustId = a.CustId AND b.SportId = a.SportGroup
			WHERE b.CustId IS NULL AND b.SportId IS NULL 
		END;
END;
GO

GRANT EXECUTE ON [dbo].[CTS_NormalClassification_BetCount_Update] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_NormalClassification_BetCount_Update] TO [wsv_cts]
GO

