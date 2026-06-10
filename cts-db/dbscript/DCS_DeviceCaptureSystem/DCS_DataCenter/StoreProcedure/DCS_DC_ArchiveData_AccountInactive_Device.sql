/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_AccountInactive_Device`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_AccountInactive_Device`()
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20211209@Aries.Nguyen
		Task :		Archive single device for customer inactive in last 6 months
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 	20211209@Aries.Nguyen: Created [Redmine ID: #165168]
            - 	20211220@Aries.Nguyen: Fix issue performance when use Functional Key Parts and user variable [Redmine ID: #166234] 
		Param's Explanation (filtered by):	
			
	*/
    DECLARE CONS_SysID_Date 	 		INT DEFAULT 14;
    DECLARE CONS_SysID_LastAccountID 	INT DEFAULT 15;
    DECLARE CONS_SysID_TableDeleting 	INT DEFAULT 16;
    DECLARE CONS_SysID_BatchSizeAccount INT DEFAULT 17;
    DECLARE CONS_SysID_BatchSizeDelete 	INT DEFAULT 18;
    
    
    DECLARE lv_DateValid			DATE DEFAULT DATE_SUB(NOW(), INTERVAL 6 MONTH);
    DECLARE lv_NextAccountID 		BIGINT UNSIGNED;
    DECLARE lv_BatchSizeAccount 	INT;
    DECLARE lv_BatchSizeDelete 		INT;
    DECLARE lv_Count 				INT;
	DECLARE lv_Table 				VARCHAR(100);
    
	
    DROP TEMPORARY TABLE IF EXISTS Temp_Account;
    CREATE TEMPORARY TABLE Temp_Account(
		AccountID   BIGINT UNSIGNED PRIMARY KEY
    );
    SET @lv_Date = NULL;
    SET @lv_LastAccountID = NULL;
    SET @lv_NextDate = NULL;

    SELECT VValue
	INTO @lv_Date
	FROM DCS_DataCenter.SystemSetting
	WHERE ID = CONS_SysID_Date; 
    
    SELECT VValue
	INTO @lv_LastAccountID
	FROM DCS_DataCenter.SystemSetting
	WHERE ID = CONS_SysID_LastAccountID; 
    
    SELECT VValue
	INTO lv_Table
	FROM DCS_DataCenter.SystemSetting
	WHERE ID = CONS_SysID_TableDeleting; 
    
	SELECT VValue
	INTO lv_BatchSizeAccount
	FROM DCS_DataCenter.SystemSetting
	WHERE ID = CONS_SysID_BatchSizeAccount; 
    
    SELECT VValue
	INTO lv_BatchSizeDelete
	FROM DCS_DataCenter.SystemSetting
	WHERE ID = CONS_SysID_BatchSizeDelete; 
    
    IF @lv_Date >= lv_DateValid THEN
		LEAVE sp;
	END IF;
    
    /*************************************** 1. DCS_DataCenter.DeviceFingerprint *******************************/
    IF (lv_Table = 'DCS_DataCenter.DeviceFingerprint') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.ArchiveAccountInactive_Device) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_DeviceFingerprint_Clean;
			CREATE TEMPORARY TABLE Temp_DeviceFingerprint_Clean(
					DeviceID   			BIGINT UNSIGNED
				,	FingerprintCode   	VARCHAR(620) COLLATE utf8_unicode_ci
				,	PRIMARY KEY(DeviceID, FingerprintCode)
			);
            
            INSERT IGNORE INTO Temp_DeviceFingerprint_Clean(DeviceID, FingerprintCode)
            SELECT 	df.DeviceID
				,	df.FingerprintCode
			FROM DCS_DataCenter.DeviceFingerprint AS df
            WHERE EXISTS (SELECT 1 FROM DCS_DataCenter.ArchiveAccountInactive_Device AS dv  WHERE dv.DeviceID = df.DeviceID)
            LIMIT lv_BatchSizeDelete;
            
            DELETE df
			FROM  DCS_DataCenter.DeviceFingerprint AS df
				INNER JOIN Temp_DeviceFingerprint_Clean AS tmp ON tmp.DeviceID = df.DeviceID AND tmp.FingerprintCode = df.FingerprintCode;
			
            UPDATE  DCS_DataCenter.SystemSetting
			SET VValue = 'DCS_DataCenter.DeviceFingerprint'
			WHERE ID = CONS_SysID_TableDeleting;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_DeviceFingerprint_Clean;
            
            IF lv_Count >= lv_BatchSizeDelete THEN
				LEAVE sp;
            END IF;
            
            SET lv_BatchSizeDelete = lv_BatchSizeDelete - lv_Count;
        END IF;
        
		SET lv_Table = 'DCS_DataCenter.DeviceCode';
    END IF;
    
    /*************************************** 2. DCS_DataCenter.DeviceCode **************************************/
    IF (lv_Table = 'DCS_DataCenter.DeviceCode') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.ArchiveAccountInactive_Device) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_DeviceCode_Clean;
			CREATE TEMPORARY TABLE Temp_DeviceCode_Clean(
					DeviceCodeID   	BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_DeviceCode_Clean(DeviceCodeID)
            SELECT 	dc.DeviceCodeID
			FROM DCS_DataCenter.DeviceCode AS dc
            WHERE EXISTS (SELECT 1 FROM DCS_DataCenter.ArchiveAccountInactive_Device AS dv  WHERE dv.DeviceID = dc.DeviceID)
            LIMIT lv_BatchSizeDelete;
            
            DELETE dc
			FROM  DCS_DataCenter.DeviceCode AS dc
				INNER JOIN Temp_DeviceCode_Clean AS tmp ON tmp.DeviceCodeID = dc.DeviceCodeID;
			
            UPDATE  DCS_DataCenter.SystemSetting
			SET VValue = 'DCS_DataCenter.DeviceCode'
			WHERE ID = CONS_SysID_TableDeleting;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_DeviceCode_Clean;
            
            IF lv_Count >=lv_BatchSizeDelete THEN
				LEAVE sp;
            END IF;
            
            SET lv_BatchSizeDelete = lv_BatchSizeDelete - lv_Count;
            
        END IF;
        
		SET lv_Table = 'CTS_DataCenter.AssociationByDevice';
    END IF;

    /*************************************** 3. CTS_DataCenter.AssociationByDevice ****************************/
    IF (lv_Table = 'CTS_DataCenter.AssociationByDevice') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.ArchiveAccountInactive_Device) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByDevice_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByDevice_Clean(
					CTSAssDevID   	BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByDevice_Clean(CTSAssDevID)
            SELECT 	dv.CTSAssDevID
			FROM CTS_DataCenter.AssociationByDevice AS dv
            WHERE EXISTS (SELECT 1 FROM DCS_DataCenter.ArchiveAccountInactive_Device AS tmp  WHERE dv.DCSDeviceID = tmp.DeviceID)
            LIMIT lv_BatchSizeDelete;
            
            DELETE dv
			FROM  CTS_DataCenter.AssociationByDevice AS dv
				INNER JOIN Temp_AssociationByDevice_Clean AS tmp ON tmp.CTSAssDevID = dv.CTSAssDevID;
			
            UPDATE  DCS_DataCenter.SystemSetting
			SET VValue = 'CTS_DataCenter.AssociationByDevice'
			WHERE ID = CONS_SysID_TableDeleting;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByDevice_Clean;
            
            IF lv_Count >=lv_BatchSizeDelete THEN
				LEAVE sp;
            END IF;
            
            SET lv_BatchSizeDelete = lv_BatchSizeDelete - lv_Count;
            
        END IF;
        
		SET lv_Table = 'CTS_Archive.AssociationByDevice_Arc';
    END IF;
    
    /*************************************** 4. CTS_Archive.AssociationByDevice_Arc ***************************/
    IF (lv_Table = 'CTS_Archive.AssociationByDevice_Arc') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.ArchiveAccountInactive_Device) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByDevice_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByDevice_Clean(
					ID   	BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByDevice_Clean(ID)
            SELECT 	dv.ID
			FROM CTS_Archive.AssociationByDevice_Arc AS dv
            WHERE EXISTS (SELECT 1 FROM DCS_DataCenter.ArchiveAccountInactive_Device AS tmp  WHERE dv.DCSDeviceID = tmp.DeviceID)
            LIMIT lv_BatchSizeDelete;
            
            DELETE dv
			FROM  CTS_Archive.AssociationByDevice_Arc AS dv
				INNER JOIN Temp_AssociationByDevice_Clean AS tmp ON tmp.ID = dv.ID;
			
            UPDATE  DCS_DataCenter.SystemSetting
			SET VValue = 'CTS_Archive.AssociationByDevice_Arc'
			WHERE ID = CONS_SysID_TableDeleting;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByDevice_Clean;
            
            IF lv_Count >=lv_BatchSizeDelete THEN
				LEAVE sp;
            END IF;
            
            SET lv_BatchSizeDelete = lv_BatchSizeDelete - lv_Count;
            
        END IF;
        
		SET lv_Table = 'DCS_DataCenter.Device';
    END IF;
    
    /*************************************** 5. DCS_DataCenter.Device ******************************************/
    IF (lv_Table = 'DCS_DataCenter.Device') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.ArchiveAccountInactive_Device) THEN
            DELETE dv
			FROM  DCS_DataCenter.Device AS dv
				INNER JOIN DCS_DataCenter.ArchiveAccountInactive_Device AS tmp ON tmp.DeviceID = dv.DeviceID;
			
            UPDATE  DCS_DataCenter.SystemSetting
			SET VValue = 'DCS_DataCenter.Association'
			WHERE ID = CONS_SysID_TableDeleting;
    
			LEAVE sp;
            
        END IF;
        
		SET lv_Table = 'DCS_DataCenter.Association';
    END IF;
	
    /*************************************** 6. DCS_DataCenter.Association *************************************/
    IF (lv_Table = 'DCS_DataCenter.Association') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.ArchiveAccountInactive_Device) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_Association_Clean;
			CREATE TEMPORARY TABLE Temp_Association_Clean(
					AccountID   	BIGINT UNSIGNED
				,	DeviceID   		BIGINT UNSIGNED
				,	PRIMARY KEY(AccountID, DeviceID)
			);
            
            INSERT IGNORE INTO Temp_Association_Clean(AccountID, DeviceID)
            SELECT 	ass.AccountID
				, 	ass.DeviceID
			FROM DCS_DataCenter.Association AS ass
            WHERE  ass.DeviceID IN (SELECT tmp.DeviceID FROM DCS_DataCenter.ArchiveAccountInactive_Device AS tmp)
            LIMIT lv_BatchSizeDelete;
            
            DELETE ass
			FROM  DCS_DataCenter.Association AS ass
				INNER JOIN Temp_Association_Clean AS tmp ON tmp.AccountID = ass.AccountID AND tmp.DeviceID = ass.DeviceID;
			
            DELETE dv
			FROM  DCS_DataCenter.ArchiveAccountInactive_Device AS dv;
			
            UPDATE  DCS_DataCenter.SystemSetting
			SET VValue = 'DCS_DataCenter.DeviceFingerprint'
			WHERE ID = CONS_SysID_TableDeleting;
			
        END IF;
    END IF;
	
    INSERT IGNORE INTO Temp_Account(AccountID)
    SELECT	AccountID
    FROM DCS_DataCenter.Account 
    WHERE DATE(LastLoginTime) = (SELECT @lv_Date)
		AND  AccountID > (SELECT @lv_LastAccountID)
    ORDER BY AccountID ASC
    LIMIT lv_BatchSizeAccount;
	
    IF NOT EXISTS (SELECT 1 FROM Temp_Account) THEN
		SELECT DATE(LastLoginTime)
        INTO @lv_NextDate
		FROM DCS_DataCenter.Account 
		WHERE DATE(LastLoginTime) > (SELECT @lv_Date)
		ORDER BY DATE(LastLoginTime) ASC
		LIMIT 1;
    END IF;
    
    IF @lv_NextDate IS NOT NULL THEN
		UPDATE  DCS_DataCenter.SystemSetting 
		SET VValue = @lv_NextDate
		WHERE ID = CONS_SysID_Date;
            
		UPDATE  DCS_DataCenter.SystemSetting 
		SET VValue = 0
		WHERE ID = CONS_SysID_LastAccountID;
            
		UPDATE  DCS_DataCenter.SystemSetting 
		SET VValue = 'DCS_DataCenter.DeviceFingerprint'
		WHERE ID = CONS_SysID_TableDeleting;
		
		INSERT IGNORE INTO Temp_Account(AccountID)
		SELECT	AccountID
		FROM DCS_DataCenter.Account 
		WHERE DATE(LastLoginTime) = (SELECT @lv_NextDate)
			AND  AccountID > 0
		ORDER BY AccountID ASC
		LIMIT lv_BatchSizeAccount;
	END IF;
    
    INSERT IGNORE INTO DCS_DataCenter.ArchiveAccountInactive_Device(DeviceID)
    SELECT ass.DeviceID 
    FROM DCS_DataCenter.Association AS ass
    WHERE EXISTS (SELECT 1 FROM Temp_Account AS acc WHERE acc.AccountID = ass.AccountID)
		AND NOT EXISTS(SELECT 1 FROM DCS_DataCenter.Association AS dv WHERE dv.DeviceID = ass.DeviceID AND dv.AccountID != ass.AccountID)
	LIMIT lv_BatchSizeDelete;
    
    
    IF NOT EXISTS (SELECT 1 FROM DCS_DataCenter.ArchiveAccountInactive_Device) THEN
		SELECT MAX(AccountID)
        INTO lv_NextAccountID
        FROM Temp_Account;
        
        UPDATE  DCS_DataCenter.SystemSetting 
		SET VValue = lv_NextAccountID
		WHERE ID = CONS_SysID_LastAccountID;
        
        UPDATE  DCS_DataCenter.SystemSetting 
		SET VValue = 'DCS_DataCenter.DeviceFingerprint'
		WHERE ID = CONS_SysID_TableDeleting;
    END IF;
    
END$$

DELIMITER ;