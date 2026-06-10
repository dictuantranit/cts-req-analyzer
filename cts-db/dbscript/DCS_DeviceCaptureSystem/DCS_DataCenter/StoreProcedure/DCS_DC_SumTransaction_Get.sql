/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_SumTransaction_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_SumTransaction_Get`(
		OUT	 op_MaxTransID 		BIGINT UNSIGNED
	,	OUT	 op_DateScan		DATE
    ,	OUT	 op_AccountID 		BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
sp: BEGIN
    /*
	    Created: 20210930@Casey.Huynh
	    Task : GET Sum Trans
	    DB: DCS_DataCenter (Slave)
	    Original:

	    Revisions:		    
        	-	20210930@Casey.Huynh: Created [Redmine ID: 161528]
            -	202110150@Casey.Huynh: Update Get TransID from LastTransID + 1 [Redmine ID: 161528]
            -   20211214@Aries.Nguyen: Enrich the information on customer profile [Redmine ID: #165105]
			-   20220325@Aries.Nguyen: Refactor the Sum data job of transaction statistic [Redmine ID: #170525]
			-   20220415@Aries.Nguyen: Fix bug return op_DateScan incorrect [Redmine ID: #170525]
            -   20250930@Jonathan.Doan: Update DeviceStatus 4,5 [Redmine ID: #236716]

	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DC_SumTransaction_Get(5000);

    */
	DECLARE lv_BatchSize 		BIGINT UNSIGNED;
    DECLARE lv_LastTransID 		BIGINT UNSIGNED;
    DECLARE lv_LastDateScan 	DATETIME;
	DECLARE lv_LastAccountID 	BIGINT UNSIGNED;
    
    DECLARE lv_CurrDateTrans	DATE;
    DECLARE lv_MaxAccountID		BIGINT UNSIGNED;
	DECLARE lv_MaxTransID		BIGINT UNSIGNED;
    
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans;
    CREATE TEMPORARY TABLE Temp_Trans(
			TransDate		DATETIME
        ,	SubscriberID 	INT
        ,	DeviceID		BIGINT UNSIGNED
        ,	DeviceStatus	TINYINT
        ,	Flagged			INT
        ,	TransID			BIGINT UNSIGNED
        ,	AccountID		BIGINT UNSIGNED
        ,	UserAgentKey	VARCHAR(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci
        ,   IP				VARCHAR(50) CHARACTER SET utf8 COLLATE utf8_unicode_ci 
        ,	PRIMARY KEY PK_Temp_ValidTrans(TransDate,SubscriberID,TransID)
        ,	INDEX AccountID(AccountID)
        
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ValidTrans;
    CREATE TEMPORARY TABLE Temp_ValidTrans(
			TransDate		DATETIME
        ,	SubscriberID 	INT
        ,	DeviceID		BIGINT UNSIGNED
        ,	DeviceStatus	TINYINT
        ,	Flagged			INT
        ,	TransID			BIGINT UNSIGNED
        ,	AccountID		BIGINT
        ,	UserAgentKey	VARCHAR(32) CHARACTER SET utf8 COLLATE utf8_unicode_ci
        ,   IP				VARCHAR(50) CHARACTER SET utf8 COLLATE utf8_unicode_ci 
        
        ,	PRIMARY KEY PK_Temp_ValidTrans(TransDate,SubscriberID,TransID)
        ,	INDEX AccountID(AccountID)
        
    );
    
    SELECT VValue
    INTO lv_LastTransID
    FROM DCS_DataCenter.SystemSetting WHERE ID = 11;
    
    SELECT VValue
    INTO lv_BatchSize
    FROM DCS_DataCenter.SystemSetting WHERE ID = 12;
    
    SELECT MAX(tmp.TransID) 
    INTO lv_MaxTransID
    FROM (SELECT TransID FROM DCS_DataCenter.Transaction07 WHERE TransID > lv_LastTransID ORDER BY TransID ASC LIMIT lv_BatchSize) AS tmp;
    
    SET  op_MaxTransID = IFNULL(lv_MaxTransID,lv_LastTransID);
    
    IF lv_MaxTransID IS NOT NULL OR  lv_MaxTransID > lv_LastTransID THEN
		INSERT INTO Temp_Trans(TransID, TransDate,SubscriberID, DeviceID, DeviceStatus, Flagged, AccountID, UserAgentKey, IP)
		SELECT 	TransID
			, 	CreatedDate
			, 	SubscriberID
			, 	DeviceID
			, 	DeviceStatus
			, 	Flagged
			, 	AccountID
			, 	UserAgentKey
			, 	IP
		FROM DCS_DataCenter.Transaction07 AS ts
		WHERE TransID BETWEEN lv_LastTransID + 1 AND lv_MaxTransID;
		   
		INSERT INTO Temp_ValidTrans(TransID, TransDate,SubscriberID, DeviceID, DeviceStatus, Flagged, AccountID, UserAgentKey, IP)
		SELECT 	ts.TransID
			, 	ts.TransDate
			,	ts.SubscriberID
			, 	ts.DeviceID
			, 	ts.DeviceStatus
			, 	ts.Flagged
			, 	ts.AccountID
			, 	ts.UserAgentKey
			, 	ts.IP
		FROM Temp_Trans AS ts
			INNER JOIN CTS_DataCenter.CustDCSAccount AS dc ON ts.AccountID = dc.AccountID;        
    END IF;
    
	/******************************Sum Login Login, IP, Device******************************/
    
    SELECT VValue 
	INTO lv_LastDateScan
	FROM DCS_DataCenter.SystemSetting
	WHERE ID = 21;

	SELECT VValue 
	INTO lv_LastAccountID
	FROM DCS_DataCenter.SystemSetting
	WHERE ID = 22;
    
    SELECT CreatedDate
    INTO lv_CurrDateTrans
    FROM DCS_DataCenter.Transaction07
    ORDER BY TransID DESC
    LIMIT 1;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_SumTransactionByDate;
	CREATE TEMPORARY TABLE Temp_SumTransactionByDate(
			TransID			BIGINT UNSIGNED PRIMARY KEY
		,	TransDate		DATE
		,	AccountID		BIGINT UNSIGNED
		,	IP				VARCHAR(50) CHARACTER SET utf8 COLLATE utf8_unicode_ci
		,	DeviceID		BIGINT UNSIGNED
		,	UserAgentKey	VARCHAR(32)
		,	INDEX 			IX_Temp_SumTransactionByDate_AccountID(AccountID)
	) ENGINE=InnoDB;

	DROP TEMPORARY TABLE IF EXISTS Temp_AccountInvalid;
	CREATE TEMPORARY TABLE Temp_AccountInvalid(
		AccountID		BIGINT UNSIGNED PRIMARY KEY
	) ENGINE=InnoDB;
    
	SET  op_DateScan = lv_LastDateScan;
	SET  op_AccountID = lv_LastAccountID;

    IF  lv_LastDateScan < lv_CurrDateTrans THEN
		SET @sql = 	CONCAT("
			INSERT IGNORE INTO Temp_SumTransactionByDate(TransID, TransDate, AccountID, IP, DeviceID, UserAgentKey)
			SELECT  trans.TransID 
				,	DATE(trans.TransTime) AS TransDate
				,	trans.AccountID 
				,	trans.IP
				,	trans.DeviceID
				,	trans.UserAgentKey
			FROM DCS_DataCenter.Transaction07 AS  trans USE INDEX (IX_Transaction07_CreatedDate_AccountID)
			WHERE trans.CreatedDate = '",lv_LastDateScan,"' ","
				AND trans.AccountID > ",lv_LastAccountID," ","
			ORDER BY trans.CreatedDate ASC
				,	 trans.AccountID ASC
			LIMIT ",lv_BatchSize,";");
        
        PREPARE stmt1 FROM  @sql;
		EXECUTE stmt1; 
		DEALLOCATE PREPARE stmt1;

		SELECT MAX(AccountID)
		INTO lv_MaxAccountID
		FROM Temp_SumTransactionByDate;

		INSERT IGNORE INTO Temp_SumTransactionByDate(TransID, TransDate, AccountID, IP, DeviceID, UserAgentKey)
		SELECT  trans.TransID
			,	DATE(trans.TransTime) AS TransDate
			,	trans.AccountID 
			,	trans.IP
			,	trans.DeviceID
			,	trans.UserAgentKey
		FROM DCS_DataCenter.Transaction07 AS trans USE INDEX (IX_Transaction07_CreatedDate_AccountID)
		WHERE trans.CreatedDate = lv_LastDateScan
			AND trans.AccountID = lv_MaxAccountID;

		SET  op_DateScan = DATE_ADD(lv_LastDateScan, INTERVAL 1 DAY);
		SET  op_AccountID = 0;
    END IF;

	IF EXISTS (SELECT 1 FROM Temp_SumTransactionByDate) THEN
		SELECT 	MAX(TransDate)
			,	MAX(AccountID)
        INTO 	op_DateScan
			,	op_AccountID
        FROM Temp_SumTransactionByDate;
	END IF;

    INSERT IGNORE INTO Temp_AccountInvalid(AccountID)
	SELECT tmp.AccountID
	FROM Temp_SumTransactionByDate AS tmp
		LEFT JOIN CTS_DataCenter.CustDCSAccount AS dc ON tmp.AccountID = dc.AccountID
	WHERE dc.AccountID IS NULL;  

	DELETE tran
	FROM Temp_SumTransactionByDate AS tran
	WHERE EXISTS (SELECT 1 FROM Temp_AccountInvalid AS tmp WHERE tmp.AccountID = tran.AccountID);
	
	SELECT TransDate
		,	SubscriberID
		,	COUNT(1) AS ValidTotal
		,	SUM(CASE WHEN DeviceStatus IS NULL THEN 1 ELSE 0 END) AS ValidNoDevice
		,	SUM(CASE WHEN DeviceStatus = 1 THEN 1 ELSE 0 END) AS ValidDeviceStatusNew
		,	SUM(CASE WHEN DeviceStatus = 2 THEN 1 ELSE 0 END) AS ValidDeviceStatusOld
		,	SUM(CASE WHEN DeviceStatus IN (3, 4, 5) THEN 1 ELSE 0 END) AS ValidDeviceStatusRecover  
		,	SUM(CASE WHEN Flagged > 1 THEN 1 ELSE 0 END) AS ValidBrowserless
	FROM Temp_ValidTrans
	GROUP BY TransDate
			,	 SubscriberID;    
    
    SELECT 	trans.AccountID
		,	trans.TransDate
		,	SUM(CASE WHEN dv.GroupName = 'Mobile' THEN 1 ELSE 0 END) AS DeviceMobile
		,	SUM(CASE WHEN dv.GroupName = 'Desktop' THEN 1 ELSE 0 END) AS DeviceDesktop
		,	SUM(CASE WHEN dv.GroupName IS NULL OR  dv.GroupName = 'Others' THEN 1 ELSE 0 END) AS DeviceOthers
		,	COUNT(1) AS TotalLogin
		,	MAX(TransID) AS MaxTransID
	FROM Temp_SumTransactionByDate AS trans
		LEFT JOIN DCS_DataCenter.UserAgent  AS ua ON ua.UserAgentKey  = trans.UserAgentKey
		LEFT JOIN DCS_DataCenter.DeviceType AS dv ON dv.DeviceTypeID = ua.DeviceTypeID
	GROUP BY trans.AccountID
		,	 trans.TransDate;
		
	SELECT trans.AccountID
		,	MAX(trans.TransDate) AS TransDate
		,	trans.IP
		,	MAX(TransID) AS MaxTransID
	FROM Temp_SumTransactionByDate AS trans
	GROUP BY trans.AccountID
		,	 trans.IP;
		
	SELECT 	trans.AccountID
		,	MAX(trans.TransDate) AS TransDate
		,	trans.DeviceID
		,	MAX(TransID) AS MaxTransID
	FROM Temp_SumTransactionByDate AS trans
	GROUP BY trans.AccountID
		,	 trans.DeviceID;
END$$
DELIMITER ;
