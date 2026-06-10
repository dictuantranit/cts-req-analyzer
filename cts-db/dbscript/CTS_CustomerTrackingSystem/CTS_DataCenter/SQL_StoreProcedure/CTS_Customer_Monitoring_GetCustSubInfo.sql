/*<info serverAlias="DBCTS-bodb02" executers="bodbSPUNet" viewers="" isFunction="0" isNested="0"></info>*/

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE CTS_Customer_Monitoring_GetCustSubInfo
		@LastCustSubId	INT = 0
	,	@RowSize		INT = 500
	,	@MaxScannedDate	DATETIME
AS
/*
	Creator:	20210115@CaseyHuynh
	Task:		Get customer - [Redmine: #148849]
	Database:	DBCTS.bodb02
	
	Revisions:
		- 20211210@Harvey:		Initial - [Redmine: #165607]
		- 20230307@Jonas.Huynh:	Enhance monitoring customer service [Redmine:#183278]

	Developer's Notes:

		exec [dbo].[CTS_Customer_Monitoring_GetCustSubInfo] 27, 500, '2003-10-23 21:06:00'
		
*/
BEGIN;
	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#tmpNewCustSub') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpNewCustSub;
	END;

	CREATE TABLE #tmpNewCustSub (
			CustID			INT	
		,	CustSubID		INT
		,	UserName		VARCHAR(30)
		,	CreatedDate		DATETIME	
		,	PRIMARY KEY		(CustID,CustSubID)		
	);

	INSERT INTO #tmpNewCustSub(CustID, CustSubID, UserName, CreatedDate)
	SELECT	TOP (@RowSize)
			sub.custid
		,	sub.subaccid
		,	sub.username
		,	sub.createdate			
	FROM dbo.custSub sub WITH (NOLOCK)
	WHERE sub.subaccid > @LastCustSubId
		AND sub.createdate <= @MaxScannedDate
	ORDER BY sub.subaccid ASC;

	SELECT MAX(CustSubID) AS MaxScannedCustSubID
	FROM #tmpNewCustSub;

	SELECT	CustID
		,	CustSubID
		,	UserName
		,	CreatedDate
	FROM #tmpNewCustSub;
	
END;
GO