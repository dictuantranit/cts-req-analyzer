/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_cts" viewers="" isFunction="0" isNested="0"></info>*/

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE	CTS_Customer_GetReactivated
		@LastScannedDate	DATETIME,
		@NextScannedDate	DATETIME = NULL	
AS
/*
	Creator:	20220310@Long.Luu
	Task:		Get New customer - [Redmine ID: #169761]
	Database:	DBLOG.bodb_CustomerLog
	
	Revisions:
		- 20220310@Long.Luu:Created [Redmine ID: 169761]
		- 20241213@Jonas.Huynh: Job Monitoring [Redmine ID: #214157]

	Developer's Notes:
		

	exec CTS_Customer_GetReactivated @LastScannedDate = '2021-11-30 07:31:08.000', @NextScannedDate = NULL;
		
*/
BEGIN;
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmpReactivatedAccount') IS NOT NULL
		DROP TABLE	#tmpReactivatedAccount;

	CREATE TABLE #tmpReactivatedAccount(
			CustId		INT NOT NULL PRIMARY KEY
		,	LogTime		DATETIME
	);

	IF @NextScannedDate IS NULL
		SET @NextScannedDate = GETDATE();

	INSERT INTO #tmpReactivatedAccount(CustId, LogTime)
	SELECT custid, MAX(LogTime)
	FROM dbo.DBALog_Archive_Dep_Cust_Process WITH(NOLOCK)
	WHERE LogTime > @LastScannedDate
		AND LogTime <= @NextScannedDate
		AND LogId > 0 
		AND [action] = 'REACTIVATION' 
		AND [status] = 'Done'
	GROUP BY CustId;
			
	DELETE t WITH(ROWLOCK)
	FROM #tmpReactivatedAccount AS t
		INNER JOIN DBCUST.CustDB.dbo.Dep_Customer_Archived AS a WITH(NOLOCK) 
			ON t.CustId = a.CustID AND t.LogTime < a.ArchivedDate;

	SELECT CustId, LogTime
	FROM #tmpReactivatedAccount WITH(NOLOCK);

	DROP TABLE	#tmpReactivatedAccount;
END;
GO