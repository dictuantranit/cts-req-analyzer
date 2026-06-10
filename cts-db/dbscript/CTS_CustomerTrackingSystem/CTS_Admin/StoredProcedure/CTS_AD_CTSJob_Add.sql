/*<info serverAlias="CTSMain-CTS_Admin" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_CTSJob_Add`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_AD_CTSJob_Add`(
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

	
	INSERT IGNORE INTO CTS_Admin.CTSJob(JobName, GroupName, EnvironmentID, JobType, APIUrl, MethodName, Controller, IsStartByDefault, IsAdjust)
	SELECT  js.JobName
		,	js.GroupName
		,	js.EnvironmentID
        ,	js.JobType
        ,	js.APIUrl
		,	js.MethodName
		,	js.Controller
		,	js.IsStartByDefault
		,	js.IsAdjust
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
						)
				) AS js;
				
	INSERT IGNORE INTO CTS_Admin.CTSTrigger (TriggerName, JobName, EnvironmentID, TriggerType, IntervalInSecond, CronExpression)
	SELECT  js.TriggerName
		,	js.JobName
		,	js.EnvironmentID
        ,	js.TriggerType
        ,	js.IntervalInSecond
		,	js.CronExpression		
	FROM JSON_TABLE(ip_JobTrigger,
					 "$[*]" COLUMNS(
								TriggerName				VARCHAR(300) PATH "$.TriggerName" 
							,	JobName					VARCHAR(300) PATH "$.JobName" 
							,	EnvironmentID			INT	PATH "$.EnvironmentID"
                            ,	TriggerType				VARCHAR(300) PATH "$.TriggerType"                            
							,	IntervalInSecond		INT PATH "$.IntervalInSecond" 
							,	CronExpression			varchar(300) PATH "$.CronExpression" 										
						)
				) AS js;
				

END$$

DELIMITER ;