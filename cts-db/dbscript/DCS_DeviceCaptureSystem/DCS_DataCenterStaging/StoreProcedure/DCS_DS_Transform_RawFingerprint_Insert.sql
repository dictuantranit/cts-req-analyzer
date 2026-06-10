/*<info serverAlias="CTSMain-DCS_DataCenterStaging" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DS_Transform_RawFingerprint_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DS_Transform_RawFingerprint_Insert`(
		IN ip_RawFPDetails	LONGTEXT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20250822@Casey.Huynh
		Task : Insert to Raw Details Table 
		DB: DCS_DataCenterStaging
		Original:

		Revisions:
            - 20250826@Casey.Huynh: Created, AI Power Device Fingerprint AND Remove FPJs [Redmine ID: #236716]
			- 20251010@Jonathan.Doan: Add field Indicate Tagging Type & FP version[Redmine ID: #240781]

		Param's Explanation (filtered by):
        
		Example:
			CALL DCS_DS_Transform_RawFingerprint_Insert('[{"FPPatternCode01":"FPPatternCode01Sample","FPPatternCode02":"FPPatternCode02Sample","HardwareCode":"7ca71ebf7ca71ebf7ca71ebf7ca71ebf","GraphicCode":"77ad7e6477ad7e6477ad7e6477ad7e64","AudioCode":"ff61404dff61404dff61404dff61404d","BrowserCode":"b500f57fb500f57fb500f57fb500f57f","PreferencesCode":"6f0147036f0147036f0147036f014703","HardwareDetails":"Hw","GraphicDetails":"Gp","AudioDetails":"Au","BrowserDetails":"Br","PreferencesDetails":"Pf","CreatedDate":"2025-09-23T00:00:00"}]');
	*/
    
    DECLARE CONST_FPPATTERNTYPE01	INT DEFAULT 1;
    DECLARE CONST_FPPATTERNTYPE02	INT DEFAULT 2;
    
    DECLARE CONST_TYPE_HARDWARE		INT DEFAULT 1;
    DECLARE CONST_TYPE_GRAPHIC		INT DEFAULT 2;
    DECLARE CONST_TYPE_AUDIO		INT DEFAULT 3;
    DECLARE CONST_TYPE_BROWSER		INT DEFAULT 4;
    DECLARE CONST_TYPE_PREFERENCES	INT DEFAULT 5;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_FPPattern;
	CREATE TEMPORARY TABLE Temp_FPPattern(
			ID					BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY 
		,	FPPatternCode01		VARCHAR(32)
		,	FPPatternCode02 	VARCHAR(32)
        ,	FPPatternID01		BIGINT UNSIGNED
		,	FPPatternID02 		BIGINT UNSIGNED
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
		,	CreatedDate			DATE NOT NULL
		
		,	INDEX IX_Temp_FPPattern_FPPatternCode01(FPPatternCode01)
        ,	INDEX IX_Temp_FPPattern_FPPatternCode02(FPPatternCode02)
	);
  
	DROP TEMPORARY TABLE IF EXISTS Temp_ExistingFPPattern;
    CREATE TEMPORARY TABLE Temp_ExistingFPPattern(
			FPPatternID		BIGINT UNSIGNED
		,	FPPatternType	TINYINT COMMENT 'Pattern Group Combinition'
		,	FPPatternCode	VARCHAR(32) 
        ,	NewUsedDate		DATE
        
        ,	PRIMARY KEY ID_Temp_ExistingFPPattern_FPPatternTypeCode(FPPatternType, FPPatternCode)
        ,	INDEX IX_Temp_ExistingFPPattern_FPPatternID(FPPatternID)
    );

	INSERT INTO Temp_FPPattern(FPPatternCode01, FPPatternCode02, HardwareCode, GraphicCode, AudioCode, BrowserCode, PreferencesCode, HardwareDetails, GraphicDetails, AudioDetails, BrowserDetails, PreferencesDetails, CreatedDate)
	SELECT	js.FPPatternCode01
		,	js.FPPatternCode02
		,	js.HardwareCode
		,	js.GraphicCode
		,	js.AudioCode
		,	js.BrowserCode
		,	js.PreferencesCode
		,	js.HardwareDetails
		,	js.GraphicDetails
		,	js.AudioDetails
		,	js.BrowserDetails
		,	js.PreferencesDetails
		,	js.CreatedDate
	FROM	JSON_TABLE(
			ip_RawFPDetails,
			 "$[*]" COLUMNS(
								FPPatternCode01		VARCHAR(32) 	PATH "$.FPPatternCode01"
                            ,	FPPatternCode02		VARCHAR(32) 	PATH "$.FPPatternCode02"
                            ,	HardwareCode		VARCHAR(32) 	PATH "$.HardwareCode"
                            ,	GraphicCode			VARCHAR(32) 	PATH "$.GraphicCode"
                            ,	AudioCode			VARCHAR(32) 	PATH "$.AudioCode"
                            ,	BrowserCode			VARCHAR(32) 	PATH "$.BrowserCode"
                            ,	PreferencesCode		VARCHAR(32) 	PATH "$.PreferencesCode"
                            ,	HardwareDetails		LONGTEXT 		PATH "$.HardwareDetails"
                            ,	GraphicDetails		LONGTEXT 		PATH "$.GraphicDetails"
                            ,	AudioDetails		LONGTEXT 		PATH "$.AudioDetails"
                            ,	BrowserDetails		LONGTEXT 		PATH "$.BrowserDetails"
                            ,	PreferencesDetails	LONGTEXT 		PATH "$.PreferencesDetails"
                            
                            ,	CreatedDate			DATE			PATH "$.CreatedDate"
				)
		   ) AS js; 	

	#======GET EXISTING Pattern============
	INSERT IGNORE INTO Temp_ExistingFPPattern(FPPatternID, FPPatternType, FPPatternCode, NewUsedDate)
	SELECT 	fp.FPPatternID
		,	fp.FPPatternType
        ,	fp.FPPatternCode
		,	tmpFp.CreatedDate AS NewUsedDate
	FROM Temp_FPPattern AS tmpFp
		INNER JOIN DCS_DataCenterStaging.FPPattern AS fp ON fp.FPPatternType = CONST_FPPATTERNTYPE01 AND fp.FPPatternCode = tmpFp.FPPatternCode01
	WHERE tmpFp.FPPatternCode01 IS NOT NULL ;        

	INSERT IGNORE INTO Temp_ExistingFPPattern(FPPatternID, FPPatternType, FPPatternCode, NewUsedDate)
	SELECT 	fp.FPPatternID
		,	fp.FPPatternType
        ,	fp.FPPatternCode
		,	tmpFp.CreatedDate AS NewUsedDate
	FROM Temp_FPPattern AS tmpFp
		INNER JOIN DCS_DataCenterStaging.FPPattern AS fp ON fp.FPPatternType = CONST_FPPATTERNTYPE02 AND fp.FPPatternCode = tmpFp.FPPatternCode02
	WHERE tmpFp.FPPatternCode02 IS NOT NULL ;
	
	#======UPDATE FOR EXISTING Pattern LastUsedDate============    
	UPDATE  DCS_DataCenterStaging.FPPattern AS fp
		INNER JOIN Temp_ExistingFPPattern AS tmpEx ON tmpEx.FPPatternID = fp.FPPatternID
	SET fp.LastUsedDate = tmpEx.NewUsedDate
	WHERE fp.LastUsedDate < tmpEx.NewUsedDate;     

	#======INSERT FPPattern=============================
	INSERT IGNORE INTO DCS_DataCenterStaging.FPPattern(FPPatternType, FPPatternCode, CreatedDate, LastUsedDate)
	SELECT DISTINCT CONST_FPPATTERNTYPE01 AS FPPatternType
		,	tmpPt.FPPatternCode01 AS FPPatternCode
		,	DATE(tmpPt.CreatedDate) AS CreatedDate
		,	DATE(tmpPt.CreatedDate) AS LastUsedDate
	FROM Temp_FPPattern AS tmpPt
		LEFT JOIN Temp_ExistingFPPattern AS tmpEx ON tmpEx.FPPatternCode = tmpPt.FPPatternCode01
	WHERE	tmpEx.FPPatternType IS NULL
		AND tmpPt.FPPatternCode01 IS NOT NULL
	ON DUPLICATE KEY UPDATE LastUsedDate = GREATEST(tmpPt.CreatedDate,LastUsedDate);
	
	INSERT IGNORE INTO DCS_DataCenterStaging.FPPattern(FPPatternType, FPPatternCode, CreatedDate, LastUsedDate)
	SELECT DISTINCT CONST_FPPATTERNTYPE02 AS FPPatternType
		,	tmpPt.FPPatternCode02 AS FPPatternCode
		,	DATE(tmpPt.CreatedDate) AS CreatedDate
		,	DATE(tmpPt.CreatedDate) AS LastUsedDate
	FROM Temp_FPPattern AS tmpPt
		LEFT JOIN Temp_ExistingFPPattern AS tmpEx ON tmpEx.FPPatternCode = tmpPt.FPPatternCode02
	WHERE	tmpEx.FPPatternType IS NULL
		AND tmpPt.FPPatternCode02 IS NOT NULL
	ON DUPLICATE KEY UPDATE LastUsedDate = GREATEST(tmpPt.CreatedDate,LastUsedDate);   	

   #======INSERT FPPatternGroupQueue=============================
	UPDATE Temp_FPPattern AS tmpPt
		INNER JOIN Temp_ExistingFPPattern AS tmpEx ON tmpEx.FPPatternType = CONST_FPPATTERNTYPE01 AND tmpEx.FPPatternCode = tmpPt.FPPatternCode01
    SET tmpPt.FPPatternID01 = tmpEx.FPPatternID;
    
    UPDATE Temp_FPPattern AS tmpPt
		INNER JOIN DCS_DataCenterStaging.FPPattern AS pt ON pt.FPPatternType = CONST_FPPATTERNTYPE01 AND pt.FPPatternCode = tmpPt.FPPatternCode01
    SET tmpPt.FPPatternID01 = pt.FPPatternID
    WHERE tmpPt.FPPatternID01 IS NULL;
    
	UPDATE Temp_FPPattern AS tmpPt
		INNER JOIN Temp_ExistingFPPattern AS tmpEx ON tmpEx.FPPatternType = CONST_FPPATTERNTYPE02 AND tmpEx.FPPatternCode = tmpPt.FPPatternCode02
    SET tmpPt.FPPatternID02 = tmpEx.FPPatternID;     
    
    UPDATE Temp_FPPattern AS tmpPt
		INNER JOIN DCS_DataCenterStaging.FPPattern AS pt ON pt.FPPatternType = CONST_FPPATTERNTYPE02 AND pt.FPPatternCode = tmpPt.FPPatternCode02
    SET tmpPt.FPPatternID02 = pt.FPPatternID
    WHERE tmpPt.FPPatternID02 IS NULL;

	INSERT IGNORE INTO DCS_DataCenterStaging.RawFingerprintQueue(FPPatternID01, FPPatternID02, HardwareCode, GraphicCode, AudioCode, BrowserCode, PreferencesCode,  HardwareDetails, GraphicDetails, AudioDetails, BrowserDetails, PreferencesDetails, CreatedDate)
	SELECT	tmpPt.FPPatternID01 AS FPPatternID01
		,	tmpPt.FPPatternID02  AS FPPatternID02
        ,	tmpPt.HardwareCode
        ,	tmpPt.GraphicCode
        ,	tmpPt.AudioCode
        ,	tmpPt.BrowserCode
        ,	tmpPt.PreferencesCode
		,	tmpPt.HardwareDetails
		,	tmpPt.GraphicDetails
		,	tmpPt.AudioDetails
		,	tmpPt.BrowserDetails
		,	tmpPt.PreferencesDetails
        ,	tmpPt.CreatedDate
	FROM Temp_FPPattern AS tmpPt
    WHERE (tmpPt.HardwareCode IS NOT NULL
            OR tmpPt.GraphicCode IS NOT NULL
            OR tmpPt.AudioCode IS NOT NULL
            OR tmpPt.BrowserCode IS NOT NULL
            OR tmpPt.PreferencesCode IS NOT NULL);
  
END$$

DELIMITER ;
