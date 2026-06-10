/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_FP_DeviceMappingInsert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_FP_DeviceMappingInsert`(
	IN ip_BatchSize INT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20240729@Jonathan.Doan
	    Task : Change Data Flow Ver. 6
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20240729@Jonathan.Doan: Created [RedmineID: #206403]
	    Param's Explanation (filtered by):
        
        Example:
			CALL DCS_DC_Transform_FP_DeviceMappingInsert('50');
	*/
    
    /********************** Constants ***********************************/
    DECLARE CONST_MIN_TRANSACTION_TRANSID		INT DEFAULT 24;
    DECLARE CONST_MINUTE_TO_WAIT_EVOLUTION		INT DEFAULT 25;
    
    DECLARE CONST_RECOVERTYPE_FIRSTRULE			SMALLINT DEFAULT 1;
    DECLARE CONST_RECOVERTYPE_SECONDRULE		SMALLINT DEFAULT 5;
    
	DECLARE CONST_DEVICESTATUS_NEW				TINYINT DEFAULT 1;
	DECLARE CONST_DEVICESTATUS_OLD				TINYINT DEFAULT 2;
	DECLARE CONST_DEVICESTATUS_RECOVER			TINYINT DEFAULT 3;

    /********************** Local variables ***********************************/
	DECLARE lv_Min_Transaction_TransID  		BIGINT UNSIGNED;
	DECLARE lv_Minute_To_Wait_Evolution  		INT;
    DECLARE lv_CurrentDate 						TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    
    /********************** Fetch System Settings values ***********************************/
	SET lv_Min_Transaction_TransID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_MIN_TRANSACTION_TRANSID);
	SET lv_Minute_To_Wait_Evolution = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_MINUTE_TO_WAIT_EVOLUTION);
	
    
    /********************** CREAT TEMP TABLE ***********************************/
	DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
	DROP TEMPORARY TABLE IF EXISTS Temp_DeviceMapping;
	DROP TEMPORARY TABLE IF EXISTS Temp_TaggingDevice;
	DROP TEMPORARY TABLE IF EXISTS Temp_DeviceFingerprintAccountOld;
	DROP TEMPORARY TABLE IF EXISTS Temp_CheckSameDevice;
	DROP TEMPORARY TABLE IF EXISTS Temp_ExistingDevice;
    
	CREATE TEMPORARY TABLE Temp_Transaction(
			TransID										BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	RawTransID									BIGINT UNSIGNED NOT NULL
		,	AccountID									BIGINT UNSIGNED
		,	FP_TaggingID								BIGINT UNSIGNED
		,	FP_FingerPrintID							BIGINT UNSIGNED
		,	FP_FingerPrintOldID							BIGINT UNSIGNED
	);
    
	CREATE TEMPORARY TABLE Temp_DeviceMapping(
			TransID										BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	RawTransID									BIGINT UNSIGNED NOT NULL
		,	FP_DeviceID									BIGINT UNSIGNED DEFAULT 0
		,	FP_TaggingID								BIGINT UNSIGNED
		,	FP_FingerPrintID							BIGINT UNSIGNED
		,	FP_DeviceFingerprintAccountID				BIGINT UNSIGNED
		,	FP_DeviceFingerprintAccount_EvolveID		BIGINT UNSIGNED
		,	FP_DeviceFingerprintAccountOldID			BIGINT UNSIGNED
        
		,	FP_DeviceFingerprintAccount_InsertedTime	TIMESTAMP
        ,	RecoverType									SMALLINT UNSIGNED DEFAULT 0 /* SELECT * FROM DCS_DataCenter.StaticList WHERE ListID = 4; */
        
		,	SameDeviceWithRawTransID					BIGINT UNSIGNED DEFAULT 0
		,	FP_DeviceMappingID							BIGINT UNSIGNED DEFAULT 0
		,	FirstRawTransID								BIGINT UNSIGNED
	);
    
	CREATE TEMPORARY TABLE Temp_ExistingDevice(
			RawTransID									BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	FP_DeviceID									BIGINT UNSIGNED DEFAULT 0
		,	SameDeviceWithRawTransID					BIGINT UNSIGNED DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_TaggingDevice(
			FP_TaggingID								BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	FP_DeviceID									BIGINT UNSIGNED DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_DeviceFingerprintAccountOld(
			FP_DeviceFingerprintAccountOldID			BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	FP_DeviceID									BIGINT UNSIGNED DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_CheckSameDevice(
			RawTransID									BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	SameDeviceWithRawTransID					BIGINT UNSIGNED DEFAULT 0
		,	FP_DeviceID									BIGINT UNSIGNED DEFAULT 0
		,	RecoverType									SMALLINT UNSIGNED DEFAULT 0
        
		,	FirstDeviceID								BIGINT UNSIGNED
		,	SecondDeviceID								BIGINT UNSIGNED
	);
    
    /********************** Get Data ***********************************/
    INSERT INTO Temp_Transaction(TransID, RawTransID, AccountID, FP_TaggingID, FP_FingerPrintID, FP_FingerPrintOldID)
    SELECT 	TransID
		,	RawTransID
        ,	AccountID
        ,	FP_TaggingID
        ,	FP_FingerPrintID
		,	FP_FingerPrintOldID
    FROM DCS_DataCenter.Transaction AS trans
    WHERE trans.TransID >= lv_Min_Transaction_TransID
		AND NOT EXISTS (SELECT 1 FROM DCS_DataCenter.FP_TransactionDeviceMapping AS tdm WHERE tdm.RawTransID = trans.RawTransID)
	ORDER BY trans.TransID ASC
    LIMIT ip_BatchSize;
    
	ALTER TABLE Temp_Transaction
	ADD INDEX IX_Temp_Transaction_FP_FingerPrintID_AccountID (FP_FingerPrintID, AccountID),
	ADD INDEX IX_Temp_Transaction_FP_FingerPrintOldID_AccountID (FP_FingerPrintOldID, AccountID);
    
    
    INSERT IGNORE INTO Temp_DeviceMapping(TransID, RawTransID, FP_TaggingID, FP_FingerPrintID, FP_DeviceFingerprintAccountID, FP_DeviceFingerprintAccount_EvolveID, FP_DeviceFingerprintAccount_InsertedTime, FP_DeviceFingerprintAccountOldID)
    SELECT	tmp.TransID
		,	tmp.RawTransID
		,	IFNULL(tmp.FP_TaggingID,0) AS FP_TaggingID
		,	IFNULL(tmp.FP_FingerPrintID,0) AS FP_FingerPrintID
		,	IFNULL(dfa.ID,0) AS FP_DeviceFingerprintAccountID
		,	IFNULL(dfa.EvolveID,0) AS FP_DeviceFingerprintAccount_EvolveID
		,	dfa.InsertedTime AS FP_DeviceFingerprintAccount_InsertedTime
		,	IFNULL(dfao.ID,0) AS FP_DeviceFingerprintAccountOldID
    FROM Temp_Transaction AS tmp
		LEFT JOIN DCS_DataCenter.FP_DeviceFingerprintAccount AS dfa ON dfa.FP_FingerPrintID = tmp.FP_FingerPrintID AND dfa.AccountID = tmp.AccountID
		LEFT JOIN DCS_DataCenter.FP_DeviceFingerprintAccountOld AS dfao ON dfao.FP_FingerPrintOldID = tmp.FP_FingerPrintOldID AND dfao.AccountID = tmp.AccountID;
	
	ALTER TABLE Temp_DeviceMapping
	ADD INDEX IX_Temp_DeviceMapping_RawTransID (RawTransID),
	ADD INDEX IX_Temp_DeviceMapping_FP_DeviceFingerprintAccountOldID (FP_DeviceFingerprintAccountOldID),
	ADD INDEX IX_Temp_DeviceMapping_GroupIndex (FP_TaggingID, FP_FingerPrintID, FP_DeviceFingerprintAccountID, FP_DeviceFingerprintAccount_EvolveID, FP_DeviceFingerprintAccountOldID);
    
    SET lv_Min_Transaction_TransID = (SELECT MIN(TransID) FROM Temp_DeviceMapping);
    
    -- Wait lv_Minute_To_Wait_Evolution minutes
    DELETE tmp
    FROM Temp_DeviceMapping AS tmp
    WHERE (FP_TaggingID > 0 OR FP_FingerPrintID > 0)
		AND FP_DeviceFingerprintAccountID > 0
		AND FP_DeviceFingerprintAccount_EvolveID = 0
		AND FP_DeviceFingerprintAccount_InsertedTime >= DATE_ADD(NOW(), INTERVAL (-1)*lv_Minute_To_Wait_Evolution MINUTE);
        
    /********************** Check Same Device ***********************************/
    INSERT INTO Temp_CheckSameDevice(RawTransID, FirstDeviceID, SecondDeviceID)
    SELECT 	RawTransID
		,	FP_TaggingID AS FirstDeviceID
		,	FP_DeviceFingerprintAccountOldID AS SecondDeviceID
    FROM Temp_DeviceMapping
    WHERE FP_TaggingID > 0
		OR FP_DeviceFingerprintAccountOldID > 0;
    
    CALL DCS_DataCenter.DCS_DC_Transform_FP_DeviceMappingUpdateTheSameDevice('Temp_CheckSameDevice');
    
	ALTER TABLE Temp_CheckSameDevice
	ADD INDEX IX_Temp_CheckSameDevice_RawTransID (RawTransID);
    
    UPDATE Temp_DeviceMapping AS tmp
		INNER JOIN Temp_CheckSameDevice AS tmpND ON tmpND.RawTransID = tmp.RawTransID
	SET tmp.SameDeviceWithRawTransID = tmpND.SameDeviceWithRawTransID,
		tmp.RecoverType = CASE tmpND.RecoverType 
							WHEN 1 THEN CONST_RECOVERTYPE_FIRSTRULE
                            WHEN 2 THEN CONST_RECOVERTYPE_SECONDRULE
						END;
    
    /********************** Add more Index ***********************************/
	ALTER TABLE Temp_DeviceMapping
	ADD INDEX IX_Temp_DeviceMapping_SameDeviceWithRawTransID (SameDeviceWithRawTransID);
    
    
    /********************** Get Device in FP_DeviceMapping ***********************************/
    UPDATE Temp_DeviceMapping AS tmp
		INNER JOIN DCS_DataCenter.FP_DeviceMapping AS dm ON dm.FP_TaggingID 							= tmp.FP_TaggingID
														AND dm.FP_FingerPrintID 						= tmp.FP_FingerPrintID
														AND dm.FP_DeviceFingerprintAccountID 			= tmp.FP_DeviceFingerprintAccountID
														AND dm.FP_DeviceFingerprintAccount_EvolveID 	= tmp.FP_DeviceFingerprintAccount_EvolveID
														AND dm.FP_DeviceFingerprintAccountOldID 		= tmp.FP_DeviceFingerprintAccountOldID
	SET tmp.FP_DeviceID = dm.FP_DeviceID;
    
    /********************** Insert into Temp_ExistingDevice ***********************************/
    INSERT IGNORE INTO Temp_ExistingDevice(RawTransID, FP_DeviceID, SameDeviceWithRawTransID)
    SELECT	RawTransID
		,	FP_DeviceID
        ,	SameDeviceWithRawTransID
	FROM Temp_DeviceMapping
    WHERE FP_DeviceID > 0;
    
    UPDATE Temp_DeviceMapping AS tmp
		INNER JOIN Temp_ExistingDevice AS tmpED ON tmpED.SameDeviceWithRawTransID = tmp.SameDeviceWithRawTransID
	SET tmp.FP_DeviceID = tmpED.FP_DeviceID
	WHERE tmp.FP_DeviceID = 0;
    
    /********************** Check Rule 1 ***********************************/
    INSERT INTO Temp_TaggingDevice(FP_TaggingID)
    SELECT DISTINCT FP_TaggingID
    FROM Temp_DeviceMapping
    WHERE FP_DeviceID = 0
		AND FP_TaggingID > 0;
    
    UPDATE Temp_TaggingDevice AS tmp
	SET tmp.FP_DeviceID = IFNULL((
		SELECT dm.FP_DeviceID
		FROM DCS_DataCenter.FP_DeviceMapping AS dm
		WHERE dm.FP_TaggingID = tmp.FP_TaggingID
		ORDER BY dm.ID DESC
        LIMIT 1
	), 0);
    
    
    /********************** Update Temp ***********************************/
    UPDATE Temp_DeviceMapping AS tmp
		INNER JOIN Temp_TaggingDevice AS tmpTg ON tmpTg.FP_TaggingID = tmp.FP_TaggingID
	SET tmp.FP_DeviceID = tmpTg.FP_DeviceID,
		tmp.RecoverType = CONST_RECOVERTYPE_FIRSTRULE
    WHERE tmp.FP_DeviceID = 0
		AND tmpTg.FP_DeviceID > 0;
    
    INSERT IGNORE INTO Temp_ExistingDevice(RawTransID, FP_DeviceID, SameDeviceWithRawTransID)
    SELECT	RawTransID
		,	FP_DeviceID
        ,	SameDeviceWithRawTransID
	FROM Temp_DeviceMapping 
    WHERE FP_DeviceID > 0;
    
    UPDATE Temp_DeviceMapping AS tmp
		INNER JOIN Temp_ExistingDevice AS tmpED ON tmpED.SameDeviceWithRawTransID = tmp.SameDeviceWithRawTransID
	SET tmp.FP_DeviceID = tmpED.FP_DeviceID
	WHERE tmp.FP_DeviceID = 0;
    
    
    /********************** Check Rule 5 FP_DeviceFingerprintAccountOldID ***********************************/
    INSERT INTO Temp_DeviceFingerprintAccountOld(FP_DeviceFingerprintAccountOldID)
    SELECT DISTINCT FP_DeviceFingerprintAccountOldID
    FROM Temp_DeviceMapping
    WHERE FP_DeviceID = 0
		AND FP_DeviceFingerprintAccountOldID > 0;
    
    UPDATE Temp_DeviceFingerprintAccountOld AS tmp
	SET tmp.FP_DeviceID = IFNULL((
		SELECT dm.FP_DeviceID
		FROM DCS_DataCenter.FP_DeviceMapping AS dm
		WHERE dm.FP_DeviceFingerprintAccountOldID = tmp.FP_DeviceFingerprintAccountOldID
		ORDER BY dm.ID DESC
        LIMIT 1
	), 0);
    
    /********************** Update Temp ***********************************/
    UPDATE Temp_DeviceMapping AS tmp
		INNER JOIN Temp_DeviceFingerprintAccountOld AS tmpDfa ON tmpDfa.FP_DeviceFingerprintAccountOldID = tmp.FP_DeviceFingerprintAccountOldID
	SET tmp.FP_DeviceID = tmpDfa.FP_DeviceID,
		tmp.RecoverType = CONST_RECOVERTYPE_SECONDRULE
    WHERE tmp.FP_DeviceID = 0
		AND tmpDfa.FP_DeviceID > 0;
    
    INSERT IGNORE INTO Temp_ExistingDevice(RawTransID, FP_DeviceID, SameDeviceWithRawTransID)
    SELECT	RawTransID
		,	FP_DeviceID
        ,	SameDeviceWithRawTransID
	FROM Temp_DeviceMapping
    WHERE FP_DeviceID > 0;
    
    UPDATE Temp_DeviceMapping AS tmp
		INNER JOIN Temp_ExistingDevice AS tmpED ON tmpED.SameDeviceWithRawTransID = tmp.SameDeviceWithRawTransID
	SET tmp.FP_DeviceID = tmpED.FP_DeviceID
	WHERE tmp.FP_DeviceID = 0;
    
    /********************** INSERT New device ***********************************/
    INSERT IGNORE INTO DCS_DataCenter.FP_Device(FirstRawTransID)
    SELECT DISTINCT SameDeviceWithRawTransID
    FROM Temp_DeviceMapping
    WHERE FP_DeviceID = 0
		AND SameDeviceWithRawTransID > 0;
    
    UPDATE Temp_DeviceMapping AS tmp
		INNER JOIN DCS_DataCenter.FP_Device AS dv ON dv.FirstRawTransID = tmp.SameDeviceWithRawTransID
	SET tmp.FP_DeviceID = dv.ID
    WHERE tmp.FP_DeviceID = 0;
    
    INSERT IGNORE INTO DCS_DataCenter.FP_DeviceMapping(FP_TaggingID, FP_FingerPrintID, FP_DeviceFingerprintAccountID, FP_DeviceFingerprintAccount_EvolveID, FP_DeviceFingerprintAccountOldID, FP_DeviceID, FirstRawTransID, RecoverType)
    SELECT 	FP_TaggingID
		,	FP_FingerPrintID
        ,	FP_DeviceFingerprintAccountID
        ,	FP_DeviceFingerprintAccount_EvolveID
        ,	FP_DeviceFingerprintAccountOldID
        ,	FP_DeviceID
        ,	RawTransID AS FirstRawTransID
        ,	RecoverType AS RecoverType
    FROM Temp_DeviceMapping
    WHERE FP_DeviceID > 0;
    
    UPDATE Temp_DeviceMapping AS tmp
		INNER JOIN DCS_DataCenter.FP_DeviceMapping AS dm ON dm.FP_TaggingID 							= tmp.FP_TaggingID
														AND dm.FP_FingerPrintID 						= tmp.FP_FingerPrintID
														AND dm.FP_DeviceFingerprintAccountID 			= tmp.FP_DeviceFingerprintAccountID
														AND dm.FP_DeviceFingerprintAccount_EvolveID 	= tmp.FP_DeviceFingerprintAccount_EvolveID
														AND dm.FP_DeviceFingerprintAccountOldID 		= tmp.FP_DeviceFingerprintAccountOldID
	SET tmp.FP_DeviceMappingID  = dm.ID,
		tmp.FP_DeviceID = dm.FP_DeviceID,
		tmp.FirstRawTransID = dm.FirstRawTransID;
    
    INSERT IGNORE INTO DCS_DataCenter.FP_TransactionDeviceMapping(RawTransID, FP_DeviceMappingID, FP_DeviceID, FP_DeviceStatus)
    SELECT 	RawTransID
		,	FP_DeviceMappingID
		,	FP_DeviceID
		,	CASE WHEN FirstRawTransID = RawTransID
				THEN (
					CASE WHEN RecoverType = CONST_RECOVERTYPE_FIRSTRULE THEN CONST_DEVICESTATUS_OLD
						WHEN RecoverType = CONST_RECOVERTYPE_SECONDRULE THEN CONST_DEVICESTATUS_RECOVER
                        ELSE CONST_DEVICESTATUS_NEW
					END
                )
                ELSE (CASE WHEN FP_DeviceMappingID = 0
						THEN 0
                        ELSE CONST_DEVICESTATUS_OLD END)
			END AS FP_DeviceStatus
    FROM Temp_DeviceMapping;
    
    /*****UPDATE MaxTransID in SystemSetting****************************************************/    
    IF lv_Min_Transaction_TransID IS NOT NULL AND lv_Min_Transaction_TransID > 0 THEN
		UPDATE DCS_DataCenter.SystemSetting AS sys
		SET sys.VValue 	= CONCAT('', lv_Min_Transaction_TransID),
		    sys.UpdatedTime = lv_CurrentDate
		WHERE ID = CONST_MIN_TRANSACTION_TRANSID;
    END IF;
    
END$$

DELIMITER ;
