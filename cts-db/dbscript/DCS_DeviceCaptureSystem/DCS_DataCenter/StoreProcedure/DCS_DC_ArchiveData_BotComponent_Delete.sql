/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_BotComponent_Delete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_BotComponent_Delete`(
	ip_RetentionDays INT
)
    SQL SECURITY INVOKER
sp:BEGIN
	/*
		Created:	20230807@Jonathan.Doan
		Task:		Delete BotComponent according to RetentionDays
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20230807@Jonathan.Doan: Created [Redmine ID: #191960]
            
		Param's Explanation (filtered by):

		Example:
			CALL DCS_DC_ArchiveData_BotComponent_Delete(7);
	*/ 
    
    DECLARE lv_LastDate DATE DEFAULT CURRENT_DATE() - INTERVAL ip_RetentionDays DAY;
    
    DELETE FROM DCS_DataCenter.BotComponent
    WHERE ModifiedDate <= lv_LastDate;
END$$

DELIMITER ;