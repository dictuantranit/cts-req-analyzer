/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_Account_Reset`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_Account_Reset`()
SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240419@Jonathan.Doan
		Task:		Clear all data archive to re-cook
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20240426@Jonathan.Doan: Created [Redmine ID: #203691]
		Param's Explanation (filtered by):
			CALL DCS_DC_ArchiveData_Account_Reset();
	*/
    
	DELETE FROM DCS_DataCenter.ArchiveAccount_NotUsed;
	DELETE FROM DCS_DataCenter.ArchiveAssociation_NotUsed;
	DELETE FROM DCS_DataCenter.ArchiveDevice_NotUsed;
	DELETE FROM DCS_DataCenter.ArchiveDeviceCode_NotUsed;
	DELETE FROM DCS_DataCenter.ArchiveAccountIP_NotUsed;
	DELETE FROM DCS_DataCenter.ArchiveAccountDevice_NotUsed;
	DELETE FROM DCS_DataCenter.ArchiveAccountFingerprint_NotUsed;
    
END$$

DELIMITER ;
