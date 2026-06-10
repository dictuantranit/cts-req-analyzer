/*<info serverAlias="CTSMain-CTS_Admin" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_CTSJob_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_AD_CTSJob_Get`(
		IN ip_IsAdjust			BIT
	,	IN ip_EnvironmentID		INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20241226@Adam.Tran
		Task:		CTS - Main Service - Extend Functions Scheduler manager [Redmine ID: 215328]
		DB:			CTS_Admin
		Original:

		Revisions: 
			- 20241226@Adam.Tran:   Created
			
		Param's Explanation (filtered by):
	*/
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Job;
    CREATE TEMPORARY TABLE Temp_Job(		
			JobName   			varchar(300)
        ,	GroupName   		varchar(300)
		,	JobType				varchar(300)
		,	APIUrl				varchar(500)
		,	MethodName			varchar(300)
		,	Controller			varchar(300)
		,	IsStartByDefault	TINYINT
		,	IsAdjust			TINYINT
		,	PRIMARY KEY (JobName, GroupName)
    );
	
	INSERT INTO Temp_Job(JobName, GroupName, JobType, APIUrl, MethodName, Controller, IsStartByDefault, IsAdjust)
    SELECT	j.JobName
			, j.GroupName
			, j.JobType
			, j.APIUrl
			, j.MethodName
			, j.Controller
			, j.IsStartByDefault
			, j.IsAdjust
	FROM 	CTS_Admin.CTSJob AS j
	WHERE	j.IsDisable = 0 
		AND j.EnvironmentID = ip_EnvironmentID
		AND (CASE 
				WHEN ip_IsAdjust = 0 THEN j.IsAdjust <> 1
				ELSE 1 = 1
			END);
	
	SELECT	j.JobName
			, j.GroupName
			, j.JobType
			, j.APIUrl
			, j.MethodName
			, j.Controller
			, j.IsStartByDefault
			, j.IsAdjust
	FROM 	Temp_Job AS j;
	
	SELECT 	tr.TriggerName
			, tr.JobName
			, tr.TriggerType
			, tr.IntervalInSecond
			, tr.CronExpression				
	FROM 	CTS_Admin.CTSTrigger as tr
		INNER JOIN Temp_Job AS j ON tr.JobName = j.JobName
	WHERE  tr.IsDisable = 0 
		AND tr.EnvironmentID = ip_EnvironmentID;

END$$

DELIMITER ;