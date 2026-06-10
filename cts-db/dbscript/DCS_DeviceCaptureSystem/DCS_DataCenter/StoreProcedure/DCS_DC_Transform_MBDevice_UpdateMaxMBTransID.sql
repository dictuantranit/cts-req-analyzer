/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBDevice_UpdateMaxMBTransID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBDevice_UpdateMaxMBTransID`()
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20250812@Jonathan.Doan
	    Task : Max TransID updated (completed trans), run after transform device service
	    DB: DCS_DataCenter
	    Original:
		 
	    Revisions:
			- 20250812@Jonathan.Doan: Created [Redmine ID: #217768]
	    Param's Explanation (filtered by):
        
        Example:
			SET sql_safe_updates = 0;
			CALL DCS_DC_Transform_MBDevice_UpdateMaxMBTransID();

            SELECT * FROM DCS_DataCenter.SystemSetting WHERE ID = 4;
	*/
    DECLARE CONST_MBDEVICETRANSFORM_MAXMBTRANSACTION07IDCOMPLETED INT DEFAULT 4;
    
    DECLARE lv_MaxTransID BIGINT UNSIGNED;
    
    SELECT MAX(ID) AS MaxTransID
    INTO lv_MaxTransID
    FROM DCS_DataCenter.MBTransaction07;
    
    IF(lv_MaxTransID IS NOT NULL AND lv_MaxTransID > 0) THEN
        UPDATE DCS_DataCenter.SystemSetting
        SET VValue = lv_MaxTransID,
			UpdatedTime = NOW()
        WHERE ID = CONST_MBDEVICETRANSFORM_MAXMBTRANSACTION07IDCOMPLETED;
    END IF;
    
END$$

DELIMITER ;