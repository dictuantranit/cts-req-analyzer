/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_FP_DeviceEvolutionGet`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_FP_DeviceEvolutionGet`(
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
            CALL DCS_DataCenter.DCS_DC_Transform_FP_DeviceEvolutionGet(50);
	*/
    DECLARE CONST_MINID_FP_DEVICEEVOLUTION	INT DEFAULT 23;
	DECLARE lv_Max_FP_DeviceEvolutionID  	BIGINT UNSIGNED;
    
	SET lv_Max_FP_DeviceEvolutionID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_MINID_FP_DEVICEEVOLUTION);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_DeviceFingerprintAccount;
	DROP TEMPORARY TABLE IF EXISTS Temp_GroupAccount;
	DROP TEMPORARY TABLE IF EXISTS Temp_DeviceFingerprintAccount_Ref;
    
	CREATE TEMPORARY TABLE Temp_DeviceFingerprintAccount(
			ID						BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	FP_FingerPrintID		BIGINT UNSIGNED
		,	AccountID				BIGINT UNSIGNED
		,	IDRef					LONGTEXT
	);
    
	CREATE TEMPORARY TABLE Temp_GroupAccount(
			AccountID					BIGINT UNSIGNED NOT NULL PRIMARY KEY
	);
    
	CREATE TEMPORARY TABLE Temp_DeviceFingerprintAccount_Ref(
			AccountID						BIGINT UNSIGNED NOT NULL
		,	FPDeviceFingerprintAccountID	BIGINT UNSIGNED NOT NULL
        
        , 	PRIMARY KEY (AccountID,FPDeviceFingerprintAccountID)
	);
    
    INSERT INTO Temp_DeviceFingerprintAccount(ID, FP_FingerPrintID, AccountID)
	SELECT 	ID
		,	FP_FingerPrintID
		,	AccountID
    FROM DCS_DataCenter.FP_DeviceFingerprintAccount
    WHERE ID > lv_Max_FP_DeviceEvolutionID
		AND EvolveID = 0
    ORDER BY ID ASC
    LIMIT ip_BatchSize;
    
    /* === Add index === */
	ALTER TABLE Temp_DeviceFingerprintAccount
	ADD INDEX IX_Temp_DeviceFingerprintAccount_FP_FingerPrintID (FP_FingerPrintID),
	ADD INDEX IX_Temp_DeviceFingerprintAccount_AccountID (AccountID);
    
    INSERT INTO Temp_GroupAccount(AccountID)
    SELECT DISTINCT AccountID
    FROM Temp_DeviceFingerprintAccount;
    
    INSERT INTO Temp_DeviceFingerprintAccount_Ref(AccountID, FPDeviceFingerprintAccountID)
    WITH cte_IDRef AS (
		SELECT dfaMain.ID,
			   dfaMain.AccountID,
			   ROW_NUMBER() OVER (PARTITION BY dfaMain.AccountID ORDER BY dfaMain.ID DESC) AS rn
		FROM Temp_GroupAccount AS tmpGA
			INNER JOIN DCS_DataCenter.FP_DeviceFingerprintAccount AS dfaMain ON dfaMain.AccountID = tmpGA.AccountID
		WHERE dfaMain.EvolveID > 0
	)
	SELECT 	DISTINCT
			AccountID
		,	ID AS FPDeviceFingerprintAccountID
	FROM cte_IDRef
	WHERE rn <= 10;
    
    UPDATE Temp_DeviceFingerprintAccount AS tmp
		INNER JOIN (
			SELECT 	AccountID
				, 	GROUP_CONCAT(FPDeviceFingerprintAccountID ORDER BY FPDeviceFingerprintAccountID DESC SEPARATOR ',') AS concatenatedIDs
			FROM Temp_DeviceFingerprintAccount_Ref
			GROUP BY AccountID
		) AS tmpRef ON tmp.AccountID = tmpRef.AccountID
	SET tmp.IDRef = tmpRef.concatenatedIDs;
    
	SELECT 	tmp.ID AS FPDeviceFingerprintAccountID
		,	tmp.AccountID
		,	tmp.IDRef AS FPDeviceFingerprintAccountIDRef
		,	fpe.Attribute->>'$.UserAgent' AS UserAgent
		,	fpe.Attribute->>'$.OSName' AS OSName
		,	fpe.Attribute->>'$.BrowserName' AS BrowserName
		,	fpe.Attribute->>'$.BrowserVersion' AS BrowserVersion
		,	fpe.Attribute->>'$.Platform' AS Platform
		,	fpe.Attribute->>'$.Accept' AS Accept
		,	fpe.Attribute->>'$.Encoding' AS Encoding
		,	fpe.Attribute->>'$.Headers' AS Headers
		,	fp.Attribute->>'$.LocalStorage' AS LocalStorage
		,	fp.Attribute->>'$.DoNotTrack' AS DoNotTrack
		,	fp.Attribute->>'$.CookiesEnabled' AS Cookies
		,	fp.Attribute->>'$.Canvas' AS Canvas
		,	fp.Attribute->>'$.Fonts' AS Fonts
		,	fp.Attribute->>'$.Vendor' AS Vendor
		,	fp.Attribute->>'$.WebGlBasics' AS GLRenderer
		,	fp.Attribute->>'$.Plugins' AS Plugins
		,	fp.Attribute->>'$.Languages' AS Languages
		,	fp.Attribute->>'$.ScreenResolution' AS Resolution
		,	fp.Attribute->>'$.Timezone' AS Timezone
	FROM Temp_DeviceFingerprintAccount AS tmp
		LEFT JOIN DCS_DataCenter.FP_FingerPrint AS fp ON fp.ID = tmp.FP_FingerprintID
		LEFT JOIN DCS_DataCenter.FP_EvolvedMapping AS em ON em.FP_DeviceFingerprintAccountID = tmp.ID
		LEFT JOIN DCS_DataCenter.FP_FingerPrintExtra AS fpe ON fpe.ID = em.FP_FingerPrintExtraID;
    
    WITH cte_Ref AS (
		SELECT DISTINCT FPDeviceFingerprintAccountID
		FROM Temp_DeviceFingerprintAccount_Ref
    )
    SELECT 	dfa.ID AS FPDeviceFingerprintAccountID
		,	dfa.AccountID
		,	fpe.Attribute->>'$.UserAgent' AS UserAgent
		,	fpe.Attribute->>'$.OSName' AS OSName
		,	fpe.Attribute->>'$.BrowserName' AS BrowserName
		,	fpe.Attribute->>'$.BrowserVersion' AS BrowserVersion
		,	fpe.Attribute->>'$.Platform' AS Platform
		,	fpe.Attribute->>'$.Accept' AS Accept
		,	fpe.Attribute->>'$.Encoding' AS Encoding
		,	fpe.Attribute->>'$.Headers' AS Headers
		,	fp.Attribute->>'$.LocalStorage' AS LocalStorage
		,	fp.Attribute->>'$.DoNotTrack' AS DoNotTrack
		,	fp.Attribute->>'$.CookiesEnabled' AS Cookies
		,	fp.Attribute->>'$.Canvas' AS Canvas
		,	fp.Attribute->>'$.Fonts' AS Fonts
		,	fp.Attribute->>'$.Vendor' AS Vendor
		,	fp.Attribute->>'$.WebGlBasics' AS GLRenderer
		,	fp.Attribute->>'$.Plugins' AS Plugins
		,	fp.Attribute->>'$.Languages' AS Languages
		,	fp.Attribute->>'$.ScreenResolution' AS Resolution
		,	fp.Attribute->>'$.Timezone' AS Timezone
    FROM cte_Ref AS cte
		INNER JOIN DCS_DataCenter.FP_DeviceFingerprintAccount AS dfa ON dfa.ID = cte.FPDeviceFingerprintAccountID
		INNER JOIN DCS_DataCenter.FP_FingerPrint AS fp ON fp.ID = dfa.FP_FingerprintID
		INNER JOIN DCS_DataCenter.FP_EvolvedMapping AS em ON em.FP_DeviceFingerprintAccountID = dfa.ID
		INNER JOIN DCS_DataCenter.FP_FingerPrintExtra AS fpe ON fpe.ID = em.FP_FingerPrintExtraID
	ORDER BY dfa.ID DESC;
END$$
DELIMITER ;