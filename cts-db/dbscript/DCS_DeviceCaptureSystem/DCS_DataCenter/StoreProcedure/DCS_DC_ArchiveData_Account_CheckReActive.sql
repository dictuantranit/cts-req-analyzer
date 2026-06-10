/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_Account_CheckReActive`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_Account_CheckReActive`(
)
SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240419@Jonathan.Doan
		Task:		Recheck Account before archive
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20240419@Jonathan.Doan: Created [Redmine ID: #203691]
		Param's Explanation (filtered by):
			CALL DCS_DC_ArchiveData_Account_CheckReActive();
	*/
    DECLARE CONST_SYSTEM_ARCHIVE_ACCOUNTARCHIVECUTOFFDATE	INT DEFAULT 4963735;
    DECLARE lv_AccountArchiveCutoffDate  	DATE;
    
    SET lv_AccountArchiveCutoffDate = (SELECT DATE(VValue) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_SYSTEM_ARCHIVE_ACCOUNTARCHIVECUTOFFDATE);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AccountReActived;
    DROP TEMPORARY TABLE IF EXISTS Temp_DeviceReActived;
    
    CREATE TEMPORARY TABLE Temp_AccountReActived(
			AccountID 		BIGINT UNSIGNED NOT NULL PRIMARY KEY
    );
    
    CREATE TEMPORARY TABLE Temp_DeviceReActived(
			DeviceID 		BIGINT UNSIGNED NOT NULL PRIMARY KEY
    );
    
	/* === Collect Data === */
    INSERT INTO Temp_AccountReActived(AccountID)
    SELECT DISTINCT aa.AccountID
	FROM DCS_DataCenter.ArchiveAccount_NotUsed AS aa
		INNER JOIN DCS_DataCenter.Account AS acc ON acc.AccountID = aa.AccountID
	WHERE acc.LastLoginTime >= lv_AccountArchiveCutoffDate
		OR EXISTS (SELECT 1
				FROM CTS_DataCenter.CustDCSAccount AS cda
				WHERE cda.AccountID = aa.AccountID)
		OR EXISTS (SELECT 1
				FROM CTS_DataCenter.CTSCustomer AS cust
				WHERE cust.Username = aa.LoginName)
		OR EXISTS (SELECT 1
				FROM CTS_DataCenter.CTSCustomer AS cust
				WHERE cust.RegisterName = aa.LoginName
					AND cust.SubscriberID = aa.SubscriberID);
                    
    
    INSERT INTO Temp_DeviceReActived(DeviceID)
    SELECT DISTINCT aa.DeviceID
    FROM DCS_DataCenter.ArchiveAssociation_NotUsed AS aa
		INNER JOIN Temp_AccountReActived AS tmp ON tmp.AccountID = aa.AccountID;
	
	/* === Store data ReActiveAccount === */
    INSERT INTO DCS_DataCenter.ReActiveAccount(AccountID)
    SELECT AccountID
    FROM Temp_AccountReActived;
    
	/* === Delete === */
    DELETE aa
    FROM DCS_DataCenter.ArchiveAccount_NotUsed AS aa
		INNER JOIN Temp_AccountReActived AS tmp ON tmp.AccountID = aa.AccountID;
    
    DELETE aaIp
    FROM DCS_DataCenter.ArchiveAccountIP_NotUsed AS aaIp
		INNER JOIN Temp_AccountReActived AS tmp ON tmp.AccountID = aaIp.AccountID;
    
    DELETE aaFp
    FROM DCS_DataCenter.ArchiveAccountFingerprint_NotUsed AS aaFp
		INNER JOIN Temp_AccountReActived AS tmp ON tmp.AccountID = aaFp.AccountID;
    
    DELETE aaDv
    FROM DCS_DataCenter.ArchiveAccountDevice_NotUsed AS aaDv
		INNER JOIN Temp_AccountReActived AS tmp ON tmp.AccountID = aaDv.AccountID;
    
    DELETE aaAss
    FROM DCS_DataCenter.ArchiveAssociation_NotUsed AS aaAss
		INNER JOIN Temp_AccountReActived AS tmp ON tmp.AccountID = aaAss.AccountID;
        
    DELETE ad
    FROM DCS_DataCenter.ArchiveDevice_NotUsed AS ad
		INNER JOIN Temp_DeviceReActived AS tmp ON tmp.DeviceID = ad.DeviceID;
        
    DELETE adc
    FROM DCS_DataCenter.ArchiveDeviceCode_NotUsed AS adc
		INNER JOIN Temp_DeviceReActived AS tmp ON tmp.DeviceID = adc.DeviceID;
    
    
END$$

DELIMITER ;