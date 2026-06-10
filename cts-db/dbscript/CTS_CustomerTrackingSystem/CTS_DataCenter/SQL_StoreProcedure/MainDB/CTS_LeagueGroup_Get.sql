/*<info serverAlias="DBCTS-bodb02" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CTS_LeagueGroup_Get]		

AS
/*
	Created: 20240702@Casey.Huynh
	Task : CTS_LeagueGroup_Get 
	DB	 : bodb02

	Revisions:
		- 20240702@Casey.Huynh:	Create [Redmine ID: #206494]		
	
	Params Explaination:	
		
		- SportGroup:
			1: NOT Saba Virtual Sport
			2: Saba Virtual Sport
			
	Example:
		EXEC CTS_LeagueGroup_Get 

*/
BEGIN
	SET NOCOUNT ON;		
	
	SELECT	lg.GroupID
		,	lg.GroupName
		,	lg.SportType
		,	(CASE WHEN lg.GroupID NOT IN (42,74,108,113,122,151) THEN 1 ELSE 2 END) AS SportGroup					
	FROM bodb02.dbo.LeagueGroup AS lg WITH(NOLOCK)
	WHERE lg.IsActive = 1;

END