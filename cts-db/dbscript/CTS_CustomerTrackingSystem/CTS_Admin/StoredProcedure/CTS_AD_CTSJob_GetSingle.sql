/*<info serverAlias="CTSMain-CTS_Admin" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_CTSJob_GetSingle`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_AD_CTSJob_GetSingle`(
		IN ip_JobName 		VARCHAR(300)
	 ,	IN ip_GroupName 	VARCHAR(300)
	 ,	IN ip_EnvironmentID	INT
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
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Job;
    CREATE TEMPORARY TABLE Temp_Job(		
			JobName   			VARCHAR(300)
        ,	GroupName   		VARCHAR(300)			
		,	JobType				VARCHAR(300)
		,	APIUrl				VARCHAR(500)
		,	MethodName			VARCHAR(300)
		,	Controller			VARCHAR(300)
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
	WHERE	j.JobName = ip_JobName 
		AND j.GroupName = ip_GroupName 
		AND j.IsDisable = 0
		AND j.EnvironmentID = ip_EnvironmentID;
	
	SELECT	j.JobName
			, j.GroupName
			, ip_EnvironmentID AS EnvironmentID
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
	WHERE tr.IsDisable = 0
		AND tr.EnvironmentID = ip_EnvironmentID;

END$$

DELIMITER ;