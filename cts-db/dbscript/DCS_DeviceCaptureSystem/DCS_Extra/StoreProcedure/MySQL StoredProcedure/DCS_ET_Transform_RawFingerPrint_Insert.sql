/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transform_RawFingerPrint_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transform_RawFingerPrint_Insert`(
	IN ip_TableName VARCHAR(50)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230809@Jonathan.Doan
		Task :		Insert into RawFingerPrint, FingerprintAttribute, BrowserInstance
		DB:			DCS_Extra
		Original:

		Revisions:
			- 20231108@Jonathan.Doan: Created [Redmine ID: #196570]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Transform_RawFingerPrint_Insert('Temp_Transaction');
    
    */
    DECLARE lv_CurrentDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_InputData;
	DROP TEMPORARY TABLE IF EXISTS Temp_FingerPrintAttribute;
    
	CREATE TEMPORARY TABLE Temp_InputData(
			TmpID			 			INT NOT NULL 
		,	FingerprintAttribute		JSON NULL
        
        ,	PRIMARY KEY (TmpID)
    );
    
	CREATE TEMPORARY TABLE Temp_FingerPrintAttribute(
			TmpID 									INT 				NOT NULL 
		,	RawFingerPrintID						BIGINT UNSIGNED 	NULL
		,	BrowserInstanceID						BIGINT UNSIGNED 	NULL
		,	Attribute								LONGTEXT	 		NULL
		,	FingerPrintCode							VARCHAR(64) 		NULL
		,	BrowserInstanceCode						VARCHAR(64) 		NULL
		,	BrowserFamilyCode						VARCHAR(64) 		NULL
		,	Accept									VARCHAR(200)	 	NULL
		,	Encoding								VARCHAR(200)	 	NULL
		,	Headers									VARCHAR(500)	 	NULL
		,	OSName									VARCHAR(100)	 	NULL
		,	BrowserName								VARCHAR(100)	 	NULL
		,	BrowserVersion							VARCHAR(50)	 		NULL
		,	Platform								VARCHAR(45)	 		NULL
		,	UserAgent								LONGTEXT	 		NULL
		,	IsNewRawFingerPrint						TINYINT		 		DEFAULT 1
		,	IsNewFingerPrintAttribute				TINYINT		 		DEFAULT 1
		,	IsNewBrowserInstance					TINYINT		 		DEFAULT 1
		,	IsNewBrowserInstanceRawFingerPrint		TINYINT		 		DEFAULT 1
        
        ,	PRIMARY KEY (TmpID)
    );
    
    /*******InputData********************/
	SET @sql = CONCAT('INSERT IGNORE INTO Temp_InputData(TmpID, FingerprintAttribute) 
						SELECT DISTINCT ID, FingerprintAttribute
                        FROM ', ip_TableName, 
					' WHERE IFNULL(FingerprintAttribute,'''') != '''' ');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    /*******FingerPrintAttribute********************/
    INSERT INTO Temp_FingerPrintAttribute(TmpID, Attribute, FingerPrintCode, BrowserInstanceCode, BrowserFamilyCode, Accept, Encoding, Headers, OSName, BrowserName, BrowserVersion, Platform, UserAgent)
    SELECT 	TmpID
		,	FingerprintAttribute->>'$.Attribute'
		,	FingerprintAttribute->>'$.FingerPrintCode'
		,	FingerprintAttribute->>'$.BrowserInstanceCode'
		,	FingerprintAttribute->>'$.BrowserFamilyCode'
		,	FingerprintAttribute->>'$.Accept'
		,	FingerprintAttribute->>'$.Encoding'
		,	FingerprintAttribute->>'$.Headers'
		,	FingerprintAttribute->>'$.OSName'
		,	FingerprintAttribute->>'$.BrowserName'
		,	FingerprintAttribute->>'$.BrowserVersion'
		,	FingerprintAttribute->>'$.Platform'
		,	FingerprintAttribute->>'$.UserAgent'
    FROM Temp_InputData;
    
    DELETE FROM Temp_FingerPrintAttribute
    WHERE FingerPrintCode = '' 
		OR FingerPrintCode = 'null';
	
    /******* INDEX 1 FingerPrintCode********************/
	ALTER TABLE Temp_FingerPrintAttribute
	ADD INDEX IX_Temp_FingerPrintAttribute_FingerPrintCode(FingerPrintCode),
	ADD INDEX IX_Temp_FingerPrintAttribute_BrowserInstanceCode(BrowserInstanceCode);
    
    /*******RawFingerPrint********************/    
    UPDATE Temp_FingerPrintAttribute AS tmp
		INNER JOIN DCS_Extra.RawFingerPrint AS fp ON fp.FingerPrintCode = tmp.FingerPrintCode
    SET tmp.IsNewRawFingerPrint = 0;
    
    INSERT IGNORE INTO DCS_Extra.RawFingerPrint(FingerPrintCode, CreatedDate)
	SELECT	DISTINCT 
			FingerPrintCode
        ,	lv_CurrentDate AS CreatedDate
	FROM Temp_FingerPrintAttribute
    WHERE IsNewRawFingerPrint = 1;
    
	UPDATE Temp_FingerPrintAttribute AS tmp
		INNER JOIN DCS_Extra.RawFingerPrint AS fp ON fp.FingerPrintCode = tmp.FingerPrintCode
	SET tmp.RawFingerPrintID = fp.ID;
	
    /******* INDEX 2 RawFingerPrintID********************/
	ALTER TABLE Temp_FingerPrintAttribute
	ADD INDEX IX_Temp_FingerPrintAttribute_RawFingerPrintID(RawFingerPrintID);
    
    /******* BrowserInstance ********************/      
    UPDATE Temp_FingerPrintAttribute AS tmp
		INNER JOIN DCS_Extra.BrowserInstance AS bi ON bi.BrowserInstanceCode = tmp.BrowserInstanceCode
    SET tmp.IsNewBrowserInstance = 0;
    
    INSERT IGNORE INTO DCS_Extra.BrowserInstance(BrowserInstanceCode, BrowserFamilyCode, UserAgent, OSName, BrowserName, BrowserVersion, Platform, Accept, Encoding, Headers, CreatedDate)
    SELECT	tmp.BrowserInstanceCode
		,	tmp.BrowserFamilyCode
		,	tmp.UserAgent
		,	tmp.OSName
		,	tmp.BrowserName
		,	tmp.BrowserVersion
		,	tmp.Platform
		,	tmp.Accept
		,	tmp.Encoding
		,	tmp.Headers
		,	lv_CurrentDate AS CreatedDate
	FROM Temp_FingerPrintAttribute AS tmp
    WHERE tmp.BrowserInstanceCode != ''
		AND tmp.BrowserInstanceCode != 'null'
        AND tmp.IsNewBrowserInstance = 1;
    
	UPDATE Temp_FingerPrintAttribute AS tmp
		INNER JOIN DCS_Extra.BrowserInstance AS bi ON bi.BrowserInstanceCode = tmp.BrowserInstanceCode
	SET tmp.BrowserInstanceID = bi.ID;
	
    /******* INDEX 3 BrowserInstanceID********************/
	ALTER TABLE Temp_FingerPrintAttribute
	ADD INDEX IX_Temp_FingerPrintAttribute_BrowserInstanceID(BrowserInstanceID);
    
    /******* BrowserInstanceRawFingerPrint ********************/
    UPDATE Temp_FingerPrintAttribute AS tmp
		INNER JOIN DCS_Extra.BrowserInstanceRawFingerPrint AS bifp ON bifp.RawFingerPrintID = tmp.RawFingerPrintID AND bifp.BrowserInstanceID = tmp.BrowserInstanceID
    SET tmp.IsNewBrowserInstanceRawFingerPrint = 0;
    
    INSERT IGNORE INTO DCS_Extra.BrowserInstanceRawFingerPrint(RawFingerPrintID, BrowserInstanceID)
    SELECT 	RawFingerPrintID
		,	BrowserInstanceID
    FROM Temp_FingerPrintAttribute
    WHERE IsNewBrowserInstanceRawFingerPrint = 1;
    
    /*******FingerPrintAttribute********************/
    UPDATE Temp_FingerPrintAttribute AS tmp
		INNER JOIN DCS_Extra.FingerPrintAttribute AS fpa ON fpa.RawFingerPrintID = tmp.RawFingerPrintID
    SET tmp.IsNewFingerPrintAttribute = 0;
    
    INSERT IGNORE INTO DCS_Extra.FingerPrintAttribute(RawFingerPrintID, DoNotTrack, GLRenderer, Audio, Canvas, ColorDepth, ColorGamut, Contrast, Cookies, CpuClass, DeviceMemory, DomBlockers, FontPreferencePrint, Fonts, ForcedColors, HardwareConcurrency, HDR, IndexedDB, InvertedColors, Languages, LocalStorage, Math, Monochrome, OpenDatabase, OsCpu, Platform, Plugins, ReducedMotion, Resolution, SessionStorage, Timezone, TouchSupport, Vendor, VendorFlavors, WebglPrint, ApplePay, Architecture, PDFViewerEnabled, PrivateClickMeasurement, ReducedTransparency, WebGlBasics, webGlExtensions)
    SELECT	tmp.RawFingerPrintID
		,	tmp.Attribute->>'$.doNotTrack' AS DoNotTrack
		,	tmp.Attribute->>'$.webglRenderer' AS GLRenderer
		,	tmp.Attribute->>'$.audio'
		,	tmp.Attribute->>'$.canvasPrint' AS Canvas
		,	tmp.Attribute->>'$.colorDepth'
		,	tmp.Attribute->>'$.colorGamut'
		,	tmp.Attribute->>'$.contrast'
		,	CASE 	tmp.Attribute->>'$.cookiesEnabled'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS Cookies
		,	tmp.Attribute->>'$.cpuClass'
		,	CASE 	tmp.Attribute->>'$.deviceMemory'
					WHEN 'undefined' THEN -1
                    ELSE tmp.Attribute->>'$.deviceMemory' END AS deviceMemory
		,	tmp.Attribute->>'$.domBlockers'
		,	tmp.Attribute->>'$.fontPreferencePrint'
		,	tmp.Attribute->>'$.fonts'
		,	CASE 	tmp.Attribute->>'$.forcedColors'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS forcedColors
		,	CASE 	tmp.Attribute->>'$.hardwareConcurrency'
					WHEN 'undefined' THEN -1
                    ELSE tmp.Attribute->>'$.hardwareConcurrency' END AS hardwareConcurrency
		,	CASE 	tmp.Attribute->>'$.hdr'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS hdr
		,	CASE 	tmp.Attribute->>'$.indexedDB'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS indexedDB
		,	CASE 	tmp.Attribute->>'$.invertedColors'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS invertedColors
		,	tmp.Attribute->>'$.languagesPrint' AS Languages
		,	CASE 	tmp.Attribute->>'$.localStorage'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS localStorage
		,	tmp.Attribute->>'$.math'
		,	CASE 	tmp.Attribute->>'$.monochrome'
					WHEN 'undefined' THEN -1
                    ELSE tmp.Attribute->>'$.monochrome' END AS monochrome
		,	CASE 	tmp.Attribute->>'$.openDatabase'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS openDatabase
		,	tmp.Attribute->>'$.osCpu'
		,	tmp.Attribute->>'$.platform'
		,	tmp.Attribute->>'$.plugins'
		,	CASE 	tmp.Attribute->>'$.reducedMotion'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS reducedMotion
		,	tmp.Attribute->>'$.screenPrint' AS Resolution
		,	CASE 	tmp.Attribute->>'$.sessionStorage'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS sessionStorage
		,	tmp.Attribute->>'$.timezone'
		,	tmp.Attribute->>'$.touchSupport'
		,	tmp.Attribute->>'$.vendor'
		,	tmp.Attribute->>'$.vendorFlavors'
		,	tmp.Attribute->>'$.webglPrint'
		,	tmp.Attribute->>'$.applePay'
		,	tmp.Attribute->>'$.architecture'
		,	tmp.Attribute->>'$.pdfViewerEnabled'
		,	CASE 	tmp.Attribute->>'$.privateClickMeasurement'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS privateClickMeasurement
		,	CASE 	tmp.Attribute->>'$.reducedTransparency'
					WHEN 'true' THEN 1
                    WHEN 'false' THEN 0
                    ELSE -1 END AS reducedTransparency
		,	tmp.Attribute->>'$.webGlBasics'
		,	tmp.Attribute->>'$.webGlExtensions'
	FROM Temp_FingerPrintAttribute AS tmp
    WHERE tmp.IsNewFingerPrintAttribute = 1;
    
    /* Update RawFingerPrintID */
	SET @sql = CONCAT('UPDATE ', ip_TableName,' AS tmp
						INNER JOIN Temp_FingerPrintAttribute AS tmp_fpa ON tmp_fpa.TmpID = tmp.ID
						SET tmp.RawFingerPrintID = tmp_fpa.RawFingerPrintID,
							tmp.BrowserInstanceID = tmp_fpa.BrowserInstanceID');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;
