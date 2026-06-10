/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_Archive`.`CTS_Archive_Log_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_Archive_Log_Insert`(
		ip_LogInfo 	JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220523@Aries.Nguyen
		Task:		Write Log
		DB:			CTS_Archive
        
		Revisions:
			- 	20220523@Aries.Nguyen: Created [Redmine ID: 172561]
            
		Param's Explanation (filtered by):
			-	CALL CTS_Archive.CTS_Archive_Log_Insert ('{"message":"write log","spName":"CTS_DC_CustClassification_PA_InsertRobot","param":"1,2,3,4"}');

	*/	
    INSERT INTO CTS_Archive.CTSLog(LogInfo)
    VALUES (ip_LogInfo); 
END$$
DELIMITER ;