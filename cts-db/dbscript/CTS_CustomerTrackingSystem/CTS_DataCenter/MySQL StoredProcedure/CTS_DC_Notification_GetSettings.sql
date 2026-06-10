/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Notification_GetSettings`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Notification_GetSettings`(
		IN 	ip_UserID 			INT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	2020106@Long.Luu
		Task:		Get Notification Settings (On/Off) [Redmine ID: #142414]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 2020106@Long.Luu: Created [Redmine ID: #142414]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
        
		Param's Explanation (filtered by):
        
			CALL CTS_DC_Notification_GetSettings(8);
	*/
    
    SELECT DISTINCT p.FunctionID, p.FunctionName, p.IsTurnedOnNotification
    FROM CTS_DataCenter.CTSUserPermission AS p
    WHERE p.UserID = ip_UserID
		AND p.GrantedTo IS NULL;

END$$

DELIMITER ;