/*<<ignore deploy-info serverAlias="FPSADMIN-FPS_MiddleService" executers="fpsWinService" viewers="" isFunction="0" isNested="0"></info>*/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE FPS_MS_GetDataForMigrate 
	@pageSize INT
AS
/*
	Created: 20200121@Harvey.nguyen
	Task: Get data for migration service
	  DB: FPS_MiddleService
  
	Revisions:
		- 20200121@Harvey: init SPs  (#127512)
		- 20200206@Harvey: remove insert data into completed table  (#128028)

	Param's Explanation:  

	exec FPS_MS_GetDataForMigrate 500
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT TOP (@pageSize)
		TransId
		,SubTransId
		,LoginName
		,SubName
		,TransTime
		,CreatedDate
		,DeviceCode
		,IP
		,ActionName
		,ActionResult
		,UserAgent
		,URL
	INTO #tempTrans
	FROM [uat].[CTSMigrateTrans] mt WITH (NOLOCK)

	DELETE trans
	FROM uat.CTSMigrateTrans trans
		INNER JOIN #tempTrans ttrans on trans.TransId = ttrans.TransId


	SELECT 
		TransId
		,SubTransId
		,LoginName
		,SubName
		,TransTime
		,CreatedDate
		,DeviceCode
		,IP
		,ActionName
		,ActionResult 
		,UserAgent
		,URL
	FROM #tempTrans

	DROP TABLE #tempTrans
END