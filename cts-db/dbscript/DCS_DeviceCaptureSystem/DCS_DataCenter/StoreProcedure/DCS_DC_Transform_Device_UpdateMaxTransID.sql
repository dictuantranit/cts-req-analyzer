/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_Device_UpdateMaxTransID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_Device_UpdateMaxTransID`()
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20250324@Jonathan.Doan
	    Task : Max TransID updated (completed trans), run after transform device service
	    DB: DCS_DataCenter
	    Original:
		 
	    Revisions:
			- 20250324@Jonathan.Doan: Created [Redmine ID: #217768]
		    - 20250327@Jonathan.Doan: Updated WHERE clause to use correct constant [Redmine ID: #222043]
	    Param's Explanation (filtered by):
        
        Example:
			SET sql_safe_updates = 0;
			CALL DCS_DC_Transform_Device_UpdateMaxTransID();
            
            SELECT * FROM DCS_DataCenter.SystemSetting WHERE ID = 103;
	*/
    DECLARE CONST_DEVICETRANSFORM_MAXTRANSACTION07IDCOMPLETED INT DEFAULT 3;
    
    DECLARE lv_MaxTransID BIGINT UNSIGNED;
    
    SELECT MAX(TransID) AS MaxTransID
    INTO lv_MaxTransID
    FROM DCS_DataCenter.Transaction07;
    
    IF(lv_MaxTransID IS NOT NULL AND lv_MaxTransID > 0) THEN
        UPDATE DCS_DataCenter.SystemSetting
        SET VValue = lv_MaxTransID,
			UpdatedTime = NOW()
        WHERE ID = CONST_DEVICETRANSFORM_MAXTRANSACTION07IDCOMPLETED;
    END IF;
    
END$$

DELIMITER ;