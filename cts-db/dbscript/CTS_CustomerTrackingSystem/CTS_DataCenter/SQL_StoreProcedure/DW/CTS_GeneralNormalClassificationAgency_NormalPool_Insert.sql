/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_GeneralNormalClassificationAgency_NormalPool_Insert]
		@FunctionId		SMALLINT,
		@Priority		SMALLINT
AS
/*
	Created: 20241003@Jonas.Huynh
	Task : Insert customers to normal pool for classification
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20241003@Jonas.Huynh: Created [Redmine ID: #185799]

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
		INSERT INTO dbo.CustomerClassificationAgency_NormalPool(CustId, [Priority], FunctionId, CreatedTime)
		OUTPUT INSERTED.CustId, @FunctionId, @CURRENTTIME INTO dbo.CustomerClassificationAgency_Log(CustId, FunctionId, CreatedTime)  
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

GRANT EXECUTE ON [dbo].[CTS_GeneralNormalClassificationAgency_NormalPool_Insert] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_GeneralNormalClassificationAgency_NormalPool_Insert] TO [wsv_cts]
GO