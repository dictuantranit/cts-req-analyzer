/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Summary_LoginTransaction_CookData`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Summary_LoginTransaction_CookData`(
    IN ip_BatchSize INT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231003@Jonathan.Doan
	Task : Cook data from table RawTransaction07
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20240314@Jonathan.Doan: Created [Redmine ID: 199295]
		- 20240503@Jonathan.Doan: HotFix FlaggedGroupID is incorrect [Redmine ID: 204733]
		- 20240924@Jonathan.Doan: Add table LoginTransactionSummaryByDevice [Redmine ID: #211161]
		- 20240806@Jonathan.Doan: Change data flow v6 [Redmine ID: #206403]
		- 20250327@Jonathan.Doan: HF - Missing transaction data when retrieving from table Transaction07 [Redmine ID: #222043]
        - 20250909@Jonathan.Doan: Remove FP code [Redmine ID: #236716]
		
	Param's Explanation (filtered by):

	Example:
		SET sql_safe_updates = 0;
        CALL DCS_DataTrace.DCS_DT_Summary_LoginTransaction_CookData(10);
	*/
    DECLARE CONST_DEVICETRANSFORM_MAXTRANSACTION07IDCOMPLETED	INT			DEFAULT 3;
    DECLARE CONST_COOKDATA_TRANSACTION07_TRANSID 				INT 		DEFAULT 5;
    DECLARE CONST_COOKDATA_BYDEVICE_LISTSUBID 					INT 		DEFAULT 7;
    
    DECLARE CONST_FLAGGEDGROUPID_INVALIDBROWSER					SMALLINT 	DEFAULT 2;
    DECLARE CONST_FLAGGEDGROUPID_BOTTRANS 						SMALLINT 	DEFAULT 3;
    
	DECLARE lv_MaxTransIDCompleted	BIGINT UNSIGNED;
    DECLARE lv_MaxTransID  			BIGINT UNSIGNED;
    DECLARE lv_RawUserAgentIDs		LONGTEXT;
    DECLARE lv_ListSubID			VARCHAR(500);
    DECLARE lv_CurrentDatetime 		DATETIME DEFAULT CURRENT_TIMESTAMP();
    
	SET lv_MaxTransIDCompleted	= (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_DEVICETRANSFORM_MAXTRANSACTION07IDCOMPLETED);
    SET lv_MaxTransID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataTrace.SystemSetting WHERE ID = CONST_COOKDATA_TRANSACTION07_TRANSID);
    SET lv_ListSubID = (SELECT VValue FROM DCS_DataTrace.SystemSetting WHERE ID = CONST_COOKDATA_BYDEVICE_LISTSUBID);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans07;
	DROP TEMPORARY TABLE IF EXISTS Temp_LoginTrans;
	DROP TEMPORARY TABLE IF EXISTS Temp_TotalTransByAccount;
	DROP TEMPORARY TABLE IF EXISTS Temp_TotalTransByFlagged;
	DROP TEMPORARY TABLE IF EXISTS Temp_TotalTransByDevice;
	DROP TEMPORARY TABLE IF EXISTS Temp_SubscriberID;
    
	CREATE TEMPORARY TABLE Temp_Trans07(
			TransID						BIGINT UNSIGNED NOT NULL PRIMARY KEY
		, 	TransDate					DATE NOT NULL
		, 	SubscriberID				INT UNSIGNED
		, 	AccountID					BIGINT UNSIGNED
		, 	DeviceID					BIGINT UNSIGNED
		, 	Flagged						SMALLINT
		, 	FlaggedGroupID				SMALLINT
		, 	TransTime					DATETIME
		, 	IsInvalidBrowers			BIT DEFAULT 0
		, 	IsBotTrans					BIT DEFAULT 0
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
		, 	FirstLoginTransTime			DATETIME
		, 	LastLoginTransTime			DATETIME
		, 	IsUpdate					BIT DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_TotalTransByAccount(
			ID							INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY 
		, 	TransDate					DATE NOT NULL
		, 	SubscriberID				INT UNSIGNED
		, 	AccountID					BIGINT UNSIGNED
		, 	TotalTrans					INT UNSIGNED DEFAULT 0
		, 	TotalInvalidBrowers			INT UNSIGNED DEFAULT 0
		, 	TotalBotTrans				INT UNSIGNED DEFAULT 0
		, 	TotalNoDeviceTrans			INT UNSIGNED DEFAULT 0
		, 	IsUpdate					BIT DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_TotalTransByFlagged(
			ID							INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY 
		, 	TransDate					DATE NOT NULL
		, 	Flagged						SMALLINT UNSIGNED NOT NULL
		, 	TotalTrans					INT UNSIGNED DEFAULT 0
		, 	IsUpdate					BIT DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_TotalTransByDevice(
			ID							INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY 
		, 	TransDate					DATE NOT NULL
		, 	SubscriberID				INT UNSIGNED
		, 	AccountID					BIGINT UNSIGNED
		, 	DeviceID					BIGINT UNSIGNED
		, 	TotalTrans					INT UNSIGNED DEFAULT 0
		, 	IsUpdate					BIT DEFAULT 0
	);
    
	CREATE TEMPORARY TABLE Temp_SubscriberID(
			SubscriberID				INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY
	);
    
    SET @sql = CONCAT("INSERT IGNORE INTO Temp_SubscriberID (SubscriberID) VALUES ('", REPLACE(lv_ListSubID, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    INSERT INTO Temp_Trans07(TransID, TransDate, AccountID, SubscriberID, DeviceID, Flagged, TransTime)
    SELECT 	TransID
		,	CreatedDate AS TransDate
        ,	IFNULL(AccountID, 0) AS AccountID
        ,	IFNULL(SubscriberID, 0) AS SubscriberID
        ,	IFNULL(DeviceID, 0) AS DeviceID
        ,	IFNULL(Flagged, 0) AS Flagged
        ,	TransTime
	FROM DCS_DataCenter.Transaction07
    WHERE TransID > lv_MaxTransID
		AND TransID <= lv_MaxTransIDCompleted
    ORDER BY TransID ASC
    LIMIT ip_BatchSize;
    
    ALTER TABLE Temp_Trans07
    ADD KEY IX_Temp_Trans07_Flagged (Flagged),
    ADD KEY IX_Temp_Trans07_TransID_SubscriberID (TransID, SubscriberID);

    UPDATE Temp_Trans07 AS tmp
		INNER JOIN DCS_DataCenter.StaticList AS sl ON sl.ListID = 1 AND sl.ItemID = tmp.Flagged
	SET 	tmp.FlaggedGroupID = sl.GroupID
		,	tmp.IsInvalidBrowers = (CASE WHEN sl.GroupID = CONST_FLAGGEDGROUPID_INVALIDBROWSER THEN 1 ELSE 0 END)
		,	tmp.IsBotTrans = (CASE WHEN sl.GroupID = CONST_FLAGGEDGROUPID_BOTTRANS THEN 1 ELSE 0 END);
        
    SET lv_MaxTransID = (SELECT MAX(TransID) FROM Temp_Trans07);
    
    /* == Insert into LoginTransactionSummary == */
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
		tl.FirstLoginTransTime	= LEAST(tl.FirstLoginTransTime, tmp.FirstLoginTransTime),
		tl.LastLoginTransTime	= GREATEST(tl.LastLoginTransTime, tmp.LastLoginTransTime),
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

    
    /* == Insert into LoginTransactionSummaryByAccount == */
    INSERT INTO Temp_TotalTransByAccount(TransDate, SubscriberID, AccountID, TotalTrans, TotalInvalidBrowers, TotalBotTrans, TotalNoDeviceTrans)
    SELECT 	TransDate
        ,	SubscriberID
        ,	AccountID
        ,	COUNT(1) AS TotalTrans
        ,	SUM(IsInvalidBrowers) AS TotalInvalidBrowers
        ,	SUM(IsBotTrans) AS TotalBotTrans
        ,	SUM(CASE WHEN DeviceID = 0 THEN 1 ELSE 0 END) AS TotalNoDeviceTrans
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
		,	trans.ModifiedTime 			= lv_CurrentDatetime
		,	tmp.IsUpdate = 1;
        
    INSERT INTO DCS_DataTrace.LoginTransactionSummaryByAccount(TransDate, SubscriberID, AccountID, TotalTrans, TotalInvalidBrowers, TotalBotTrans, TotalNoDeviceTrans, CreatedTime, ModifiedTime)
    SELECT 	tmp.TransDate
        ,	tmp.SubscriberID
        ,	tmp.AccountID
        ,	tmp.TotalTrans
        ,	tmp.TotalInvalidBrowers
        ,	tmp.TotalBotTrans
        ,	tmp.TotalNoDeviceTrans
        ,	lv_CurrentDatetime AS CreatedTime
        ,	lv_CurrentDatetime AS ModifiedTime
	FROM Temp_TotalTransByAccount AS tmp
    WHERE tmp.IsUpdate = 0;
    
    /* == Insert into LoginTransactionSummaryByFlagged == */
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
	SET 	trans.TotalTrans 		= trans.TotalTrans + tmp.TotalTrans
		,	trans.ModifiedTime 		= lv_CurrentDatetime
		,	tmp.IsUpdate 			= 1;
        
    INSERT INTO DCS_DataTrace.LoginTransactionSummaryByFlagged(TransDate, Flagged, TotalTrans, CreatedTime, ModifiedTime)
    SELECT 	tmp.TransDate
        ,	tmp.Flagged
        ,	tmp.TotalTrans
        ,	lv_CurrentDatetime AS CreatedTime
        ,	lv_CurrentDatetime AS ModifiedTime
	FROM Temp_TotalTransByFlagged AS tmp
    WHERE tmp.IsUpdate = 0;
    
    /* == Insert into LoginTransactionSummaryByDevice == */
    INSERT INTO Temp_TotalTransByDevice(TransDate, SubscriberID, AccountID, DeviceID, TotalTrans)
    SELECT 	tmp.TransDate
        ,	tmp.SubscriberID
        ,	tmp.AccountID
        ,	tmp.DeviceID
        ,	COUNT(1) AS TotalTrans
	FROM Temp_Trans07 AS tmp
		INNER JOIN Temp_SubscriberID AS tmpSub ON tmpSub.SubscriberID = tmp.SubscriberID
    GROUP BY tmp.TransDate, tmp.SubscriberID, tmp.AccountID, tmp.DeviceID;
    
    ALTER TABLE Temp_TotalTransByDevice
    ADD KEY IX_Temp_TotalTransByDevice_Group(TransDate, SubscriberID, AccountID, DeviceID);
    
    UPDATE DCS_DataTrace.LoginTransactionSummaryByDevice AS trans
		INNER JOIN Temp_TotalTransByDevice AS tmp 	ON 	trans.TransDate 	= tmp.TransDate 
													AND trans.SubscriberID 	= tmp.SubscriberID
													AND trans.AccountID 	= tmp.AccountID
													AND trans.DeviceID 		= tmp.DeviceID
	SET 	trans.TotalTrans 	= trans.TotalTrans + tmp.TotalTrans
		,	trans.ModifiedTime 	= lv_CurrentDatetime
		,	tmp.IsUpdate 		= 1;
        
    INSERT INTO DCS_DataTrace.LoginTransactionSummaryByDevice(TransDate, SubscriberID, AccountID, DeviceID, TotalTrans)
    SELECT 	tmp.TransDate
        ,	tmp.SubscriberID
        ,	tmp.AccountID
        ,	tmp.DeviceID
        ,	tmp.TotalTrans
	FROM Temp_TotalTransByDevice AS tmp
    WHERE tmp.IsUpdate = 0;
    
    
    /* == Update SystemSetting == */
    IF(lv_MaxTransID IS NOT NULL AND lv_MaxTransID > 0) THEN
        UPDATE DCS_DataTrace.SystemSetting
        SET VValue = lv_MaxTransID,
			UpdatedTime = lv_CurrentDatetime
        WHERE ID = CONST_COOKDATA_TRANSACTION07_TRANSID;
    END IF;
END$$
DELIMITER ;
