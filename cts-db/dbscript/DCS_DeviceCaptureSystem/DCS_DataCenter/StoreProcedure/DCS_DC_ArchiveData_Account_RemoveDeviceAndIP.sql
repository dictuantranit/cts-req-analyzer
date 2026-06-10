/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_Account_RemoveDeviceAndIP`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_Account_RemoveDeviceAndIP`()
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20211209@Aries.Nguyen
		Task :		Archive single device for customer inactive in last 6 months
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 	20211209@Aries.Nguyen: Created [Redmine ID: #165168]
		Param's Explanation (filtered by):	
			
	*/
    DECLARE CONS_SysID_BatchSizeDevice 	INT DEFAULT 19;
	DECLARE CONS_SysID_BatchSizeIP 		INT DEFAULT 20;
    
    DECLARE lv_DateValid			DATE DEFAULT DATE_SUB(NOW(), INTERVAL 4 MONTH);
    DECLARE lv_BatchSizeDevice 		INT;
    DECLARE lv_BatchSizeIP 			INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN 
        GET DIAGNOSTICS CONDITION 1 @errCode = RETURNED_SQLSTATE, @errMsg = MESSAGE_TEXT;
        INSERT INTO CTS_DataCenter.Adhoc_StoredProcedureExecError(StoredProcedureName, ErrCode, ErrMsg, ErrDate, ErrDateTime)
        SELECT 'DCS_DC_ArchiveData_Account_RemoveDeviceAndIP', @errCode, @errMsg, NOW(), NOW();
        
		UPDATE CTS_DataCenter.SystemEventStatus 
		SET Status = 'Stop' 
		WHERE EventName = 'EV_DCS_DataCenter_Account_RemoveDeviceAndIP' ;
    END;
    
    SELECT VValue
	INTO lv_BatchSizeDevice
	FROM DCS_DataCenter.SystemSetting
	WHERE ID = CONS_SysID_BatchSizeDevice; 
    
    SELECT VValue
	INTO lv_BatchSizeIP
	FROM DCS_DataCenter.SystemSetting
	WHERE ID = CONS_SysID_BatchSizeIP; 
    
    IF NOT EXISTS (SELECT 1 FROM DCS_DataCenter.AccountDevice WHERE LastTransDate < lv_DateValid) 
		AND  NOT EXISTS (SELECT 1 FROM DCS_DataCenter.AccountIP WHERE LastTransDate < lv_DateValid) THEN
		LEAVE sp;
	END IF;
    
    DELETE 
    FROM DCS_DataCenter.AccountDevice
    WHERE LastTransDate < lv_DateValid
    LIMIT lv_BatchSizeDevice;
    
    DELETE 
    FROM DCS_DataCenter.AccountIP
    WHERE LastTransDate < lv_DateValid
    LIMIT lv_BatchSizeIP;
END$$
DELIMITER ;