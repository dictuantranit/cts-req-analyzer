/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Summary_LoginTransaction_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Summary_LoginTransaction_Insert`(
    IN ip_Size INT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231003@Jonathan.Doan
	Task : Insert data into LoginTransaction
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20231003@Jonathan.Doan: Created [Redmine ID: 194933]
		- 20231026@Jonathan.Doan: Add FlaggedGroupID [Redmine ID: 195332]
		- 20240308@Jonathan.Doan: Add more field to monitoring botd [Redmine ID: 199295]
		
	Param's Explanation (filtered by):

	Example:
		SET sql_safe_updates = 0;
        CALL DCS_DataTrace.DCS_DT_Summary_LoginTransaction_Insert(10);
	*/
    DECLARE CONST_COOKDATA_CookRawTrans07_TRANSID 	INT 		DEFAULT 6;
    DECLARE CONST_FLAGGEDGROUPID_INVALIDBROWSER		SMALLINT 	DEFAULT 2;
    DECLARE CONST_FLAGGEDGROUPID_BOTTRANS 			SMALLINT 	DEFAULT 3;
    
    DECLARE lv_MaxTransID  			BIGINT UNSIGNED;
    DECLARE lv_CurrentDatetime 		DATETIME DEFAULT CURRENT_TIMESTAMP();
    
    SET lv_MaxTransID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataTrace.SystemSetting WHERE ID = CONST_SUMMARY_TRANSID);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans07;
	DROP TEMPORARY TABLE IF EXISTS Temp_LoginTrans;
	DROP TEMPORARY TABLE IF EXISTS Temp_TotalTransByAccount;
	DROP TEMPORARY TABLE IF EXISTS Temp_TotalTransByFlagged;
    
	CREATE TEMPORARY TABLE Temp_Trans07(
			TransID						INT UNSIGNED NOT NULL PRIMARY KEY
		, 	TransDate					DATE NOT NULL
		, 	SubscriberID				INT UNSIGNED
		, 	AccountID					BIGINT UNSIGNED
		, 	DeviceID					BIGINT UNSIGNED
		, 	FPDeviceID					BIGINT UNSIGNED
		, 	RawUserAgentID				BIGINT UNSIGNED
		, 	Flagged						SMALLINT
		, 	FlaggedGroupID				SMALLINT
		, 	TransTime					DATETIME
	);
    
	CREATE TEMPORARY TABLE Temp_LoginTrans(
			ID							INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY 
		, 	TransDate					DATE NOT NULL
		, 	SubscriberID				INT UNSIGNED
		, 	AccountID					BIGINT UNSIGNED
		, 	DeviceID					BIGINT UNSIGNED
		, 	Flagged						SMALLINT
		, 	FlaggedGroupID				SMALLINT
		, 	TotalTrans					INT UNSIGNED DEFAULT 0
		, 	TotalNoDeviceTrans			INT UNSIGNED DEFAULT 0
		, 	TotalNoFPDeviceTrans		INT UNSIGNED DEFAULT 0
		, 	FirstLoginTransTime			DATETIME
		, 	LastLoginTransTime			DATETIME
		, 	IsUpdate					BIT DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_TotalTransByAccount(
			ID							INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY 
		, 	TransDate					DATE NOT NULL
		, 	SubscriberID				INT UNSIGNED
		, 	AccountID					INT UNSIGNED
		, 	TotalTrans					INT UNSIGNED DEFAULT 0
		, 	TotalInvalidBrowers			INT UNSIGNED DEFAULT 0
		, 	TotalBotTrans				INT UNSIGNED DEFAULT 0
		, 	TotalNoDeviceTrans			INT UNSIGNED DEFAULT 0
		, 	TotalNoFPDeviceTrans		INT UNSIGNED DEFAULT 0
		, 	CountUserAgent				INT UNSIGNED DEFAULT 0
		, 	CountDevice					INT UNSIGNED DEFAULT 0
		, 	IsUpdate					BIT DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_TotalTransByFlagged(
			ID							INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY 
		, 	TransDate					DATE NOT NULL
		, 	Flagged						SMALLINT UNSIGNED NOT NULL
		, 	TotalTrans					INT UNSIGNED DEFAULT 0
		, 	IsUpdate					BIT DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_TotalTransByBrowser(
			ID							INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY 
		, 	TransDate					DATE NOT NULL
		, 	BrowserID					BIGINT UNSIGNED NOT NULL
		, 	OSID						BIGINT UNSIGNED NOT NULL
		, 	DeviceTypeID				BIGINT UNSIGNED NOT NULL
		, 	TotalTrans					INT UNSIGNED DEFAULT 0
		, 	TotalInvalidBrowers			INT UNSIGNED DEFAULT 0
		, 	TotalBotTrans				INT UNSIGNED DEFAULT 0
		, 	IsUpdate					BIT DEFAULT 0
	);
    
    INSERT INTO Temp_Trans07(TransID, TransDate, AccountID, SubscriberID, DeviceID, FPDeviceID, RawUserAgentID, Flagged, TransTime)
    SELECT 	trans.TransID
		,	trans.CreatedDate AS TransDate
        ,	IFNULL(trans.AccountID, 0) AS AccountID
        ,	IFNULL(trans.SubscriberID, 0) AS SubscriberID
        ,	IFNULL(trans.DeviceID, 0) AS DeviceID
        ,	IFNULL(trans.FPDeviceID, 0) AS FPDeviceID
        ,	IFNULL(trans.RawUserAgentID, 0) AS RawUserAgentID
        ,	IFNULL(trans.Flagged, 0) AS Flagged
        ,	trans.TransTime
	FROM DCS_DataTrace.RawTransaction07 AS trans
    WHERE trans.TransID > lv_MaxTransID
    ORDER BY trans.TransID ASC
    LIMIT ip_Size;
    
    ALTER TABLE Temp_Trans07
    ADD KEY IX_Temp_Trans07_Flagged (Flagged),
    ADD KEY IX_Temp_Trans07_TransID_SubscriberID (TransID, SubscriberID);
    
    UPDATE Temp_Trans07 AS tmp
		INNER JOIN DCS_DataCenter.StaticList AS sl ON sl.ListID = 1 AND sl.ItemID = tmp.Flagged
	SET tmp.FlaggedGroupID = sl.GroupID;
    
    SET lv_MaxTransID = (SELECT MAX(TransID) FROM Temp_Trans07);
    
    /* == LoginTransaction == */
    INSERT INTO Temp_LoginTrans(TransDate, SubscriberID, AccountID, DeviceID, Flagged, FlaggedGroupID, FirstLoginTransTime, LastLoginTransTime, TotalTrans)
    SELECT 	TransDate
        ,	SubscriberID
		,	AccountID
		,	0 AS DeviceID
        ,	Flagged
        ,	MAX(FlaggedGroupID) AS FlaggedGroupID
        ,	MIN(TransTime) AS FirstLoginTransTime
        ,	MAX(TransTime) AS LastLoginTransTime
        ,	COUNT(1) AS TotalTrans
	FROM Temp_Trans07 AS tmp
    GROUP BY TransDate, SubscriberID, AccountID, Flagged;
    
    ALTER TABLE Temp_LoginTrans
    ADD KEY IX_Temp_LoginTrans_Group(TransDate, SubscriberID, AccountID, Flagged);
	
    UPDATE DCS_DataTrace.LoginTransactionSummary AS tl
		INNER JOIN Temp_LoginTrans AS tmp ON 	tl.TransDate = tmp.TransDate
											AND tl.SubscriberID = tmp.SubscriberID
											AND tl.AccountID = tmp.AccountID
											AND tl.DeviceID = tmp.DeviceID
											AND tl.Flagged = tmp.Flagged
	SET tl.TotalTrans 			= tl.TotalTrans + tmp.TotalTrans,
		tl.FirstLoginTransTime 	= tmp.FirstLoginTransTime,
		tl.LastLoginTransTime 	= tmp.LastLoginTransTime,
		tl.ModifiedTime 		= lv_CurrentDatetime,
		tmp.IsUpdate 			= 1;
    
    INSERT INTO DCS_DataTrace.LoginTransactionSummary(TransDate, SubscriberID, AccountID, DeviceID, Flagged, FlaggedGroupID, FirstLoginTransTime, LastLoginTransTime, TotalTrans, CreatedTime, ModifiedTime)
    SELECT 	tmp.TransDate
        ,	tmp.SubscriberID
		,	tmp.AccountID
		,	tmp.DeviceID
        ,	tmp.Flagged
        ,	tmp.FlaggedGroupID
        ,	tmp.FirstLoginTransTime
        ,	tmp.LastLoginTransTime
        ,	tmp.TotalTrans
        ,	lv_CurrentDatetime AS CreatedTime
        ,	lv_CurrentDatetime AS ModifiedTime
	FROM Temp_LoginTrans AS tmp
    WHERE tmp.IsUpdate = 0;

    
    /* == TotalTransByAccount == */
    INSERT INTO Temp_TotalTransByAccount(TransDate, SubscriberID, AccountID, TotalTrans, TotalInvalidBrowers, TotalBotTrans, TotalNoDeviceTrans, TotalNoFPDeviceTrans, CountUserAgent, CountDevice)
    SELECT 	TransDate
        ,	SubscriberID
        ,	AccountID
        ,	COUNT(1) AS TotalTrans
        ,	SUM(CASE WHEN FlaggedGroupID = CONST_FLAGGEDGROUPID_INVALIDBROWSER THEN 1 ELSE 0 END) AS TotalInvalidBrowers
        ,	SUM(CASE WHEN FlaggedGroupID = CONST_FLAGGEDGROUPID_BOTTRANS THEN 1 ELSE 0 END) AS TotalBotTrans
        ,	SUM(CASE WHEN DeviceID = 0 THEN 1 ELSE 0 END) AS TotalNoDeviceTrans
        ,	SUM(CASE WHEN FPDeviceID = 0 THEN 1 ELSE 0 END) AS TotalNoFPDeviceTrans
        ,	COUNT(DISTINCT RawUserAgentID) AS CountUserAgent
        ,	COUNT(DISTINCT CASE WHEN DeviceID > 0 THEN DeviceID ELSE NULL END) AS CountDevice
	FROM Temp_Trans07
    GROUP BY TransDate, SubscriberID, AccountID;
    
    ALTER TABLE Temp_TotalTransByAccount
    ADD KEY IX_Temp_TotalTransByAccount_Group(TransDate, SubscriberID, AccountID);
    
    UPDATE DCS_DataTrace.LoginTransactionSummaryByAccount AS trans
		INNER JOIN Temp_TotalTransByAccount AS tmp ON 	trans.TransDate = tmp.TransDate 
													AND trans.SubscriberID = tmp.SubscriberID
													AND trans.AccountID = tmp.AccountID
	SET 	trans.TotalTrans 			= trans.TotalTrans 				+ tmp.TotalTrans
		,	trans.TotalInvalidBrowers 	= trans.TotalInvalidBrowers 	+ tmp.TotalInvalidBrowers
		,	trans.TotalBotTrans 		= trans.TotalBotTrans 			+ tmp.TotalBotTrans
		,	trans.TotalNoDeviceTrans 	= trans.TotalNoDeviceTrans 		+ tmp.TotalNoDeviceTrans
		,	trans.TotalNoFPDeviceTrans 	= trans.TotalNoFPDeviceTrans 	+ tmp.TotalNoFPDeviceTrans
		,	trans.CountUserAgent 		= trans.CountUserAgent 			+ tmp.CountUserAgent
		,	trans.CountDevice 			= trans.CountDevice 			+ tmp.CountDevice
		,	trans.ModifiedTime 			= lv_CurrentDatetime
		,	tmp.IsUpdate = 1;
        
    INSERT INTO DCS_DataTrace.LoginTransactionSummaryByAccount(TransDate, SubscriberID, AccountID, TotalTrans, TotalInvalidBrowers, TotalBotTrans, TotalNoDeviceTrans, TotalNoFPDeviceTrans, CountUserAgent, CountDevice, CreatedTime, ModifiedTime)
    SELECT 	tmp.TransDate
        ,	tmp.SubscriberID
        ,	tmp.AccountID
        ,	tmp.TotalTrans
        ,	tmp.TotalInvalidBrowers
        ,	tmp.TotalBotTrans
        ,	tmp.TotalNoDeviceTrans
        ,	tmp.TotalNoFPDeviceTrans
        ,	tmp.CountUserAgent
        ,	tmp.CountDevice
        ,	lv_CurrentDatetime AS CreatedTime
        ,	lv_CurrentDatetime AS ModifiedTime
	FROM Temp_TotalTransByAccount AS tmp
    WHERE tmp.IsUpdate = 0;
    
    /* == TotalTransByFlagged == */
    INSERT INTO Temp_TotalTransByFlagged(TransDate, Flagged, TotalTrans)
    SELECT 	TransDate
        ,	Flagged
        ,	COUNT(1) AS TotalTrans
	FROM Temp_Trans07
    GROUP BY TransDate, Flagged;
    
    ALTER TABLE Temp_TotalTransByFlagged
    ADD KEY IX_Temp_TotalTransByFlagged_Group(TransDate, Flagged);
    
    UPDATE DCS_DataTrace.LoginTransactionSummaryByFlagged AS trans
		INNER JOIN Temp_TotalTransByFlagged AS tmp ON 	trans.TransDate = tmp.TransDate 
													AND trans.Flagged = tmp.Flagged
	SET 	trans.TotalTrans 			= trans.TotalTrans + tmp.TotalTrans
		,	trans.ModifiedTime 			= lv_CurrentDatetime
		,	tmp.IsUpdate = 1;
        
    INSERT INTO DCS_DataTrace.LoginTransactionSummaryByFlagged(TransDate, Flagged, TotalTrans, CreatedTime, ModifiedTime)
    SELECT 	tmp.TransDate
        ,	tmp.Flagged
        ,	tmp.TotalTrans
        ,	lv_CurrentDatetime AS CreatedTime
        ,	lv_CurrentDatetime AS ModifiedTime
	FROM Temp_TotalTransByFlagged AS tmp
    WHERE tmp.IsUpdate = 0;
    
    /* == TotalTransByBrowser == */
    INSERT INTO Temp_TotalTransByBrowser(TransDate, BrowserID, OSID, DeviceTypeID, TotalTrans, TotalInvalidBrowers, TotalBotTrans)
    SELECT 	tmp.TransDate
        ,	ua.BrowserID
        ,	ua.OSID
        ,	ua.DeviceTypeID
        ,	COUNT(1) AS TotalTrans
        ,	SUM(CASE WHEN tmp.FlaggedGroupID = CONST_FLAGGEDGROUPID_INVALIDBROWSER THEN 1 ELSE 0 END) AS TotalInvalidBrowers
        ,	SUM(CASE WHEN tmp.FlaggedGroupID = CONST_FLAGGEDGROUPID_BOTTRANS THEN 1 ELSE 0 END) AS TotalBotTrans
	FROM Temp_Trans07 AS tmp
		INNER JOIN DCS_DataTrace.RawUserAgent AS ua ON ua.ID = tmp.RawUserAgentID
    GROUP BY TransDate, BrowserID, OSID, DeviceTypeID;
    
    ALTER TABLE Temp_TotalTransByBrowser
    ADD KEY IX_Temp_TotalTransByBrowser_Group(TransDate, BrowserID, OSID, DeviceTypeID);
    
    UPDATE DCS_DataTrace.LoginTransactionSummaryByBrowser AS trans
		INNER JOIN Temp_TotalTransByBrowser AS tmp ON 	trans.TransDate 	= tmp.TransDate 
													AND trans.BrowserID 	= tmp.BrowserID
													AND trans.OSID 			= tmp.OSID
													AND trans.DeviceTypeID 	= tmp.DeviceTypeID
	SET 	trans.TotalTrans 			= trans.TotalTrans + tmp.TotalTrans
		,	trans.TotalInvalidBrowers 	= trans.TotalInvalidBrowers + tmp.TotalInvalidBrowers
		,	trans.TotalBotTrans 		= trans.TotalBotTrans + tmp.TotalBotTrans
		,	trans.ModifiedTime 			= lv_CurrentDatetime
		,	tmp.IsUpdate = 1;
        
    INSERT INTO DCS_DataTrace.LoginTransactionSummaryByBrowser(TransDate, BrowserID, OSID, DeviceTypeID, TotalTrans, TotalInvalidBrowers, TotalBotTrans, CreatedTime, ModifiedTime)
    SELECT 	tmp.TransDate
        ,	tmp.BrowserID
        ,	tmp.OSID
        ,	tmp.DeviceTypeID
        ,	tmp.TotalTrans
        ,	tmp.TotalInvalidBrowers
        ,	tmp.TotalBotTrans
        ,	lv_CurrentDatetime AS CreatedTime
        ,	lv_CurrentDatetime AS ModifiedTime
	FROM Temp_TotalTransByBrowser AS tmp
    WHERE tmp.IsUpdate = 0;
    
    
    /* == Update SystemSetting == */
    IF(lv_MaxTransID IS NOT NULL AND lv_MaxTransID > 0) THEN
        UPDATE DCS_DataTrace.SystemSetting 
        SET VValue = lv_MaxTransID
        WHERE ID = CONST_SUMMARY_TRANSID;
    END IF;
END$$
DELIMITER ;
