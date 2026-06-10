/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_Transaction07_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_Transaction07_Insert`(
    IN ip_TransJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20231124@Jonathan.Doan
	    Task : Insert into Transaction07
	    DB: DCS_DataCenter
	    Original:
		 
	    Revisions:
			- 20231123@Jonathan.Doan: Integrate FPSjs Phrase 2 [Redmine: 196656]
	    Param's Explanation (filtered by):
        
        Example:
			CALL DCS_DC_Transform_Transaction07_Insert('[{"TransID":39,"DeviceID":2,"FPDeviceID":100,"DeviceCodeID":2,"FirstDeviceCode":"DC","DeviceStatus":1,"DeviceFingerprintID":1}]');
	*/
    DECLARE lv_AssociationJson LONGTEXT;
    DECLARE lv_AccountFingerPrintJson LONGTEXT;
    DECLARE lv_NewAccountDeviceJson LONGTEXT;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_InputTrans;
	DROP TEMPORARY TABLE IF EXISTS Temp_Transaction07;
        
	CREATE TEMPORARY TABLE Temp_InputTrans(
			TransID					BIGINT UNSIGNED PRIMARY KEY
		,	DeviceID				BIGINT UNSIGNED
		,	FPDeviceID				BIGINT UNSIGNED
		,	DeviceCodeID			BIGINT UNSIGNED
		,	FirstDeviceCode			VARCHAR(32)
		,	DeviceStatus			TINYINT
		,	RecoverType				TINYINT
		,	DeviceFingerprintID		BIGINT UNSIGNED
	);
        
	CREATE TEMPORARY TABLE Temp_Transaction07(
			TransID					BIGINT UNSIGNED PRIMARY KEY
		,	RawTransID				BIGINT UNSIGNED
		,	LoginName				VARCHAR(100)
		,	TransTime				TIMESTAMP(4)
		,	SubscriberID			INT
		,	AccountID				BIGINT UNSIGNED
		,	URLID					BIGINT UNSIGNED
		,	DeviceCodeID			BIGINT UNSIGNED
		,	DeviceID				BIGINT UNSIGNED
		,	FirstDeviceCode			VARCHAR(64)
		,	DeviceStatus			TINYINT
		,	DeviceFingerprintID		BIGINT UNSIGNED
		,	UserAgentKey			VARCHAR(32)
		,	IP						VARCHAR(50)
		,	IPID					DECIMAL(50,0)
		,	ActionResultID			BIGINT
		,	Flagged					SMALLINT
		,	PluginID				BIGINT
		,	TransStatus				BIT(16)
		,	CreatedDate				DATETIME
		,	InsertTime				TIMESTAMP(4)
		,	BotDetectionValue		BIT(32)
		,	BotComponentID			BIGINT UNSIGNED
		,	FakeIP					VARCHAR(100)
		,	CookieID				BIGINT UNSIGNED
		,	RawUserAgentID			BIGINT UNSIGNED
		,	RawFingerPrintID		BIGINT UNSIGNED
		,	BrowserInstanceID		BIGINT UNSIGNED
		,	FPDeviceID				BIGINT UNSIGNED
		,	RecoverType				TINYINT
	);
    
    INSERT INTO Temp_InputTrans(TransID, DeviceID, FPDeviceID, DeviceCodeID, FirstDeviceCode, DeviceStatus, RecoverType, DeviceFingerprintID)
	SELECT	tmpJs.TransID
		,	tmpJs.DeviceID
		,	tmpJs.FPDeviceID
        ,	tmpJs.DeviceCodeID
        ,	tmpJs.FirstDeviceCode
        ,	tmpJs.DeviceStatus
        ,	tmpJs.RecoverType
        ,	tmpJs.DeviceFingerprintID
    FROM JSON_TABLE(
			ip_TransJson,
			 "$[*]" COLUMNS(
							TransID					BIGINT UNSIGNED		PATH "$.TransID"
						,	DeviceID				BIGINT UNSIGNED		PATH "$.DeviceID"
						,	FPDeviceID				BIGINT UNSIGNED		PATH "$.FPDeviceID"
						,	DeviceCodeID			BIGINT UNSIGNED		PATH "$.DeviceCodeID"
						,	FirstDeviceCode			VARCHAR(32) 		PATH "$.FirstDeviceCode"
						,	DeviceStatus			TINYINT				PATH "$.DeviceStatus"
						,	RecoverType				TINYINT				PATH "$.RecoverType"
						,	DeviceFingerprintID		BIGINT UNSIGNED		PATH "$.DeviceFingerprintID"
					)
		) AS tmpJs;
    
    INSERT INTO Temp_Transaction07(TransID, RawTransID, LoginName, TransTime, SubscriberID, AccountID, URLID, DeviceCodeID, DeviceID, FPDeviceID, RecoverType, FirstDeviceCode, DeviceStatus, DeviceFingerprintID, UserAgentKey, IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, InsertTime, BotDetectionValue, BotComponentID, FakeIP, CookieID, RawUserAgentID, RawFingerPrintID, BrowserInstanceID)
	SELECT 	trans.TransID
		,	IFNULL(trans.RawTransID, trans.TransID) AS RawTransID
		,	trans.LoginName
		,	trans.TransTime
		,	trans.SubscriberID
		,	trans.AccountID
		,	trans.URLID
		,	tmp.DeviceCodeID
		,	tmp.DeviceID
		,	tmp.FPDeviceID
		,	tmp.RecoverType
		,	tmp.FirstDeviceCode
		,	tmp.DeviceStatus
		,	tmp.DeviceFingerprintID
		,	trans.UserAgentKey
		,	trans.IP
		,	trans.IPID
		,	trans.ActionResultID
		,	trans.Flagged
		,	trans.PluginID
		,	trans.TransStatus
		,	trans.CreatedDate
		,	trans.InsertTime
		,	trans.BotDetectionValue
		,	trans.BotComponentID
		,	trans.FakeIP
		,	trans.CookieID
		,	trans.RawUserAgentID
		,	trans.RawFingerPrintID
		,	trans.BrowserInstanceID
	FROM Temp_InputTrans AS tmp
		INNER JOIN DCS_DataCenter.Transaction AS trans ON trans.TransID = tmp.TransID
	WHERE tmp.DeviceID IS NOT NULL;
    
    INSERT IGNORE INTO DCS_DataCenter.Transaction07(RawTransID, LoginName, TransTime, SubscriberID, AccountID, URLID, DeviceCodeID, DeviceID, FPDeviceID, RecoverType, FirstDeviceCode, DeviceStatus, DeviceFingerprintID, UserAgentKey, IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, InsertTime, BotDetectionValue, BotComponentID, FakeIP, CookieID, RawUserAgentID, RawFingerPrintID, BrowserInstanceID)
	SELECT 	RawTransID
		,	LoginName
		,	TransTime
		,	SubscriberID
		,	AccountID
		,	URLID
		,	DeviceCodeID
		,	DeviceID
		,	FPDeviceID
		,	RecoverType
		,	FirstDeviceCode
		,	DeviceStatus
		,	DeviceFingerprintID
		,	UserAgentKey
		,	IP
		,	IPID
		,	ActionResultID
		,	Flagged
		,	PluginID
		,	TransStatus
		,	CreatedDate
		,	InsertTime
		,	BotDetectionValue
		,	BotComponentID
		,	FakeIP
		,	CookieID
		,	RawUserAgentID
		,	RawFingerPrintID
		,	BrowserInstanceID
	FROM Temp_Transaction07;
    
    /* === Insert new Association === */
    WITH cte_DistinctData AS (
		SELECT	DISTINCT
				AccountID
			,	DeviceID
			,	FPDeviceID
			,	SubscriberID
			,	TransTime
			,	CreatedDate
		FROM Temp_Transaction07
		WHERE AccountID IS NOT NULL
    )
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'AccountID'		, AccountID
				,	'DeviceID'		, DeviceID
				,	'FPDeviceID'	, FPDeviceID
				,	'SubscriberID'	, SubscriberID
				,	'CreatedTime'	, TransTime
				,	'CreatedDate'	, CreatedDate
			)
		) AS json_data
	INTO lv_AssociationJson
	FROM cte_DistinctData;
    
    SET lv_AssociationJson = IFNULL(lv_AssociationJson,'[{}]');
	CALL DCS_DC_Transform_Association_Insert(lv_AssociationJson);
    
    /* === Insert new AccountFingerPrint === */
    WITH cte_DistinctData AS (
		SELECT	DISTINCT
				AccountID
			,	RawFingerPrintID
		FROM Temp_Transaction07
		WHERE AccountID IS NOT NULL
			AND RawFingerPrintID IS NOT NULL
    )
    SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'AccountID'				, AccountID
				,	'RawFingerPrintID'		, RawFingerPrintID
			)
		) AS json_data
	INTO lv_AccountFingerPrintJson
	FROM cte_DistinctData;
    
    SET lv_AccountFingerPrintJson = IFNULL(lv_AccountFingerPrintJson,'[{}]');
	CALL DCS_DC_Identity_AccountFingerPrint_Insert(lv_AccountFingerPrintJson);
    
    /* === Insert into NewAccountDevice === */
    WITH cte_DistinctData AS (
		SELECT	DISTINCT
				AccountID
			,	DeviceID
            ,	SubscriberID
            ,	RawTransID
            ,	CreatedDate
            ,	LoginName
            ,	TransTime
            ,	UserAgentKey
            ,	IP
		FROM Temp_Transaction07
		WHERE AccountID IS NOT NULL
			AND DeviceID IS NOT NULL
    )
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'AccountID'			, AccountID
				,	'DeviceID'			, DeviceID
				,	'SubscriberID'		, SubscriberID
				,	'RawTransID'		, RawTransID
				,	'CreatedDate'		, CreatedDate
				,	'LoginName'			, LoginName
				,	'TransTime'			, TransTime
				,	'UserAgentKey'		, UserAgentKey
				,	'IP'				, IP
			)
		) AS json_data
	INTO lv_NewAccountDeviceJson
	FROM cte_DistinctData;
    
    SET lv_NewAccountDeviceJson = IFNULL(lv_NewAccountDeviceJson,'[{}]');
	CALL DCS_DC_Transform_NewAccountDevice_Insert(lv_NewAccountDeviceJson);
	
	DELETE trans
	FROM DCS_DataCenter.Transaction AS trans
		INNER JOIN Temp_Transaction07 AS tmp ON tmp.TransID = trans.TransID;
END$$

DELIMITER ;
