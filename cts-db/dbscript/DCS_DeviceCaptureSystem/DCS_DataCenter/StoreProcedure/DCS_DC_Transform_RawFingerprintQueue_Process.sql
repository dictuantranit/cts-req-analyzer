/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_RawFingerprintQueue_Process`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_RawFingerprintQueue_Process`(
	IN ip_BatchSize INT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20250822@Casey.Huynh
		Task : Transform Pattern Group
		DB: DCS_DataCenter
		Original:
	
		Revisions:
            - 20250826@Casey.Huynh: Created, AI Power Device Fingerprint AND Remove FPJs [Redmine ID: #236716]

		Param's Explanation (filtered by):
		Example:
			
	*/
	DECLARE CONST_TYPE_HARDWARE		TINYINT DEFAULT 1;
    DECLARE CONST_TYPE_GRAPHIC		TINYINT DEFAULT 2;
    DECLARE CONST_TYPE_AUDIO		TINYINT DEFAULT 3;
    DECLARE CONST_TYPE_BROWSER		TINYINT DEFAULT 4;
    DECLARE CONST_TYPE_PREFERENCES	TINYINT DEFAULT 5;
    
	DECLARE CONST_TYPE_PATTERN01	TINYINT DEFAULT 1;
    DECLARE CONST_TYPE_PATTERN02	TINYINT DEFAULT 2;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_RawFingerprintQueue;
	CREATE TEMPORARY TABLE Temp_RawFingerprintQueue(
			ID					BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY
		,	FPPatternID01		BIGINT UNSIGNED
		,	FPPatternID02		BIGINT UNSIGNED
		,	HardwareCode		VARCHAR(32)
		,	GraphicCode			VARCHAR(32)
		,	AudioCode			VARCHAR(32)
		,	BrowserCode			VARCHAR(32)
		,	PreferencesCode		VARCHAR(32)
		,	HardwareDetails		LONGTEXT
		,	GraphicDetails		LONGTEXT
		,	AudioDetails		LONGTEXT
		,	BrowserDetails		LONGTEXT
		,	PreferencesDetails	LONGTEXT
		,	CreatedDate			DATE
        
	);     
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Hardware;
	CREATE TEMPORARY TABLE Temp_Hardware(
			HardwareCode		VARCHAR(32) NOT NULL PRIMARY KEY
		,	HardwareDetails		LONGTEXT
        ,	FPGroupHardwareID	BIGINT UNSIGNED
        ,	NewUsedDate			DATE		
	
		,	INDEX IX_Temp_Hardware_FPGroupHardwareID(FPGroupHardwareID)
    );  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Graphic;
	CREATE TEMPORARY TABLE Temp_Graphic(
			GraphicCode			VARCHAR(32) NOT NULL PRIMARY KEY
		,	GraphicDetails		LONGTEXT
        ,	FPGroupGraphicID	BIGINT UNSIGNED
        ,	NewUsedDate			DATE		
	
		,	INDEX IX_Temp_Graphic_FPGroupGraphicID(FPGroupGraphicID)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Audio;
	CREATE TEMPORARY TABLE Temp_Audio(
			AudioCode		VARCHAR(32) NOT NULL PRIMARY KEY
		,	AudioDetails	LONGTEXT
        ,	FPGroupAudioID	BIGINT UNSIGNED
        ,	NewUsedDate		DATE		
	
		,	INDEX IX_Temp_Audio_FPGroupAudioID(FPGroupAudioID)
    );    
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Browser;
	CREATE TEMPORARY TABLE Temp_Browser(
			BrowserCode			VARCHAR(32) NOT NULL PRIMARY KEY
		,	BrowserDetails		LONGTEXT
        ,	FPGroupBrowserID	BIGINT UNSIGNED
        ,	NewUsedDate			DATE		
	
		,	INDEX IX_Temp_Browser_FPGroupBrowserID(FPGroupBrowserID)
    );  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Preferences;
	CREATE TEMPORARY TABLE Temp_Preferences(
			PreferencesCode			VARCHAR(32) NOT NULL PRIMARY KEY
		,	PreferencesDetails		LONGTEXT
        ,	FPGroupPreferencesID	BIGINT UNSIGNED
        ,	NewUsedDate				DATE		
	
		,	INDEX IX_Temp_Preferences_FPGroupPreferencesID(FPGroupPreferencesID)
    );  
    #=============================================================================
	DROP TEMPORARY TABLE IF EXISTS Temp_FPPatternGroup;
	CREATE TEMPORARY TABLE Temp_FPPatternGroup(
			FPPatternID 	BIGINT UNSIGNED NOT NULL
		,	FPPatternType	TINYINT NOT NULL COMMENT 'Pattern Group Combinition'
        ,	FPGroupType 	TINYINT UNSIGNED NOT NULL COMMENT '1:Hardware, 2:Graphic, 3.Audio, 4. Browser, 5.Prereference'
		,	FPGroupID 		BIGINT UNSIGNED	NOT NULL		
		
		,	PRIMARY KEY PK_FPPatternGroup_FPCode(FPPatternID, FPGroupType, FPGroupID)
	);
    
    INSERT INTO Temp_RawFingerprintQueue(ID, FPPatternID01, FPPatternID02, HardwareCode, GraphicCode, AudioCode, BrowserCode, PreferencesCode, HardwareDetails, GraphicDetails, AudioDetails, BrowserDetails, PreferencesDetails, CreatedDate)
	SELECT	que.ID
		,	que.FPPatternID01
		,	que.FPPatternID02
		,	que.HardwareCode
		,	que.GraphicCode
		,	que.AudioCode
		,	que.BrowserCode
		,	que.PreferencesCode
		,	que.HardwareDetails
		,	que.GraphicDetails
		,	que.AudioDetails
		,	que.BrowserDetails
		,	que.PreferencesDetails
		,	que.CreatedDate
    FROM DCS_DataCenter.RawFingerprintQueue AS que
	LIMIT ip_BatchSize;
	
    ALTER TABLE Temp_RawFingerprintQueue
		  ADD INDEX IX_RawFingerprintQueue_HardwareCode(HardwareCode)
        , ADD INDEX IX_RawFingerprintQueue_GraphicCode(GraphicCode)
        , ADD INDEX IX_RawFingerprintQueue_AudioCode(AudioCode)
        , ADD INDEX IX_RawFingerprintQueue_BrowserCode(BrowserCode)
        , ADD INDEX IX_RawFingerprintQueue_PreferencesCode(PreferencesCode);

	#=======================Hardware DEAILS============================================= 
	INSERT INTO Temp_Hardware(HardwareCode, HardwareDetails, NewUsedDate)
    SELECT	tmpQue.HardwareCode
			,	MAX(tmpQue.HardwareDetails)
            ,	MAX(tmpQue.CreatedDate) AS NewUsedDate
	FROM Temp_RawFingerprintQueue AS tmpQue
	WHERE tmpQue.HardwareCode IS NOT NULL
	GROUP BY tmpQue.HardwareCode;
    
	INSERT IGNORE INTO DCS_DataCenter.FPGroupHardware(HardwareCode, HardwareDetails, CreatedDate, LastUsedDate)
	SELECT	tmpDt.HardwareCode
		,	tmpDt.HardwareDetails
		,	tmpDt.NewUsedDate
		,	tmpDt.NewUsedDate AS LastUsedDate
	FROM Temp_Hardware AS tmpDt
    WHERE tmpDt.FPGroupHardwareID IS NULL
    ON DUPLICATE KEY UPDATE LastUsedDate = GREATEST(LastUsedDate, tmpDt.NewUsedDate);
    
    UPDATE Temp_Hardware AS tmpDt
		INNER JOIN DCS_DataCenter.FPGroupHardware AS hw ON hw.HardwareCode = tmpDt.HardwareCode
    SET tmpDt.FPGroupHardwareID = hw.FPGroupHardwareID;
    
    INSERT IGNORE INTO Temp_FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpQue.FPPatternID01
		,	CONST_TYPE_PATTERN01 AS FPPatternType
		,	tmpDt.FPGroupHardwareID
		,	CONST_TYPE_HARDWARE AS FPGroupType
	FROM Temp_Hardware AS tmpDt
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpDt.HardwareCode = tmpQue.HardwareCode
	WHERE tmpQue.FPPatternID01 IS NOT NULL;    
    
    INSERT IGNORE INTO Temp_FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpQue.FPPatternID02
		,	CONST_TYPE_PATTERN02 AS FPPatternType
		,	tmpDt.FPGroupHardwareID
		,	CONST_TYPE_HARDWARE AS FPGroupType
	FROM Temp_Hardware AS tmpDt
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpDt.HardwareCode = tmpQue.HardwareCode
	WHERE tmpQue.FPPatternID02 IS NOT NULL;
    
	#=======================Graphic DEAILS============================================= 
	INSERT INTO Temp_Graphic(GraphicCode, GraphicDetails, NewUsedDate)
    SELECT	tmpQue.GraphicCode
			,	MAX(tmpQue.GraphicDetails)
            ,	MAX(tmpQue.CreatedDate) AS NewUsedDate
	FROM Temp_RawFingerprintQueue AS tmpQue
	WHERE tmpQue.GraphicCode IS NOT NULL
	GROUP BY tmpQue.GraphicCode;
    
	INSERT IGNORE INTO DCS_DataCenter.FPGroupGraphic(GraphicCode, GraphicDetails, CreatedDate, LastUsedDate)
	SELECT	tmpDt.GraphicCode
		,	tmpDt.GraphicDetails
		,	tmpDt.NewUsedDate
		,	tmpDt.NewUsedDate AS LastUsedDate
	FROM Temp_Graphic AS tmpDt
    WHERE tmpDt.FPGroupGraphicID IS NULL
    ON DUPLICATE KEY UPDATE LastUsedDate = GREATEST(LastUsedDate, tmpDt.NewUsedDate);
    
    UPDATE Temp_Graphic AS tmpDt
		INNER JOIN DCS_DataCenter.FPGroupGraphic AS hw ON hw.GraphicCode = tmpDt.GraphicCode
    SET tmpDt.FPGroupGraphicID = hw.FPGroupGraphicID;
        
    INSERT IGNORE INTO Temp_FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpQue.FPPatternID02
		,	CONST_TYPE_PATTERN02 AS FPPatternType
		,	tmpDt.FPGroupGraphicID
		,	CONST_TYPE_GRAPHIC AS FPGroupType
	FROM Temp_Graphic AS tmpDt
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpDt.GraphicCode = tmpQue.GraphicCode
	WHERE tmpQue.FPPatternID02 IS NOT NULL;
    
    #=======================Audio DEAILS============================================= 
	INSERT INTO Temp_Audio(AudioCode, AudioDetails, NewUsedDate)
    SELECT	tmpQue.AudioCode
			,	MAX(tmpQue.AudioDetails)
            ,	MAX(tmpQue.CreatedDate) AS NewUsedDate
	FROM Temp_RawFingerprintQueue AS tmpQue
	WHERE tmpQue.AudioCode IS NOT NULL
	GROUP BY tmpQue.AudioCode;
    
	INSERT IGNORE INTO DCS_DataCenter.FPGroupAudio(AudioCode, AudioDetails, CreatedDate, LastUsedDate)
	SELECT	tmpDt.AudioCode
		,	tmpDt.AudioDetails
		,	tmpDt.NewUsedDate
		,	tmpDt.NewUsedDate AS LastUsedDate
	FROM Temp_Audio AS tmpDt
    WHERE tmpDt.FPGroupAudioID IS NULL
    ON DUPLICATE KEY UPDATE LastUsedDate = GREATEST(LastUsedDate, tmpDt.NewUsedDate);
    
    UPDATE Temp_Audio AS tmpDt
		INNER JOIN DCS_DataCenter.FPGroupAudio AS hw ON hw.AudioCode = tmpDt.AudioCode
    SET tmpDt.FPGroupAudioID = hw.FPGroupAudioID;
    
    INSERT IGNORE INTO Temp_FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpQue.FPPatternID01
		,	CONST_TYPE_PATTERN01 AS FPPatternType
		,	tmpDt.FPGroupAudioID
		,	CONST_TYPE_AUDIO AS FPGroupType
	FROM Temp_Audio AS tmpDt
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpDt.AudioCode = tmpQue.AudioCode
	WHERE tmpQue.FPPatternID01 IS NOT NULL;    
    
    INSERT IGNORE INTO Temp_FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpQue.FPPatternID02
		,	CONST_TYPE_PATTERN02 AS FPPatternType
		,	tmpDt.FPGroupAudioID
		,	CONST_TYPE_AUDIO AS FPGroupType
	FROM Temp_Audio AS tmpDt
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpDt.AudioCode = tmpQue.AudioCode
	WHERE tmpQue.FPPatternID02 IS NOT NULL;
    
    #=======================Browser DEAILS============================================= 
	INSERT INTO Temp_Browser(BrowserCode, BrowserDetails, NewUsedDate)
    SELECT	tmpQue.BrowserCode
			,	MAX(tmpQue.BrowserDetails)
            ,	MAX(tmpQue.CreatedDate) AS NewUsedDate
	FROM Temp_RawFingerprintQueue AS tmpQue
	WHERE tmpQue.BrowserCode IS NOT NULL
	GROUP BY tmpQue.BrowserCode;
    
	INSERT IGNORE INTO DCS_DataCenter.FPGroupBrowser(BrowserCode, BrowserDetails, CreatedDate, LastUsedDate)
	SELECT	tmpDt.BrowserCode
		,	tmpDt.BrowserDetails
		,	tmpDt.NewUsedDate
		,	tmpDt.NewUsedDate AS LastUsedDate
	FROM Temp_Browser AS tmpDt
    WHERE tmpDt.FPGroupBrowserID IS NULL
    ON DUPLICATE KEY UPDATE LastUsedDate = GREATEST(LastUsedDate, tmpDt.NewUsedDate);
    
    UPDATE Temp_Browser AS tmpDt
		INNER JOIN DCS_DataCenter.FPGroupBrowser AS hw ON hw.BrowserCode = tmpDt.BrowserCode
    SET tmpDt.FPGroupBrowserID = hw.FPGroupBrowserID;
    
    INSERT IGNORE INTO Temp_FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpQue.FPPatternID01
		,	CONST_TYPE_PATTERN01 AS FPPatternType
		,	tmpDt.FPGroupBrowserID
		,	CONST_TYPE_BROWSER AS FPGroupType
	FROM Temp_Browser AS tmpDt
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpDt.BrowserCode = tmpQue.BrowserCode
	WHERE tmpQue.FPPatternID01 IS NOT NULL;    
    
    INSERT IGNORE INTO Temp_FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpQue.FPPatternID02
		,	CONST_TYPE_PATTERN02 AS FPPatternType
		,	tmpDt.FPGroupBrowserID
		,	CONST_TYPE_BROWSER AS FPGroupType
	FROM Temp_Browser AS tmpDt
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpDt.BrowserCode = tmpQue.BrowserCode
	WHERE tmpQue.FPPatternID02 IS NOT NULL;
    
    #=======================Preferences DEAILS============================================= 
	INSERT INTO Temp_Preferences(PreferencesCode, PreferencesDetails, NewUsedDate)
    SELECT	tmpQue.PreferencesCode
			,	MAX(tmpQue.PreferencesDetails)
            ,	MAX(tmpQue.CreatedDate) AS NewUsedDate
	FROM Temp_RawFingerprintQueue AS tmpQue
	WHERE tmpQue.PreferencesCode IS NOT NULL
	GROUP BY tmpQue.PreferencesCode;
    
	INSERT IGNORE INTO DCS_DataCenter.FPGroupPreferences(PreferencesCode, PreferencesDetails, CreatedDate, LastUsedDate)
	SELECT	tmpDt.PreferencesCode
		,	tmpDt.PreferencesDetails
		,	tmpDt.NewUsedDate
		,	tmpDt.NewUsedDate AS LastUsedDate
	FROM Temp_Preferences AS tmpDt
    WHERE tmpDt.FPGroupPreferencesID IS NULL
    ON DUPLICATE KEY UPDATE LastUsedDate = GREATEST(LastUsedDate, tmpDt.NewUsedDate);
    
    UPDATE Temp_Preferences AS tmpDt
		INNER JOIN DCS_DataCenter.FPGroupPreferences AS hw ON hw.PreferencesCode = tmpDt.PreferencesCode
    SET tmpDt.FPGroupPreferencesID = hw.FPGroupPreferencesID;
    
    INSERT IGNORE INTO Temp_FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpQue.FPPatternID01
		,	CONST_TYPE_PATTERN01 AS FPPatternType
		,	tmpDt.FPGroupPreferencesID
		,	CONST_TYPE_PREFERENCES AS FPGroupType
	FROM Temp_Preferences AS tmpDt
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpDt.PreferencesCode = tmpQue.PreferencesCode
	WHERE tmpQue.FPPatternID01 IS NOT NULL;    
    
    INSERT IGNORE INTO Temp_FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpQue.FPPatternID02
		,	CONST_TYPE_PATTERN02 AS FPPatternType
		,	tmpDt.FPGroupPreferencesID
		,	CONST_TYPE_PREFERENCES AS FPGroupType
	FROM Temp_Preferences AS tmpDt
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpDt.PreferencesCode = tmpQue.PreferencesCode
	WHERE tmpQue.FPPatternID02 IS NOT NULL;
    
	#=================FPPatternGroup=========================
    INSERT IGNORE INTO DCS_DataCenter.FPPatternGroup(FPPatternID, FPPatternType, FPGroupID, FPGroupType)
    SELECT	tmpPg.FPPatternID
		,	tmpPg.FPPatternType
        ,	tmpPg.FPGroupID
        ,	tmpPg.FPGroupType
    FROM Temp_FPPatternGroup AS tmpPg;
    
    #=================CLEAN QUEUE============================================
    DELETE que
    FROM DCS_DataCenter.RawFingerprintQueue AS que
		INNER JOIN Temp_RawFingerprintQueue AS tmpQue ON tmpQue.ID = que.ID;
        
END$$

DELIMITER ;
