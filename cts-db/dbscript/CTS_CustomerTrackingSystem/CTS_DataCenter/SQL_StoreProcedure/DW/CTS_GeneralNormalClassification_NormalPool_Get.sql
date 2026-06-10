/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
/****** Object:  StoredProcedure [dbo].[CTS_GeneralNormalClassification_NormalPool_Get]    Script Date: 20/04/2023 11:05:2022 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_GeneralNormalClassification_NormalPool_Get]
	@ScannedMaxId BIGINT OUTPUT
AS
/*
	Created: 20230420@Jonas.Huynh
	Task : Insert customers to normal pool for classification
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20230420@Jonas.Huynh: Created [Redmine ID: #186678]
		- 20230816@Jonas.Huynh: Tagging Classification [Redmine ID: #191400]
		- 20230915@Jonas.Huynh: HF Wrong Inactive Category for New and Realtime flow exclude S/R/P with not latest category [Redmine ID: #193050]
		- 20231030@Victoria.Le: New Member Classify Tagging [Redmine ID: #195060]
		- 20240327@Jonas.Huynh: EC2024 - Resolve Locking [Redmine ID: #200842]
		- 20240426@Thomas.Nguyen: Remove logic New Member Classify Tagging [Redmine ID: #200854]
		- 20241226@Jonas.Huynh: HF Incorrect CC  [Redmine ID: #214058]
		- 20250515@Thomas.Nguyen: Add logic for Special Lic Sub [Redmine ID: #226847]

	Param's Explanation:
		@ScannedMaxId: This parameter is used to output scanned MaxID

    Script:
		DECLARE @output BIGINT
        EXEC bodb_VR2Model.dbo.CTS_GeneralNormalClassification_NormalPool_Get @ScannedMaxId = @output;
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE	@BATCHSIZE						INT 	= 20000;

	DECLARE @FUNCTIONID_REALTIME					TINYINT = 1,
			@FUNCTIONID_SCANTAGGING					TINYINT = 100,
			@FUNCTIONID_SCANSPECIALLICSUBCC			TINYINT = 10;

	DECLARE @SCANTAGGINGTYPE_NOTEXIST				TINYINT = 0,
			@SCANTAGGINGTYPE_EXIST					TINYINT = 1,
			@SCANTAGGINGTYPE_EXISTONLY				TINYINT = 2,
			@SCANSPECIALLICSUBTYPE_NOTEXIST			TINYINT = 0,
			@SCANSPECIALLICSUBTYPE_EXIST			TINYINT = 1;

	DECLARE @GENERAL_LASTSCANNEDID			TINYINT = 3;
	DECLARE @LastScannedID					BIGINT;

	IF	OBJECT_ID('tempdb..#tmpCustomers') IS NOT NULL
	DROP TABLE	#tmpCustomers;

	CREATE TABLE #tmpCustomers(
		Id					BIGINT PRIMARY KEY IDENTITY(1,1),
		CustId				INT UNIQUE NOT NULL,
		IsRealtimeOnly		BIT DEFAULT(0),
		ScanTaggingType  	TINYINT DEFAULT(0),
		ScanSpecialLicSubType		TINYINT
	);

	-- #1: Get Scanned MaxID
	SELECT @ScannedMaxId = MAX(c.ID) FROM dbo.CustomerClassification_NormalPool AS c WITH(NOLOCK);
	SELECT @LastScannedID = CAST([Value] AS BIGINT) FROM dbo.CustomerClassification_Parameter WITH(NOLOCK) WHERE [DataId] = @GENERAL_LASTSCANNEDID;
	
	WAITFOR DELAY '00:00:00.300';

	-- #2: Get top customers by priority
	IF(@ScannedMaxId IS NOT NULL)
	BEGIN
		INSERT INTO #tmpCustomers(CustId, IsRealtimeOnly, ScanTaggingType, ScanSpecialLicSubType)
		SELECT TOP(@BATCHSIZE) c.CustId,
			   CASE WHEN SUM(c.FunctionId) = (COUNT(c.ID) * @FUNCTIONID_SCANTAGGING) THEN 0
					WHEN SUM(CASE WHEN c.FunctionId = @FUNCTIONID_SCANTAGGING THEN @FUNCTIONID_REALTIME ELSE c.FunctionId END) = (COUNT(c.ID) * @FUNCTIONID_REALTIME) THEN 1 
					ELSE 0 END,
			   CASE WHEN SUM(c.FunctionId) = (COUNT(c.CustId) * @FUNCTIONID_SCANTAGGING) THEN @SCANTAGGINGTYPE_EXISTONLY 
					WHEN SUM(CASE WHEN c.FunctionId = @FUNCTIONID_SCANTAGGING THEN @FUNCTIONID_SCANTAGGING ELSE 0 END) > 1 THEN @SCANTAGGINGTYPE_EXIST 
					ELSE @SCANTAGGINGTYPE_NOTEXIST END,
			   CASE WHEN SUM(CASE WHEN c.FunctionId = @FUNCTIONID_SCANSPECIALLICSUBCC THEN @FUNCTIONID_SCANSPECIALLICSUBCC ELSE 0 END) > 1 THEN @SCANSPECIALLICSUBTYPE_EXIST 
					ELSE @SCANSPECIALLICSUBTYPE_NOTEXIST END
		FROM dbo.CustomerClassification_NormalPool AS c WITH(NOLOCK)
		WHERE c.ID <= @ScannedMaxId
			AND NOT EXISTS (SELECT 1 FROM dbo.CustomerClassification AS cc WITH (NOLOCK) WHERE cc.ID > @LastScannedID AND cc.CustId = c.CustId)
		GROUP BY c.CustId
		ORDER BY Min(c.Priority) ASC, Min(c.ID) ASC;
	END

	-- #3: Return dataset
	SELECT CustId			 AS CustId, 
		   IsRealtimeOnly	 AS IsRealtimeOnly,
		   ScanTaggingType   AS ScanTaggingType,
		   ScanSpecialLicSubType AS ScanSpecialLicSubType
	FROM #tmpCustomers AS tmp WITH(NOLOCK);
	
	DROP TABLE #tmpCustomers;
END;
GO
