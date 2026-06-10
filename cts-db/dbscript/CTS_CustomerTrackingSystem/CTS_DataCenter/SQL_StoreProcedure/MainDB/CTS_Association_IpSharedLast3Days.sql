/*<info serverAlias="DBCTS-bodb02" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_Association_IpSharedLast3Days]
		@ListCustId				VARCHAR(MAX) = ''

AS
/*
	Created: 20230314@Long.Luu
	Task : CTS - Association - Get Association by sharing IP within last 3 days
	DB	 : bodb02

	Revisions:
		- 20230314@Long.Luu:	Created [Redmine ID: #184771]
		- 20230602@Long.Luu:	Add new agent as internal account [Redmine ID: #188554]
        - 20231024@Long.Luu: 	Add Agent HITRM & WINRM as internal account [Redmine ID: #195355]
        - 20231207@Long.Luu: 	Add Agent M999RM00 as internal account [Redmine ID: #197915]
		- 20250121@Thomas.Nguyen: Exclude 2 IP [Redmine ID: #217111]
        - 20250923@Long.Luu: 	Add Agents ORI6RM & ORI20RM  as internal account [Redmine ID: #239117]

	Params Explaination:

	Example:
		EXECUTE [dbo].[CTS_Association_IpSharedLast3Days] @ListCustId = '1,2,3';
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @lv_ProcessingDate	DATE;

	IF	OBJECT_ID('tempdb..#tmp_Last3Days') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp_Last3Days;
	END;

	CREATE TABLE	#tmp_Last3Days (
			EventDate		DATE PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmp_Bettrans') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp_Bettrans;
	END;

	CREATE TABLE	#tmp_Bettrans (
			CustID			INT
		,	TransDate		DATE
		,	IP				VARCHAR(45)
	);

	IF	OBJECT_ID('tempdb..#tmp_CustID') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp_CustID;
	END;

	CREATE TABLE	#tmp_CustID (
			CustID			INT PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmp_CustID_IP') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp_CustID_IP;
	END;

	CREATE TABLE	#tmp_CustID_IP (
			CustID			INT
		,	IP				VARCHAR(45)
	);

	CREATE CLUSTERED INDEX #CIX_tmp_CustID_IP_IP ON #tmp_CustID_IP (
		IP, CustID
	);

	IF	OBJECT_ID('tempdb..#tmp_Association') IS NOT NULL
	BEGIN
		DROP TABLE	#tmp_Association;
	END;

	CREATE TABLE	#tmp_Association (
			CustID1			INT
		,	CustID2			INT
		,	IP				VARCHAR(45)
	);

	INSERT INTO #tmp_CustID (CustID)
	SELECT ssk.value FROM STRING_SPLIT(@ListCustId, ',') ssk;

	INSERT INTO	#tmp_Last3Days (EventDate)
	SELECT	tally.EventDate
	FROM	(
		SELECT	[NoDays] = 4
	) cnt
	CROSS APPLY	(
		SELECT	TOP(cnt.NoDays)
				[EventDate] = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, DATEADD(DAY, -3, GETDATE()))
		FROM		(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
		CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
	) tally;

	INSERT INTO #tmp_Bettrans (CustID,TransDate,IP)
	SELECT t.CustID, CAST(b.transdate AS DATE), b.IP
	FROM #tmp_CustID AS t
		INNER JOIN dbo.bettrans AS b WITH(NOLOCK) ON b.CustID = t.CustID	
		INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) on b.custid = c.custid	
	WHERE b.srecommend NOT IN (41430709) 
		AND b.mrecommend NOT IN (27899314,11656504,12146012) 
		AND b.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
		AND b.username NOT LIKE '%CashOut' 
		AND c.site NOT IN ('Nextbet','9wickets','9wsports')
		AND b.currency NOT IN (20,27,28)
		AND b.IP IS NOT NULL
		AND b.IP NOT IN ('127.0.0.1','16.162.136.5');

	CREATE CLUSTERED INDEX #CIX_tmp_Bettrans ON #tmp_Bettrans (
		TransDate, CustID, IP
	);

	WHILE EXISTS(SELECT 1 FROM #tmp_Last3Days WITH(NOLOCK))
		BEGIN
			SELECT TOP 1 @lv_ProcessingDate = EventDate FROM #tmp_Last3Days WITH(NOLOCK);

			TRUNCATE TABLE #tmp_CustID_IP;

			INSERT INTO #tmp_CustID_IP(CustID, IP)
			SELECT DISTINCT CustID, IP
			FROM #tmp_Bettrans WITH(NOLOCK)	
			WHERE TransDate = @lv_ProcessingDate;

			INSERT INTO #tmp_Association(CustID1, CustID2, IP)
			SELECT	CASE WHEN t1.CustID > t2.CustID THEN t2.CustID ELSE t1.CustID END AS CustID1
				,	CASE WHEN t1.CustID > t2.CustID THEN t1.CustID ELSE t2.CustID END AS CustID2
				,	t1.IP
			FROM #tmp_CustID_IP AS t1 WITH(NOLOCK)
				INNER JOIN #tmp_CustID_IP AS t2 WITH(NOLOCK) ON t1.IP = t2.IP
			WHERE t1.CustID <> t2.CustID;

			DELETE FROM #tmp_Last3Days WHERE EventDate = @lv_ProcessingDate;
		END;

	SELECT DISTINCT CustID1, CustID2, IP
	FROM #tmp_Association WITH(NOLOCK);
	
	DROP TABLE #tmp_Bettrans;
	DROP TABLE #tmp_CustID;
	DROP TABLE #tmp_CustID_IP;
	DROP TABLE #tmp_Association;
END;

GO