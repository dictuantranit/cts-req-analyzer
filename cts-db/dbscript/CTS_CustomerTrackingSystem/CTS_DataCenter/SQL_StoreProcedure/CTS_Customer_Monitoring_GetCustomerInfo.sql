/*<info serverAlias="DBCTS-bodb02" executers="bodbSPUNet" viewers="" isFunction="0" isNested="0"></info>*/

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE CTS_Customer_Monitoring_GetCustomerInfo
		@LastCustId		INT = 0
	,	@RowSize		INT = 500
	,	@MaxScannedDate	DATETIME
AS
/*
	Creator:	20211210@Harvey.Nguyen
	Task:		Get customer for monitoring service - [Redmine ID: #165607]
	Database:	DBCTS.bodb02
	
	Revisions:
		- 20211210@Harvey:		Initial - [Redmine: #165607]
		- 20230307@Jonas.Huynh:	Enhance monitoring customer service [Redmine:#183278]
	Developer's Notes:
		

	exec [dbo].[CTS_Customer_Monitoring_GetCustomerInfo] 27, 500, '2023-03-07 06:00:23.000'
		
*/
BEGIN;
	SET NOCOUNT ON;
	IF	OBJECT_ID('tempdb..#tmpNewCust') IS NOT NULL
		DROP TABLE	#tmpNewCust;

	CREATE TABLE #tmpNewCust(
		CustId			INT NOT NULL
	,	UserName		VARCHAR(30)
	,	CreatedDate		SMALLDATETIME
	,	RoleID			TINYINT
	,	PRIMARY KEY (CustId)
	);

	INSERT INTO #tmpNewCust(CustID, UserName, CreatedDate, RoleID)
	SELECT	TOP (@RowSize)
			c.custid
		,	c.username
		,	c.creatdate
		,	c.roleid
	FROM	bodb02.dbo.Customer AS c WITH(NOLOCK)
	WHERE  c.custid > @LastCustId 
		AND	c.creatdate <= @MaxScannedDate
	ORDER BY c.custid ASC;

	SELECT MAX(CustId) AS MaxScannedCustID
	FROM #tmpNewCust;

	SELECT	CustID
		,	UserName
		,	RoleID
		,	CreatedDate
	FROM #tmpNewCust
	WHERE RoleID BETWEEN 1 AND 4;

END;
GO