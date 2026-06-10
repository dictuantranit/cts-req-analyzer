/*<info serverAlias="DBUserLog-LogCDB" executers="bodbSPUNet" viewers="" isFunction="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CTS_RobotImperva_Get]
		@LastLogID		BIGINT
	,	@MaxLogID		BIGINT	OUTPUT
AS
/*
	Creator:	20230315@victoria.le
	Task:	 	Robot Imperva - Get Data

	 Revisions:
		- 20230315@Victoria.le: 	Initial Writing  [Redmine ID: #184773]
								
	Example:
		DECLARE @MaxLogID BIGINT
		EXEC CTS_RobotImperva_Get @LastLogID = 0, @MaxLogID = @MaxLogID OUTPUT
		SELECT @MaxLogID
*/
BEGIN
	SET NOCOUNT ON

	IF	OBJECT_ID('tempdb..#tmp_CustLoginLog_ABP') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp_CustLoginLog_ABP;
	END;

	CREATE TABLE #tmp_CustLoginLog_ABP
	(
			LogID			BIGINT	PRIMARY KEY
		,	CustID			INT
		,	Platform		SMALLINT
		,	CreateTime		DATETIME
		,	ActionMode		VARCHAR(20)
	);

	INSERT INTO #tmp_CustLoginLog_ABP
	(
			LogID
		,	CustID
		,	Platform
		,	CreateTime
		,	ActionMode	
	)
	SELECT	logid 
		,	Custid	
		,	Platform
		,	CreateTime
		,	ActionMode	
	FROM [LogCDB].[dbo].[CustLoginLog_ABP] WITH (NOLOCK)
	WHERE logid > @LastLogID;

	IF (@@ROWCOUNT = 0)
		BEGIN
			SET @MaxLogID = ISNULL(@LastLogID,0);
		END
	ELSE
		BEGIN
			SELECT @MaxLogID = MAX(LogID)
			FROM #tmp_CustLoginLog_ABP;
		END;

	WITH CTE_block AS
	(
		SELECT	LogID
			,	CustID
			,	Platform
			,	CreateTime
			,	ROW_NUMBER() OVER (PARTITION BY CustID,Platform ORDER BY LogID DESC) AS RowNumber 
		FROM #tmp_CustLoginLog_ABP
		WHERE ActionMode = 'block'
	)
	SELECT	LogID
		,	CustID
		,	Platform
		,	CreateTime
	FROM CTE_block
	WHERE RowNumber = 1;

END