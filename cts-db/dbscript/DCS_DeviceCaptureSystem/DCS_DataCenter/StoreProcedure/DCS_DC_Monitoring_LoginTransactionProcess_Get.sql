/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `DCS_DataCenter`.`DCS_DC_Monitoring_LoginTransactionProcess_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DataCenter`.`DCS_DC_Monitoring_LoginTransactionProcess_Get`(
	 OUT op_RecordNumber	BIGINT
) 
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20240102@Jonas.Huynh
		Task:  Return customer categories
		DB: CTS_DataCenter
		Original:
		Revisions:
			- 20240102@Jonas.Huynh: Creator [RedmineID: #197999]
            
		Param's Explanation (filtered by):    
			CALL DCS_DC_Monitoring_LoginTransactionProcess_Get(@op_RecordNumber)
	*/  
    
	SELECT 	COUNT(1)
	INTO	op_RecordNumber
    FROM 	DCS_DataCenter.AccountLastLoginTimeProcess;

END$$
DELIMITER ;