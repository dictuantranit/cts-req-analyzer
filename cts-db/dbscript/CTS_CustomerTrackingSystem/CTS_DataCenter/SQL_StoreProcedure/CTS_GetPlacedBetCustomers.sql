USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CTS_GetPlacedBetCustomers]
		@FromDate			DATETIME
	,	@ToDate				DATETIME
AS
/*
	Created: 20200930@Long.Luu
	Task : Get all customers placed bet within a time range
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20200930@Long.Luu: Created [Redmine ID: #142510]
        
	Param's Explanation:
*/
BEGIN
	
	SET NOCOUNT ON;

	SELECT DISTINCT b.custid, b.Username
	FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
	WHERE b.custid <> 0
		AND b.bettype < 19001
		AND b.transdate BETWEEN @FromDate AND @ToDate
		AND b.Currency NOT IN (20,27,28)
		AND b.Username NOT LIKE '%Cashout%'
		AND b.BetFrom NOT IN ('p','m','w','0','3','6');
END;

/*<info serverAlias="DBCTS-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/