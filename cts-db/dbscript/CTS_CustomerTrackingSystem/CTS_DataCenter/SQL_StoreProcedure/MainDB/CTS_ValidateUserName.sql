/*<info serverAlias="DBCTS-bodb02" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CTS_ValidateUsername]		
	@UsernameList	VARCHAR(MAX) = ''
AS
/*
	Created: 20240702@Casey.Huynh
	Task : CTS_LeagueGroup_Get 
	DB	 : bodb02

	Revisions:
		- 20240702@Casey.Huynh:	Create [Redmine ID: #206494]		
	
	Params Explaination:	
		
			
	Example:
		EXEC CTS_ValidateUsername @UsernameList = '305RM,922SD,832NSD,10938DUETO'
*/
BEGIN
	SET NOCOUNT ON;
	
	IF	OBJECT_ID('tempdb..#tmpUsername') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpUsername;
	END;

	CREATE TABLE	#tmpUsername(
		UserName	VARCHAR(50) 	
	);

	IF @UserNameList <> ''
	BEGIN
		INSERT INTO #tmpUsername(UserName)
		SELECT ssk.value FROM STRING_SPLIT (@UserNameList, ',') AS ssk;
	END;

	SELECT	cus.UserName
		,	cus.CustId
	FROM bodb02.dbo.Customer AS cus WITH(NOLOCK)
		INNER JOIN #tmpUsername AS tmp WITH(NOLOCK) ON cus.Username = tmp.Username;
	
END