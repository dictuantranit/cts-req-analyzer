/*<info serverAlias="CTSMain-CTS_Admin" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_CTSJob_Delete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_AD_CTSJob_Delete`(
		IN ip_JobName   			VARCHAR(300)
	,	IN ip_GroupName  			VARCHAR(300)
	,	IN ip_EnvironmentID			INT
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
	
	UPDATE CTS_Admin.CTSJob as j
	SET j.IsDisable = TRUE
	WHERE j.JobName = ip_JobName 
		AND j.GroupName = ip_GroupName 
		AND j.EnvironmentID = ip_EnvironmentID;
		
	UPDATE CTS_Admin.CTSTrigger as tr
	SET tr.IsDisable = TRUE
	WHERE tr.JobName = ip_JobName 		
		AND tr.EnvironmentID = ip_EnvironmentID;				

END$$

DELIMITER ;