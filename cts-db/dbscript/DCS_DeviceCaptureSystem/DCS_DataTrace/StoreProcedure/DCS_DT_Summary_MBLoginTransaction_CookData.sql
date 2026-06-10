/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Summary_MBLoginTransaction_CookData`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Summary_MBLoginTransaction_CookData`(
    IN ip_BatchSize INT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20250924@Jonathan.Doan
	Task : Cook data from table MBRawTransaction07
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20250924@Jonathan.Doan: Created [Redmine ID: #239121]
		
	Param's Explanation (filtered by):

	Example:
		SET sql_safe_updates = 0;
        CALL DCS_DataTrace.DCS_DT_Summary_MBLoginTransaction_CookData(3);
	*/
    DECLARE CONST_DC_MAXMBTRANSACTION07IDCOMPLETED				INT			DEFAULT 4;
    DECLARE CONST_DT_TRANSACTION07_TRANSID 						INT 		DEFAULT 30;
    
	DECLARE lv_MaxTransIDCompleted	BIGINT UNSIGNED;
    DECLARE lv_MaxTransID  			BIGINT UNSIGNED;
    DECLARE lv_CurrentDatetime 		DATETIME DEFAULT CURRENT_TIMESTAMP();
    
	SET lv_MaxTransIDCompleted	= (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_DC_MAXMBTRANSACTION07IDCOMPLETED);
    SET lv_MaxTransID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataTrace.SystemSetting WHERE ID = CONST_DT_TRANSACTION07_TRANSID);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans07;
	DROP TEMPORARY TABLE IF EXISTS Temp_LoginTrans;
    
	CREATE TEMPORARY TABLE Temp_Trans07(
			ID							BIGINT UNSIGNED NOT NULL PRIMARY KEY
		, 	TransDate					DATE NOT NULL
		, 	SubscriberID				INT UNSIGNED
		, 	MBAccountID					BIGINT UNSIGNED
		, 	MBOSID						BIGINT UNSIGNED
		, 	MBOSType					SMALLINT UNSIGNED DEFAULT 0
		, 	Flagged						SMALLINT
		, 	FlaggedGroupID				SMALLINT UNSIGNED
		, 	TransTime					DATETIME
	);
    
	CREATE TEMPORARY TABLE Temp_LoginTrans(
			ID							INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY 
		, 	TransDate					DATE NOT NULL
		, 	SubscriberID				INT UNSIGNED
		, 	MBAccountID					BIGINT UNSIGNED
		, 	MBOSType					SMALLINT UNSIGNED DEFAULT 0
		, 	FlaggedGroupID				SMALLINT UNSIGNED
		, 	TotalTrans					INT UNSIGNED DEFAULT 0
		, 	FirstLoginTransTime			DATETIME
		, 	LastLoginTransTime			DATETIME
		, 	IsUpdate					BIT DEFAULT 0
	);
    
    INSERT INTO Temp_Trans07(ID, TransDate, SubscriberID, MBAccountID, MBOSID, Flagged, TransTime)
    SELECT 	ID
		,	CreatedDate AS TransDate
        ,	SubscriberID
        ,	MBAccountID
        ,	MBOSID
        ,	Flagged
        ,	TransTime
	FROM DCS_DataCenter.MBTransaction07
    WHERE ID > lv_MaxTransID
		AND ID <= lv_MaxTransIDCompleted
        AND MBAccountID > 0
    ORDER BY ID ASC
    LIMIT ip_BatchSize;
    
    UPDATE Temp_Trans07 AS tmp
		INNER JOIN DCS_DataCenter.StaticList AS sl ON sl.ListID = 1 AND sl.ItemID = tmp.Flagged
	SET tmp.FlaggedGroupID = sl.GroupID;
    
    UPDATE Temp_Trans07 AS tmp
		INNER JOIN DCS_DataCenter.MBOS AS os ON os.ID = tmp.MBOSID
		INNER JOIN DCS_DataCenter.StaticList AS sl ON sl.ListID = 5 AND sl.ItemName = os.OSName
	SET tmp.MBOSType = sl.ItemID;
    
    SET lv_MaxTransID = (SELECT MAX(ID) FROM Temp_Trans07);
        
    /* == Insert into MBLoginTransactionSummary == */
    INSERT INTO Temp_LoginTrans(TransDate, SubscriberID, MBAccountID, MBOSType, FlaggedGroupID, FirstLoginTransTime, LastLoginTransTime, TotalTrans)
    SELECT 	TransDate
        ,	SubscriberID
		,	MBAccountID
        ,	MBOSType
        ,	FlaggedGroupID
        ,	MIN(TransTime) AS FirstLoginTransTime
        ,	MAX(TransTime) AS LastLoginTransTime
        ,	COUNT(1) AS TotalTrans
	FROM Temp_Trans07
    GROUP BY TransDate, SubscriberID, MBAccountID, MBOSType, FlaggedGroupID;
    
    ALTER TABLE Temp_LoginTrans
    ADD KEY IX_Temp_LoginTrans_Group(TransDate, SubscriberID, MBAccountID, FlaggedGroupID);
	
    UPDATE DCS_DataTrace.MBLoginTransactionSummary AS mbsum
		INNER JOIN Temp_LoginTrans AS tmp ON mbsum.TransDate		= tmp.TransDate
										AND mbsum.SubscriberID		= tmp.SubscriberID
										AND mbsum.MBAccountID		= tmp.MBAccountID
										AND mbsum.FlaggedGroupID	= tmp.FlaggedGroupID
	SET 	mbsum.TotalTrans 			= mbsum.TotalTrans + tmp.TotalTrans
		,	mbsum.FirstLoginTransTime 	= tmp.FirstLoginTransTime
		,	mbsum.LastLoginTransTime 	= tmp.LastLoginTransTime
		,	mbsum.ModifiedTime 			= lv_CurrentDatetime
		,	tmp.IsUpdate 				= 1;
    
    INSERT INTO DCS_DataTrace.MBLoginTransactionSummary(TransDate, SubscriberID, MBAccountID, FlaggedGroupID, FirstLoginTransTime, LastLoginTransTime, TotalTrans, CreatedTime, ModifiedTime)
    SELECT 	tmp.TransDate
        ,	tmp.SubscriberID
		,	tmp.MBAccountID
		,	tmp.FlaggedGroupID
        ,	tmp.FirstLoginTransTime
        ,	tmp.LastLoginTransTime
        ,	tmp.TotalTrans
        ,	lv_CurrentDatetime AS CreatedTime
        ,	lv_CurrentDatetime AS ModifiedTime
	FROM Temp_LoginTrans AS tmp
    WHERE tmp.IsUpdate = 0;

    /* == Update SystemSetting == */
    IF(lv_MaxTransID IS NOT NULL AND lv_MaxTransID > 0) THEN
        UPDATE DCS_DataTrace.SystemSetting
        SET VValue = lv_MaxTransID,
			UpdatedTime = lv_CurrentDatetime
        WHERE ID = CONST_DT_TRANSACTION07_TRANSID;
    END IF;
END$$
DELIMITER ;
