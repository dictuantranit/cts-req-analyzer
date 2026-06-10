/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
/****** Object:  StoredProcedure [dbo].[CTS_GeneralNormalClassification_NormalPool_Insert]    Script Date: 20/04/2023 11:05:2022 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_GeneralNormalClassification_NormalPool_Insert]
		@FunctionId		SMALLINT,
		@Priority		SMALLINT
AS
/*
	Created: 20230420@Jonas.Huynh
	Task : Insert customers to normal pool for classification
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20230420@Jonas.Huynh: Created [Redmine ID: #186678]
		- 20230601@Jonas.Huynh: Normal Renovation (Phase2) [Redmine ID: #186684]
		- 20230816@Jonas.Huynh: Tagging Classification [Redmine ID: #191400]
		- 20240327@Jonas.Huynh: EC2024 - Resolve Locking [Redmine ID: #200842]

	Param's Explanation:
        @FunctionId		: Being used to log particular function
		@Priority		: Being used to prioritize group functions
    Script:
        EXEC bodb_VR2Model.dbo.CTS_GeneralNormalClassification_NormalPool_Insert @FunctionId = 1,
																				 @Priority = 1;
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @BATCHSIZE		INT = 4000;
	DECLARE	@CURRENTTIME	DATETIME = GETDATE();

	DECLARE @TotalRecords	INT = (SELECT COUNT(1) FROM #tmpCustomers);
	DECLARE @Offset			INT = 0;

	WHILE @Offset < @TotalRecords
	BEGIN
		INSERT INTO dbo.CustomerClassification_NormalPool(CustId, [Priority], FunctionId, CreatedTime)
		OUTPUT INSERTED.CustId, @FunctionId, @CURRENTTIME INTO dbo.CustomerClassification_Log(CustId, FunctionId, CreatedTime)  
		SELECT	a.CustId
			,	@Priority
			,	@FunctionId
			,	@CURRENTTIME
		FROM #tmpCustomers AS a
		ORDER BY a.CustId
		OFFSET @Offset ROWS
		FETCH NEXT @BATCHSIZE ROWS ONLY;

		SET @Offset = @Offset + @BATCHSIZE;
	END;

	DROP TABLE #tmpCustomers;
END;
GO

GRANT EXECUTE ON [dbo].[CTS_GeneralNormalClassification_NormalPool_Insert] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_GeneralNormalClassification_NormalPool_Insert] TO [wsv_cts]
GO