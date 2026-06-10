/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_GeneralNormalClassification_TWGroupBetting_UpdateNextScannedTime]
		@NextScannedDateTime DATETIME2
	,	@NextScannedCustID BIGINT
AS
/*
	Created: 	20231030@Victoria.Le
	Task : 		Update TWGroupBetting NextScannedTime
	DB: 		bodb_VR2Model
	Original:	
	Revisions:
		- 20231030@Victoria.Le: 	Initial Writing  [Redmine ID: #195060]
		- 20240424@Thomas.Nguyen: 	Update last scanned CustID [Redmine ID: #200854]

*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @LastJobScannedTime_ParamId TINYINT = 7;
	DECLARE	@LastJobScannedTime DATETIME2;
	DECLARE @LastScannedCustID_ParamId TINYINT = 14;
	DECLARE	@LastScannedCustID BIGINT;

	SELECT @LastJobScannedTime = CONVERT(DATETIME2, [Value], 121)
	FROM dbo.CustomerClassification_Parameter WITH(NOLOCK)
	WHERE DataId = @LastJobScannedTime_ParamId;

	SELECT @LastScannedCustID = [Value]
	FROM dbo.CustomerClassification_Parameter WITH(NOLOCK)
	WHERE DataId = @LastScannedCustID_ParamId;

	IF (@NextScannedDatetime IS NOT NULL AND @NextScannedDatetime > @LastJobScannedTime)
		BEGIN
			UPDATE dbo.CustomerClassification_Parameter WITH(ROWLOCK, UPDLOCK)
			SET [Value] = CONVERT(VARCHAR(200), @NextScannedDateTime)
			WHERE DataId = @LastJobScannedTime_ParamId;

		END;
	
	IF (@NextScannedCustID <> @LastScannedCustID)
		BEGIN
			UPDATE dbo.CustomerClassification_Parameter WITH(ROWLOCK, UPDLOCK)
			SET [Value] = @NextScannedCustID
			WHERE DataId = @LastScannedCustID_ParamId;
		END;

END;
GO

GRANT EXECUTE ON [dbo].[CTS_GeneralNormalClassification_TWGroupBetting_UpdateNextScannedTime] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_GeneralNormalClassification_TWGroupBetting_UpdateNextScannedTime] TO [wsv_cts]
GO