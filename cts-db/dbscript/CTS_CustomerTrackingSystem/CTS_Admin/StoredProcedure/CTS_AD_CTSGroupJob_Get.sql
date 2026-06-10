/*<info serverAlias="CTSMain-CTS_Admin" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_CTSGroupJob_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_AD_CTSGroupJob_Get`()
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20250103@Adam.Tran
		Task:		CTS - Main Service - Extend Functions Scheduler manager [Redmine ID: 215328]
		DB:			CTS_Admin
		Original:

		Revisions: 
			- 20250103@Adam.Tran:   Created
			
		Param's Explanation (filtered by):
	*/
			
	SELECT 	gj.GroupID
			, gj.GroupName				
	FROM 	CTS_Admin.CTSGroupJob as gj;
		
END$$

DELIMITER ;