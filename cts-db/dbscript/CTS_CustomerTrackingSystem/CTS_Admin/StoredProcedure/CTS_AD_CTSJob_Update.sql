/*<info serverAlias="CTSMain-CTS_Admin" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_CTSJob_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_AD_CTSJob_Update`(
	IN ip_JobTrigger	JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20250102@Adam.Tran
		Task:		CTS - Main Service - Extend Functions Scheduler manager [Redmine ID: 215328]
		DB:			CTS_Admin
		Original:

		Revisions: 
			- 20250102@Adam.Tran:   Created
			
		Param's Explanation (filtered by):
	*/

	DROP TEMPORARY TABLE IF EXISTS Temp_JobTrigger;
    CREATE TEMPORARY TABLE Temp_JobTrigger(		
			JobName   			VARCHAR(300)
        ,	GroupName   		VARCHAR(300)
		,	EnvironmentID		INT
		,	JobType				VARCHAR(300)
		,	APIUrl				VARCHAR(500)
		,	MethodName			VARCHAR(300)
		,	Controller			VARCHAR(300)
		,	IsStartByDefault	TINYINT
		,	IsAdjust			TINYINT
		,	TriggerName			VARCHAR(300)
		,	TriggerType			VARCHAR(300)
		,	IntervalInSecond	INT
		,	CronExpression		VARCHAR(300)
    );	
	
	INSERT INTO Temp_JobTrigger(JobName, GroupName, EnvironmentID, JobType, APIUrl, MethodName, Controller, IsStartByDefault, IsAdjust, TriggerName, TriggerType, IntervalInSecond, CronExpression)
	SELECT  js.JobName
		,	js.GroupName
		,	js.EnvironmentID
        ,	js.JobType
        ,	js.APIUrl
		,	js.MethodName
		,	js.Controller
		,	js.IsStartByDefault
		,	js.IsAdjust
		,	js.TriggerName
		,	js.TriggerType
		,	js.IntervalInSecond
		,	js.CronExpression
	FROM JSON_TABLE(ip_JobTrigger,
					 "$[*]" COLUMNS(
								JobName				VARCHAR(300) PATH "$.JobName" 
							,	GroupName			VARCHAR(300) PATH "$.GroupName" 
							,	EnvironmentID		INT	PATH "$.EnvironmentID" 
                            ,	JobType				VARCHAR(300) PATH "$.JobType"
                            ,	APIUrl				VARCHAR(300) PATH "$.ApiUrl" 
							,	MethodName			VARCHAR(300) PATH "$.MethodName" 
							,	Controller			VARCHAR(300) PATH "$.Controller" 
							,	IsStartByDefault	TINYINT PATH "$.IsStartByDefault"
							,	IsAdjust			TINYINT PATH "$.IsAdjust"
							,	TriggerName			VARCHAR(300) PATH "$.TriggerName" 
							,	TriggerType			VARCHAR(300) PATH "$.TriggerType" 
							,	IntervalInSecond	INT	PATH "$.IntervalInSecond" 
							,	CronExpression		varchar(300) PATH "$.CronExpression" 		
						)
				) AS js;
				
	UPDATE CTS_Admin.CTSJob AS js
	INNER JOIN Temp_JobTrigger AS tempJs ON js.JobName = tempJs.JobName 
		AND js.GroupName = tempJs.GroupName
		AND js.EnvironmentID = tempJs.EnvironmentID
	SET 
		  js.JobType = tempJs.JobType
		, js.APIUrl = tempJs.APIUrl
		, js.MethodName = tempJs.MethodName
		, js.Controller = tempJs.Controller
		, js.IsStartByDefault = tempJs.IsStartByDefault
		, js.IsAdjust = tempJs.IsAdjust;
		
	UPDATE CTS_Admin.CTSTrigger AS tr
	INNER JOIN Temp_JobTrigger AS tempTr ON tr.TriggerName = tempTr.TriggerName 
		AND tr.JobName = tempTr.JobName
		AND tr.EnvironmentID = tempTr.EnvironmentID
	SET 
		  tr.TriggerType = tempTr.TriggerType
		, tr.IntervalInSecond = tempTr.IntervalInSecond
		, tr.CronExpression = tempTr.CronExpression;
	

END$$

DELIMITER ;