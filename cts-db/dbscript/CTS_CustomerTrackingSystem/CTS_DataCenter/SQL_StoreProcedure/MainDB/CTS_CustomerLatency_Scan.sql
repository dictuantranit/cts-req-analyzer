/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE dbo.CTS_CustomerLatency_Scan
		@FromCustID			INT
	,	@ToCustID			INT
	,	@BatchSize			INT = 500
AS
/*
	Created: 20250416@Casey.Huynh
	Task : CTS - CustomerLatency - Get CustID 
	DB	 : bodb02

	Revisions:
		- 20250416@Casey.Huynh: Created [Redmine ID: #223443]

	Param's Explanation (filtered by):		
					 
	Example:
		exec CTS_CustomerLatency_Scan @FromCustID = 1000, @ToCustID = 12000, @BatchSize=1000
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT TOP(@BatchSize) 
			c.CustID
		,	c.RepUpdateTime
	FROM bodb02.dbo.Customer AS c WITH(NOLOCK)
	WHERE RoleID BETWEEN 1 AND 4
		AND c.CustID > @FromCustID
		AND c.CustID <= @ToCustID
	ORDER BY c.CustID ASC;

END;
GO
