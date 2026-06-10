/*<info serverAlias="DBONUSER-ON_USER" executers="bodbSPUNet" isFunction="0" isNested="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CTS_RobotUserStatus_Get] 
		 @custId				INT
AS
/*
	Created: 20191225@HarveyNguyen
	Task : Get robot user status
	DB: [ON_USER]
	Original:

	Revisions:
		- 20191225@Harvey:	Initial - [Redmine: #126079]
        - 20200619@Harvey:	change condition for detect robot - [Redmine: 133935]
        - 20201112@Lex:	Update rule, remove upline from checking - [Redmine: 145006]

	Param's Explanation:

	EXEC CTS_RobotUserStatus_Get 1397
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @isRobotUser BIT = 0;

	CREATE TABLE #tempCustomer (
		CustId INT
		,Srecommend INT
		,Mrecommend INT
		,Recommend INT
		)

	INSERT INTO #tempCustomer (
		CustId
		,Srecommend
		,Mrecommend
		,Recommend
		)
	SELECT cust.custid
		,cust.srecommend
		,cust.mrecommend
		,cust.recommend
	FROM bodb02.dbo.Customer cust WITH (NOLOCK)
	WHERE cust.custid = @custId

	IF EXISTS (
			SELECT 1
			FROM #tempCustomer cau
				INNER JOIN dbo.RobotUsers ru WITH (NOLOCK) ON cau.CustId = ru.custid
			WHERE ru.counter >= 10
			)
		SET @isRobotUser = 1;

	SELECT @custId 'CustId'
		,@isRobotUser 'IsRobotUser'

	DROP TABLE #tempCustomer;


END;
GO