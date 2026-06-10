/*<info serverAlias="CTSMain-CTS_Admin" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_CTSJob_CheckExist`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_AD_CTSJob_CheckExist`(
		IN ip_JobName 			VARCHAR(300)	
	 ,	IN ip_EnvironmentIDs	VARCHAR(30)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20250122@Adam.Tran
		Task:		CTS - Main Service - Extend Functions Scheduler manager [Redmine ID: 215328]
		DB:			CTS_Admin
		Original:

		Revisions: 
			- 20250122@Adam.Tran:   Created
			
		Param's Explanation (filtered by):
	*/
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Job;
    CREATE TEMPORARY TABLE Temp_Job(		
			JobName   			VARCHAR(300)       
		,	EnvironmentID		INT		
    );
	
	INSERT INTO Temp_Job(JobName, EnvironmentID)
    SELECT	j.JobName			
			, j.EnvironmentID		
	FROM 	CTS_Admin.CTSJob AS j
	WHERE	j.JobName = ip_JobName 		
		AND j.IsDisable = 0
		AND FIND_IN_SET(j.EnvironmentID, ip_EnvironmentIDs);
	
	SELECT	j.JobName		
			, j.EnvironmentID
	FROM 	Temp_Job AS j;	

END$$

DELIMITER ;