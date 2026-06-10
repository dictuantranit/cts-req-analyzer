/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_OpenSearch_Transaction_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_OpenSearch_Transaction_Get`(
		IN ip_BatchSize INT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20250213@Lando.Vu
	Task : Optimize and Enhance OpenSearch
	DB: DCS_DataCenter
	Original:

	Revisions:
		- 20250213@Lando.Vu: Created [Redmine ID: 217768]
		- 20250312@Lando.Vu: Ignored Subscribers [Redmine ID: 217768]
		- 20250327@Jonathan.Doan: HF - Missing transaction data when retrieving from table Transaction07 [Redmine ID: #222043]
		- 20251006@Jonathan.Doan: HF - Resolve FingerprintCode update delay [Redmine ID: 236716]
		- 20251009@Jonathan.Doan: Add field Indicate Tagging Type & FP version[Redmine ID: #240781]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataCenter.DCS_DC_OpenSearch_Transaction_Get(100);
	*/
    DECLARE CONST_DEVICETRANSFORM_MAXTRANSACTION07IDCOMPLETED	INT			DEFAULT 3;
    DECLARE CONST_OPENSEARCH_LISTIGNOREDSUBID 					INT 		DEFAULT 100;
	DECLARE CONST_OPENSEARCH_TRANSACTION07_TRANSID 				INT 		DEFAULT 101;
    
	DECLARE CONST_SCRIPTVERSIONTYPE_ACTIVATOR	 				INT 		DEFAULT 1;
	DECLARE CONST_SCRIPTVERSIONTYPE_FINGERPRINT	 				INT 		DEFAULT 2;
    
	DECLARE lv_MaxTransID  				BIGINT UNSIGNED;
	DECLARE lv_MaxTransIDCompleted		BIGINT UNSIGNED;
	DECLARE lv_ListIgnoredSubID			VARCHAR(500);
	DECLARE lv_CurrentDatetime 			DATETIME DEFAULT CURRENT_TIMESTAMP();
    
	SET lv_MaxTransID			= (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_OPENSEARCH_TRANSACTION07_TRANSID);
	SET lv_MaxTransIDCompleted	= (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_DEVICETRANSFORM_MAXTRANSACTION07IDCOMPLETED);
    SET lv_ListIgnoredSubID		= (SELECT VValue FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_OPENSEARCH_LISTIGNOREDSUBID);
    
    #============================================
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans07;
	DROP TEMPORARY TABLE IF EXISTS Temp_IgnoredSubscriberID;
	DROP TEMPORARY TABLE IF EXISTS Temp_BotDetection;
	DROP TEMPORARY TABLE IF EXISTS Temp_FPPatternID;
	DROP TEMPORARY TABLE IF EXISTS Temp_FPPattern;
    #============================================
    
    #======GET DATA FROM TRANSACTION07===========================
	CREATE TEMPORARY TABLE Temp_Trans07(
			TransID						BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	TransTime 					TIMESTAMP(4)
		,	AccountID 					BIGINT UNSIGNED
		,	LoginName 					VARCHAR(100)
		,	SubscriberID 				INT
		,	URLID 						BIGINT UNSIGNED
		,	DeviceCodeID 				BIGINT UNSIGNED
		, 	DeviceID					BIGINT UNSIGNED
		,	FirstDeviceCode 			VARCHAR(64)
		,	DeviceStatus 				TINYINT
		,	DeviceFingerprintID 		BIGINT UNSIGNED
		,	UserAgentKey 				VARCHAR(32)
		,	IP 							VARCHAR(50)
		,	IPID 						DECIMAL(50,0)
		, 	ActionResultID 				BIGINT
		,	Flagged 					SMALLINT
		,	CreatedDate 				DATETIME
		, 	InsertTime 					TIMESTAMP(4)
		,	RawTransID 					BIGINT UNSIGNED
		, 	BotDetectionValue 			BIT(32)
		,	FakeIP 						VARCHAR(100)
		, 	IsIncognitoMode 			TINYINT(1)
		,	FingerprintCode 			VARCHAR(620)
		,	DeviceCode					VARCHAR(32)
		,	UserAgent					VARCHAR(1000)
		,	BotDetection				LONGTEXT
		,	DeviceType 					VARCHAR(20)
		,	FPPatternID01 				BIGINT UNSIGNED
		,	FPPatternID02 				BIGINT UNSIGNED
		,	TransFlow 					TINYINT(1)
		,	ActivatorVersionID 			INT
		,	FingerprintVersionID		INT
		,	TaggingType 				SMALLINT
		,	WebRTCIPID 					BIGINT UNSIGNED
	);

	CREATE TEMPORARY TABLE Temp_IgnoredSubscriberID(
			SubscriberID				INT NOT NULL PRIMARY KEY
	);
    
    CREATE TEMPORARY TABLE Temp_BotDetection(
			TransID						BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	BotDetection				LONGTEXT
	);
    
	CREATE TEMPORARY TABLE Temp_FPPatternID (
		FPPatternID						BIGINT UNSIGNED PRIMARY KEY
	);
    
	CREATE TEMPORARY TABLE Temp_FPPattern (
		FPPatternID						BIGINT UNSIGNED PRIMARY KEY,
		FPGroupHardwareID				BIGINT UNSIGNED,
		FPGroupGraphicID				BIGINT UNSIGNED,
		FPGroupAudioID					BIGINT UNSIGNED,
		FPGroupBrowserID				BIGINT UNSIGNED,
		FPGroupPreferencesID			BIGINT UNSIGNED
	);
	
	#========GET INPUT DATA===========================
	SET @sql = CONCAT("INSERT IGNORE INTO Temp_IgnoredSubscriberID (SubscriberID) VALUES ('", REPLACE(lv_ListIgnoredSubID, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;

	INSERT IGNORE INTO Temp_Trans07(TransID, TransTime, AccountID, LoginName, SubscriberID, URLID, DeviceCodeID, DeviceID, FirstDeviceCode, DeviceStatus, DeviceFingerprintID, UserAgentKey, IP, IPID, ActionResultID, Flagged, CreatedDate, InsertTime, RawTransID, BotDetectionValue, FakeIP, IsIncognitoMode, FPPatternID01, FPPatternID02, TransFlow, ActivatorVersionID, FingerprintVersionID, TaggingType, WebRTCIPID)
	SELECT 	trans.TransID
		,	trans.TransTime
		,	trans.AccountID
		,	trans.LoginName
		,	trans.SubscriberID
		,	trans.URLID
		,	trans.DeviceCodeID
		,	trans.DeviceID
		,	trans.FirstDeviceCode
		,	trans.DeviceStatus
		,	trans.DeviceFingerprintID
		,	trans.UserAgentKey
		,	trans.IP
		,	trans.IPID
		,	trans.ActionResultID
		,	trans.Flagged
		,	trans.CreatedDate
		,	trans.InsertTime
		,	trans.RawTransID
		,	trans.BotDetectionValue
		,	trans.FakeIP
		,	trans.IsIncognitoMode
		,	trans.FPPatternID01
		,	trans.FPPatternID02
		,	trans.TransFlow
		,	trans.ActivatorVersionID
		,	trans.FingerprintVersionID
		,	trans.TaggingType
		,	trans.WebRTCIPID
	FROM DCS_DataCenter.Transaction07 AS trans
	WHERE trans.TransID > lv_MaxTransID
		AND trans.TransID <= lv_MaxTransIDCompleted
        AND NOT EXISTS (SELECT 1
						FROM Temp_IgnoredSubscriberID AS subs 
						WHERE subs.SubscriberID = trans.SubscriberID)
	ORDER BY trans.TransID ASC
	LIMIT ip_BatchSize;
	
	/******* Add index ********************/
	ALTER TABLE Temp_Trans07
	ADD INDEX IX_Temp_Trans07_DeviceFingerprintID_DeviceID (DeviceFingerprintID, DeviceID),
	ADD INDEX IX_Temp_Trans07_UserAgentKey (UserAgentKey);
	
	#========Fingerprint Code===========================
	UPDATE Temp_Trans07 AS trans
		INNER JOIN DCS_DataCenter.DeviceFingerprint AS df ON df.DeviceFingerprintID = trans.DeviceFingerprintID AND df.DeviceID = trans.DeviceID
	SET trans.FingerprintCode = df.FingerprintCode
	WHERE trans.DeviceFingerprintID > 0
		AND trans.DeviceID > 0;
	
	#========Useragent===========================
	UPDATE Temp_Trans07 AS trans
		INNER JOIN DCS_DataCenter.UserAgent AS ua ON ua.UserAgentKey = trans.UserAgentKey
		LEFT JOIN DCS_DataCenter.DeviceType AS dt ON dt.DeviceTypeID = ua.DeviceTypeID
	SET trans.UserAgent = ua.UserAgent,
		trans.DeviceType = dt.DeviceTypeName
	WHERE trans.UserAgentKey IS NOT NULL;
    
	#========Bot Detection===========================
	INSERT IGNORE INTO Temp_BotDetection(TransID, BotDetection)
	SELECT 	trans.TransID AS TransID
		,	GROUP_CONCAT(bd.Name ORDER BY bd.Value) AS BotDetection
	FROM Temp_Trans07 AS trans
		INNER JOIN DCS_DataCenter.BotDetection AS bd ON (trans.BotDetectionValue & bd.Value) = bd.Value
	GROUP BY trans.TransID;

	UPDATE Temp_Trans07 AS trans
		INNER JOIN Temp_BotDetection AS bd ON bd.TransID = trans.TransID
	SET trans.BotDetection = bd.BotDetection;
    
    INSERT IGNORE INTO Temp_FPPatternID(FPPatternID)
    SELECT DISTINCT FPPatternID01
	FROM Temp_Trans07
	WHERE FPPatternID01 > 0;
    
    INSERT IGNORE INTO Temp_FPPatternID(FPPatternID)
    SELECT DISTINCT FPPatternID02
	FROM Temp_Trans07
	WHERE FPPatternID02 > 0;
    
    INSERT INTO Temp_FPPattern(FPPatternID, FPGroupHardwareID, FPGroupGraphicID, FPGroupAudioID, FPGroupBrowserID, FPGroupPreferencesID)
	SELECT	a.FPPatternID
		,	MAX(CASE WHEN b.FPGroupType = 1 THEN b.FPGroupID END) AS FP1
		,	MAX(CASE WHEN b.FPGroupType = 2 THEN b.FPGroupID END) AS FP2
		,	MAX(CASE WHEN b.FPGroupType = 3 THEN b.FPGroupID END) AS FP3
		,	MAX(CASE WHEN b.FPGroupType = 4 THEN b.FPGroupID END) AS FP4
		,	MAX(CASE WHEN b.FPGroupType = 5 THEN b.FPGroupID END) AS FP5
	FROM Temp_FPPatternID AS a
		INNER JOIN DCS_DataCenter.FPPatternGroup AS b ON b.FPPatternID = a.FPPatternID
	GROUP BY a.FPPatternID;
        
	#========Return===========================
	SELECT	trans.TransID
		,	trans.TransTime
		,	trans.AccountID
		,	acc.IsCTSTransformed		AS	IsTransformed
		,	trans.LoginName
		,	trans.SubscriberID
		,	sub.SubscriberName
		,	url.URLDetails 				AS	URL
		,	trans.DeviceID
		,	trans.DeviceCodeID
		,	trans.FirstDeviceCode
		,	trans.DeviceStatus
		,	trans.FingerprintCode
		,	trans.UserAgent
		,	trans.DeviceType
		,	trans.IP
		,	CAST(trans.IPID AS CHAR) AS IPID
		,	ar.Action
		,	trans.Flagged 				AS	FlaggedID
		,	sl.ItemCode 				AS	Flagged
		,	trans.CreatedDate
		,	trans.InsertTime
		,	trans.RawTransID
		,	trans.BotDetection
		,	trans.FakeIP
		,	trans.IsIncognitoMode
		,	trans.TransFlow
		,	trans.ActivatorVersionID
		,	sv.ScriptVersion AS ActivatorVersion
		,	trans.FingerprintVersionID
		,	svFp.ScriptVersion AS FingerprintVersion
		,	trans.TaggingType
		,	trans.FPPatternID01
		,	trans.FPPatternID02
		,	fp.FPGroupHardwareID
		,	fp.FPGroupGraphicID
		,	fp.FPGroupAudioID 
		,	fp.FPGroupBrowserID 
		,	fp.FPGroupPreferencesID
		,	trans.WebRTCIPID
		,	rtc.WebRTCIPDetails
	FROM Temp_Trans07 AS trans
		LEFT JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = trans.SubscriberID
		LEFT JOIN DCS_DataCenter.StaticList AS sl ON sl.ListID = 1 AND sl.Status = 1 AND CAST(sl.ItemID AS UNSIGNED) = trans.Flagged
		LEFT JOIN DCS_DataCenter.URL AS url ON url.URLID = trans.URLID
		LEFT JOIN DCS_DataCenter.ActionResult AS ar ON ar.ActionResultID = trans.ActionResultID
		LEFT JOIN DCS_DataCenter.Account AS acc ON acc.AccountID = trans.AccountID
		LEFT JOIN DCS_DataCenter.ScriptVersion AS sv ON sv.ScriptVersionID = trans.ActivatorVersionID
		LEFT JOIN DCS_DataCenter.ScriptVersion AS svFp ON svFp.ScriptVersionID = trans.FingerprintVersionID
		LEFT JOIN Temp_FPPattern AS fp ON fp.FPPatternID = IFNULL(trans.FPPatternID02, trans.FPPatternID01)
		LEFT JOIN DCS_DataCenter.WebRTCIP AS rtc ON rtc.WebRTCIPID = trans.WebRTCIPID;
END$$
DELIMITER ;