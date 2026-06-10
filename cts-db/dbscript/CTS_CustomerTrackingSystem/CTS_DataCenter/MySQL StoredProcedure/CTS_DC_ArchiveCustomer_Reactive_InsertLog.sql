/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_ArchiveCustomer_Reactive_InsertLog`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_ArchiveCustomer_Reactive_InsertLog`(
		IN ip_LastScanTime 		DATETIME(3)
	,	IN ip_RequestTime 		DATETIME(3)
    ,	IN ip_MaxLogTime 		DATETIME(3)
    ,	IN ip_CustInfoTime 		DATETIME(3)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20241901@Jonas.Huynh
		Task :		Reactive Customer Log
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20241901@Jonas.Huynh: Created  [RedmineID: #199963]

		Param's Explanation:
        
	*/ 
    DECLARE lv_CurrentTime 	DATETIME DEFAULT CURRENT_TIME();
    
    INSERT INTO CTS_DataCenter.ReactiveCustomer_Log(LastScanTime, RequestTime, MaxLogTime, CustInfoTime, CreatedTime, CreatedDate) 
	SELECT ip_LastScanTime, ip_RequestTime, ip_MaxLogTime, ip_CustInfoTime, lv_CurrentTime, lv_CurrentTime;
    
END$$
DELIMITER ;