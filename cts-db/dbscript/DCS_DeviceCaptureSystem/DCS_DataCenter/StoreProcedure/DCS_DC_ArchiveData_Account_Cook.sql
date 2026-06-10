/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_Account_Cook`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_Account_Cook`(
		IN ip_BatchSize INT UNSIGNED
        
	,	OUT op_ShouldContinue INT
)
SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240419@Jonathan.Doan
		Task:		Cook unused data to Archive tables
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20240419@Jonathan.Doan: Created [Redmine ID: #203691]
		Param's Explanation (filtered by):
			CALL DCS_DC_ArchiveData_Account_Cook(50);
	*/
    DECLARE CONST_SYSTEM_ARCHIVE_MAXACCOUNTID 				INT DEFAULT 4963734;
    DECLARE CONST_SYSTEM_ARCHIVE_ACCOUNTARCHIVECUTOFFDATE	INT DEFAULT 4963735;
    
    DECLARE lv_MaxAccountID  				BIGINT UNSIGNED;
    DECLARE lv_AccountArchiveCutoffDate  	DATE;
    
    SET lv_MaxAccountID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_SYSTEM_ARCHIVE_MAXACCOUNTID);
    SET lv_AccountArchiveCutoffDate = (SELECT DATE(VValue) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_SYSTEM_ARCHIVE_ACCOUNTARCHIVECUTOFFDATE);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Account;
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
    DROP TEMPORARY TABLE IF EXISTS Temp_Device;
    
    CREATE TEMPORARY TABLE Temp_Account(
			AccountID 		BIGINT UNSIGNED NOT NULL PRIMARY KEY
        ,	SubscriberID	INT
        ,	LoginName		VARCHAR(100)
    );
    
    CREATE TEMPORARY TABLE Temp_Association(
			AccountID 		BIGINT UNSIGNED NOT NULL
		,	DeviceID 		BIGINT UNSIGNED NOT NULL
		,	PRIMARY KEY(AccountID, DeviceID)
    );
    
    CREATE TEMPORARY TABLE Temp_Device(
			DeviceID 		BIGINT UNSIGNED NOT NULL PRIMARY KEY
    );
    
    INSERT INTO Temp_Account(AccountID, SubscriberID, LoginName)
	SELECT	acc.AccountID
		,	acc.SubscriberID
		,	acc.LoginName
	FROM DCS_DataCenter.Account AS acc
	WHERE acc.AccountID > lv_MaxAccountID
		AND acc.LastLoginTime < lv_AccountArchiveCutoffDate
	ORDER BY AccountID ASC
    LIMIT ip_BatchSize;

    SET lv_MaxAccountID = (SELECT MAX(AccountID) FROM Temp_Account);
    
	/* === Delete records that do not exist in the CustDCSAccount table === */
	DELETE tmp
	FROM Temp_Account AS tmp
	WHERE EXISTS (SELECT 1 
				FROM CTS_DataCenter.CustDCSAccount AS cda
				WHERE cda.AccountID = tmp.AccountID);
	
    ALTER TABLE Temp_Account
    ADD KEY IX_Temp_Account_LoginName_SubscriberID(LoginName, SubscriberID);

	/* === Delete records that exist in CTSCustomer but not in CustDCSAccount === */
	DELETE tmp
	FROM Temp_Account AS tmp
	WHERE EXISTS (SELECT 1 
				FROM CTS_DataCenter.CTSCustomer AS cust 
				WHERE cust.Username = tmp.LoginName);
                    
	DELETE tmp
	FROM Temp_Account AS tmp
	WHERE EXISTS (SELECT 1 
				FROM CTS_DataCenter.CTSCustomer AS cust 
				WHERE cust.RegisterName = tmp.LoginName
					AND cust.SubscriberID = tmp.SubscriberID);


	INSERT IGNORE INTO DCS_DataCenter.ArchiveAccount_NotUsed(AccountID, SubscriberID, LoginName)
	SELECT	AccountID
		,	SubscriberID
		,	LoginName
    FROM Temp_Account;
    
    INSERT IGNORE INTO DCS_DataCenter.ArchiveAccountIP_NotUsed(ID, AccountID)
    SELECT	accIP.ID
		,	accIP.AccountID
	FROM Temp_Account AS tmp
		INNER JOIN DCS_DataCenter.AccountIP AS accIP ON accIP.AccountID = tmp.AccountID;
    
    INSERT IGNORE INTO DCS_DataCenter.ArchiveAccountDevice_NotUsed(ID, AccountID)
    SELECT	accD.ID
		,	accD.AccountID
	FROM Temp_Account AS tmp
		INNER JOIN DCS_DataCenter.AccountDevice AS accD ON accD.AccountID = tmp.AccountID;
    
    INSERT IGNORE INTO DCS_DataCenter.ArchiveAccountFingerprint_NotUsed(ID, AccountID)
    SELECT	accF.ID
		,	accF.AccountID
	FROM Temp_Account AS tmp
		INNER JOIN DCS_DataCenter.AccountFingerprint AS accF ON accF.AccountID = tmp.AccountID;
    
    
    INSERT IGNORE INTO Temp_Association(AccountID, DeviceID)
    SELECT	ass.AccountID
		,	ass.DeviceID
	FROM Temp_Account AS tmp
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.AccountID = tmp.AccountID;
    
    INSERT IGNORE INTO DCS_DataCenter.ArchiveAssociation_NotUsed(AccountID, DeviceID)
    SELECT	AccountID
		,	DeviceID
	FROM Temp_Association;
    
    
    ALTER TABLE Temp_Association
    ADD KEY IX_Temp_Association_DeviceID(DeviceID);
    
	INSERT INTO Temp_Device(DeviceID)
    SELECT DISTINCT tmp.DeviceID
	FROM Temp_Association AS tmp
	WHERE NOT EXISTS (SELECT ass.DeviceID
					FROM DCS_DataCenter.Association AS ass
					WHERE ass.DeviceID = tmp.DeviceID
						AND ass.AccountID NOT IN (SELECT AccountID FROM Temp_Account)
					LIMIT 1)
	ORDER BY tmp.DeviceID ASC;
    
    INSERT IGNORE INTO DCS_DataCenter.ArchiveDevice_NotUsed(DeviceID)
    SELECT DeviceID
    FROM Temp_Device;
    
    INSERT IGNORE INTO DCS_DataCenter.ArchiveDeviceCode_NotUsed(DeviceCodeID, DeviceCode, DeviceID)
    SELECT	dc.DeviceCodeID
		,	dc.DeviceCode
        ,	dc.DeviceID
    FROM Temp_Device AS tmp
		INNER JOIN DCS_DataCenter.DeviceCode AS dc ON dc.DeviceID = tmp.DeviceID;

    /* == Update SystemSetting == */
    IF(lv_MaxAccountID IS NOT NULL AND lv_MaxAccountID > 0) THEN
        UPDATE DCS_DataCenter.SystemSetting 
        SET VValue = lv_MaxAccountID
        WHERE ID = CONST_SYSTEM_ARCHIVE_MAXACCOUNTID;
        
		SET op_ShouldContinue = 1;
	ELSE
		SET op_ShouldContinue = 0;
    END IF;
    
END$$

DELIMITER ;
