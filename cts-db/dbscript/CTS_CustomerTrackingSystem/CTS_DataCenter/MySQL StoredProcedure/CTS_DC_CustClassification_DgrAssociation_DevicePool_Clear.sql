/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_DgrAssociation_DevicePool_Clear`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_DgrAssociation_DevicePool_Clear`(
		IN 	ip_LastScannedID	BIGINT
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
			CALL CTS_DC_CustClassification_DgrAssociation_DevicePool_Clear ();
	*/
	IF ip_LastScannedID IS NOT NULL THEN
		DELETE da
		FROM CTS_DataCenter.DangerousAssociation_DevicePool AS da
		WHERE da.ID <= ip_LastScannedID;
	END IF;

END$$
DELIMITER ;