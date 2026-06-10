/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_DgrAssociation_DevicePool_Insert`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_DgrAssociation_DevicePool_Insert`(
		IN 	ip_CustInfo 		JSON
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20241203@Thomas.Nguyen
		Task:	 	
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20241203@Thomas.Nguyen: 	Created [Redmine ID: #214353]

		Example:
			CALL CTS_DC_CustClassification_DgrAssociation_DevicePool_Insert (@ip_CustInfo:='[{"CTSCustID":1275,"DCSDeviceID":0.1419399977},{"CTSCustID":1277,"DCSDeviceID":0.7015600204}]');
	*/

	INSERT IGNORE INTO CTS_DataCenter.DangerousAssociation_DevicePool(CTSCustID, DCSDeviceID)
    SELECT	tmp.CTSCustID
		,	tmp.DCSDeviceID
    FROM JSON_TABLE(ip_CustInfo,
                        "$[*]" COLUMNS (CTSCustID          	BIGINT UNSIGNED		PATH "$.CTSCustID"
									,	DCSDeviceID			BIGINT				PATH "$.DCSDeviceID"                              
                                )) AS tmp;

END$$
DELIMITER ;