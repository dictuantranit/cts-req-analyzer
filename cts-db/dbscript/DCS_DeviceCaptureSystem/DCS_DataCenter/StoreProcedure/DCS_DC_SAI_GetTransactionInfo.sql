/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_SAI_GetTransactionInfo`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_SAI_GetTransactionInfo`(
		IN ip_LastTransID BIGINT UNSIGNED
	,	IN ip_BatchSize INT
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20241122@Jonathan.Doan
	Task : Support return info for SAI team
	DB: DCS_DataCenter
	Original:

	Revisions:
		- 20241122@Jonathan.Doan: Get Data [Redmine ID: 214111]
		- 20241206@Jonathan.Doan: Change the data source [Redmine ID: 214111]
		- 20250327@Jonathan.Doan: HF - Missing transaction data when retrieving from table Transaction07 [Redmine ID: #222043]
		
	Param's Explanation (filtered by):

	Example:
		CALL DCS_DataCenter.DCS_DC_SAI_GetTransactionInfo(0, 10);
	*/
    DECLARE CONST_DEVICETRANSFORM_MAXTRANSACTION07IDCOMPLETED	INT	DEFAULT 3;

	DECLARE lv_MaxTransIDCompleted	BIGINT UNSIGNED;

	SET lv_MaxTransIDCompleted	= (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_DEVICETRANSFORM_MAXTRANSACTION07IDCOMPLETED);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
    
    CREATE TEMPORARY TABLE Temp_Transaction(
			TransID BIGINT UNSIGNED PRIMARY KEY
        ,	TransTime TIMESTAMP(4)
        ,	AccountID BIGINT UNSIGNED
        ,	LoginName VARCHAR(100)
        ,	SubscriberID INT
        ,	CreatedDate DATETIME
        ,	Flagged SMALLINT
        ,	UserAgentKey VARCHAR(32)
        ,	IP VARCHAR(50)
        ,	IPID DECIMAL(50,0)
        ,	URLID BIGINT UNSIGNED
        ,	ActionResultID BIGINT
        ,	TransStatus BIT(16)
        ,	InsertTime TIMESTAMP(4)
        ,	BotDetectionValue BIT(32)
        ,	BotComponentID BIGINT UNSIGNED
        ,	FakeIP VARCHAR(100)
        ,	DeviceID BIGINT UNSIGNED
        ,	DeviceCodeID BIGINT UNSIGNED
        ,	FirstDeviceCode VARCHAR(64)
        ,	DeviceStatus TINYINT
        ,	DeviceFingerprintID BIGINT UNSIGNED
        ,	CustID INT UNSIGNED
        ,	FingerprintCode VARCHAR(620)
        ,	DeviceCode VARCHAR(32)
        ,	UserAgent VARCHAR(1000)
        ,	OSName VARCHAR(100)
        ,	BrowserName VARCHAR(100)
        ,	DeviceType VARCHAR(20)
    );
    
    INSERT IGNORE INTO Temp_Transaction(TransID, TransTime, AccountID, LoginName, SubscriberID, CreatedDate, Flagged, UserAgentKey, IP, IPID, URLID, ActionResultID, TransStatus, InsertTime, BotDetectionValue, BotComponentID, FakeIP, DeviceID, DeviceCodeID, FirstDeviceCode, DeviceStatus, DeviceFingerprintID)
    SELECT 	TransID
		,	TransTime
		,	AccountID
		,	LoginName
		,	SubscriberID
		,	CreatedDate
		,	Flagged
		,	UserAgentKey
		,	IP
		,	IPID
		,	URLID
		,	ActionResultID
		,	TransStatus
		,	InsertTime
		,	BotDetectionValue
		,	BotComponentID
		,	FakeIP
		,	DeviceID
		,	DeviceCodeID
		,	FirstDeviceCode
		,	DeviceStatus
		,	DeviceFingerprintID
    FROM DCS_DataCenter.Transaction07
    WHERE TransID > ip_LastTransID
		AND TransID <= lv_MaxTransIDCompleted
    ORDER BY TransID ASC
    LIMIT ip_BatchSize;
    
    /* === Get more data for large tables === */
    UPDATE Temp_Transaction AS trans
		INNER JOIN CTS_DataCenter.CustDCSAccount AS cda ON cda.AccountID = trans.AccountID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = cda.CTSCustID
	SET trans.CustID = cus.CustID;
    
    UPDATE Temp_Transaction AS trans
		INNER JOIN DCS_DataCenter.DeviceFingerprint AS df ON df.DeviceFingerprintID = trans.DeviceFingerprintID AND df.DeviceID = trans.DeviceID
	SET trans.FingerprintCode = df.FingerprintCode;
    
    UPDATE Temp_Transaction AS trans
		INNER JOIN DCS_DataCenter.DeviceCode AS dc ON dc.DeviceCodeID = trans.DeviceCodeID
	SET trans.DeviceCode = dc.DeviceCode;
    
    UPDATE Temp_Transaction AS trans
		INNER JOIN DCS_DataCenter.UserAgent AS ua ON ua.UserAgentKey = trans.UserAgentKey
		LEFT JOIN DCS_DataCenter.OS AS os ON os.OSID = ua.OSID
		LEFT JOIN DCS_DataCenter.Browser AS br ON br.BrowserID = ua.BrowserID
		LEFT JOIN DCS_DataCenter.DeviceType AS dt ON dt.DeviceTypeID = ua.DeviceTypeID
	SET trans.UserAgent = ua.UserAgent,
		trans.OSName = os.OSName,
		trans.BrowserName = br.BrowserName,
		trans.DeviceType = dt.DeviceTypeName;
    
    /* === Return values === */
	SELECT 	trans.TransID
		,	trans.CustID
		,	trans.TransTime
		,	trans.AccountID
		,	trans.loginName
		,	trans.SubscriberID
		,	sub.SubscriberName
		,	trans.CreatedDate
		,	trans.Flagged
		,	sl.ItemName AS RobotTracking
		,	trans.UserAgentKey
		,	trans.UserAgent
		,	trans.OSName
		,	NULL AS OSVersion
		,	trans.BrowserName
		,	NULL AS BrowserVersion
		,	trans.DeviceType
		,	trans.IP
		,	CAST(trans.IPID AS CHAR) AS IPID
		,	trans.URLID
		,	url.URLDetails
		,	trans.ActionResultID
		,	ar.Action
		,	ar.ActionResult
		,	trans.TransStatus
		,	trans.InsertTime
		,	trans.BotDetectionValue
		,	trans.BotComponentID
		,	trans.FakeIP
		,	trans.DeviceID
		,	trans.DeviceCode
		,	trans.FirstDeviceCode
		,	trans.DeviceStatus
		,	trans.DeviceFingerprintID
		,	trans.FingerprintCode
	FROM Temp_Transaction AS trans
		LEFT JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = trans.SubscriberID
		LEFT JOIN DCS_DataCenter.StaticList AS sl ON sl.ListID = 1 AND sl.Status = 1 AND sl.ItemID = trans.Flagged
		LEFT JOIN DCS_DataCenter.URL AS url ON url.URLID = trans.URLID
		LEFT JOIN DCS_DataCenter.ActionResult AS ar ON ar.ActionResultID = trans.ActionResultID;
        
END$$
DELIMITER ;