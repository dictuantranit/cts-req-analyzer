/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transaction_GetLatest`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transaction_GetLatest`(
		IN ip_SubscriberId	INT
	, 	IN ip_Length		INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210330@Adam.Tran
		Task:		Get latest transactions 
		DB:			DCS_DataCenter
        
		Revisions:
			- 20210330@Adam.Tran: Created [Redmine ID: #140348]  
			- 20210412@Aries.Nguyen: Fix issue performance when filter all  [Redmine ID: #153009]
            - 20210629@Casey.Huynh: Return Flagged Value (Web will show type of robot) [Redmine ID: 157085]
			- 20211006@Aries.Nguyen: Fix issue performance when filter sub SM88  [Redmine ID: #162888]
			- 20211123@Aries.Nguyen: Fix issue performance when filter sub AlphaIBCIndo  [Redmine ID: #162888]
			- 20230411@Casey.Huynh: Tunning Performance  [Redmine ID: #186129]
            - 20230512@Jonas.Huynh: BOTD transactions [Redmine ID: 185792]
            - 20230524@Jonas.Huynh: Fix issue wrong data type [Redmine ID: 188680]
            - 20230816@Casey.Huynh: Tunning Performance [Redmine ID: 192402]
            - 20230828@Casey.Huynh: Correct DBName and Tunning Performance [Redmine ID: 193267]
            - 20250922@Thomas.Nguyen: Get more MB Account latest transactions [Redmine ID: #239121]
			
		Param's Explanation (filtered by):

        Example:
			- CALL DCS_DataCenter.DCS_DC_Transaction_GetLatest(2, 100);
	*/    
    DECLARE lv_Partition			VARCHAR(50);
    DECLARE	lv_TotalTrans			INT DEFAULT 0;
    DECLARE lv_LimitTrans			INT DEFAULT 0;
	DECLARE lv_Partition_MB			VARCHAR(50);
	DECLARE	lv_TotalTrans_MB		INT DEFAULT 0;
    DECLARE lv_LimitTrans_MB		INT DEFAULT 0;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
    CREATE TEMPORARY TABLE Temp_Transaction(	
			TransID			BIGINT UNSIGNED
        ,	AccountID		BIGINT UNSIGNED
        ,	SubscriberName	VARCHAR(50)
        ,	UserName		VARCHAR(50)
        ,	LoginID			VARCHAR(50)
        ,	CTSCustID		BIGINT UNSIGNED
		,	TransTime		DATETIME(4)     
		,	FirstDeviceCode	VARCHAR(64)
		,	IP				VARCHAR(50)
		,	Flagged			VARCHAR(200)
		,	Action			VARCHAR(100)
		,	ActionResult	VARCHAR(100)
		,	OS				VARCHAR(100)		
		,	Browser			VARCHAR(100)
		,	URLDetails		VARCHAR(250)
        ,	TransSourceID	TINYINT /*1: Desktop, Mobile Web, 2: Mobile App*/
        ,	PRIMARY KEY PK_Temp_Transaction(AccountID, TransID, TransSourceID)
    );

	DROP TEMPORARY TABLE IF EXISTS Temp_CustDCSMBAccount;
    CREATE TEMPORARY TABLE Temp_CustDCSMBAccount(	
			MBAccountID		BIGINT UNSIGNED
        ,	CTSCustID		BIGINT UNSIGNED
        ,	SubscriberName	VARCHAR(50)
        ,	UserName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	UserName2		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	INDEX IX_Temp_CustDCSMBAccount(MBAccountID, CTSCustID)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Partition;
    CREATE TEMPORARY TABLE Temp_Partition(
			PartitionOrdinalPosition INT PRIMARY KEY
        ,	PartitionName	VARCHAR(100)
        
        ,	INDEX IX_Temp_Partition_PartitionName(PartitionName)
    );
    
    INSERT INTO Temp_Partition(PartitionOrdinalPosition, PartitionName)
    SELECT	p.Partition_Ordinal_Position
		,	p.Partition_Name 
    FROM INFORMATION_SCHEMA.`PARTITIONS` AS p
    WHERE p.TABLE_SCHEMA = 'DCS_DataCenter' 
		AND p.`TABLE_NAME` = 'Transaction07';    
	
    SELECT	tmp.PartitionName
    INTO lv_Partition
    FROM Temp_Partition AS tmp
    ORDER BY PartitionOrdinalPosition DESC
    LIMIT 1;
	
    SET lv_LimitTrans = ip_Length;
	WHILE (lv_LimitTrans > 0 AND lv_Partition IS NOT NULL) DO
		
        SET @lv_HasData= 0;
 
        SET @sql = CONCAT("SELECT 1
							INTO @lv_HasData
							FROM DCS_DataCenter.Transaction07 PARTITION(",lv_Partition,") AS ts
							LIMIT 1");
		PREPARE stmt1 FROM  @sql;
		EXECUTE stmt1; 
		DEALLOCATE PREPARE stmt1;
        
        IF @lv_HasData = 1 THEN
        
			SET @sql = 	CONCAT("
			INSERT INTO Temp_Transaction(TransID, AccountID, SubscriberName, UserName, LoginID, CTSCustID, TransTime, FirstDeviceCode, IP, Flagged, Action, ActionResult, OS, Browser, URLDetails, TransSourceID)
			SELECT	ts.TransID
				,	ts.AccountID
				,	sb.SubscriberName
				,	cus.UserName
				,	cus.UserName2 AS LoginID
				,	cus.CTSCustID
				,	ts.TransTime
				,	ts.FirstDeviceCode
				,	ts.IP
				,	s.ItemName AS Flagged
				,	ar.Action
				,	ar.ActionResult
				,	ua.OS
				,	ua.Browser
				,	ur.URLDetails 
				,	1 AS TransSourceID
			FROM DCS_DataCenter.Transaction07 PARTITION(",lv_Partition,") AS ts
				INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON ts.AccountID = ca.AccountID
				INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID 
				LEFT JOIN DCS_DataCenter.UserAgent AS ua ON ts.UserAgentKey = ua.UserAgentKey
				LEFT JOIN DCS_DataCenter.ActionResult AS ar ON ts.ActionResultID = ar.ActionResultID
				LEFT JOIN DCS_DataCenter.URL AS ur ON ts.URLID = ur.URLID
				LEFT JOIN CTS_Admin.Subscriber AS sb ON cus.SubscriberID = sb.SubscriberID		
				LEFT JOIN DCS_DataCenter.StaticList AS s ON s.ListID = 1 AND s.ItemID = ts.Flagged AND s.Status = 1
			WHERE ts.SubscriberID = ",ip_SubscriberId," OR ",ip_SubscriberId," = -1
			ORDER BY ts.TransTime DESC
			LIMIT ",lv_LimitTrans);
			
			PREPARE stmt1 FROM  @sql;
			EXECUTE stmt1; 
			DEALLOCATE PREPARE stmt1;
			
			SET lv_TotalTrans = (SELECT COUNT(1) FROM Temp_Transaction);
			
			SET lv_LimitTrans = ip_Length - lv_TotalTrans;
            
        END IF;
        
        DELETE tmp
        FROM Temp_Partition AS tmp
        WHERE tmp.PartitionName = lv_Partition;
        
        SET lv_Partition = (SELECT	tmp.PartitionName
							FROM Temp_Partition AS tmp
							ORDER BY PartitionOrdinalPosition DESC
							LIMIT 1);    
		
    END WHILE;


	/*** MB Account ***/
	TRUNCATE TABLE Temp_Partition;
	INSERT INTO Temp_Partition(PartitionOrdinalPosition, PartitionName)
    SELECT	p.Partition_Ordinal_Position
		,	p.Partition_Name 
    FROM INFORMATION_SCHEMA.`PARTITIONS` AS p
    WHERE p.TABLE_SCHEMA = 'DCS_DataCenter' 
		AND p.`TABLE_NAME` = 'MBTransaction07';    
	
    SELECT	tmp.PartitionName
    INTO lv_Partition_MB
    FROM Temp_Partition AS tmp
    ORDER BY PartitionOrdinalPosition DESC
    LIMIT 1;
	
    SET lv_LimitTrans_MB = ip_Length;
	WHILE (lv_LimitTrans_MB > 0 AND lv_Partition_MB IS NOT NULL) DO
		
        SET @lv_HasData= 0;
 
        SET @sql = CONCAT("SELECT 1
							INTO @lv_HasData
							FROM DCS_DataCenter.MBTransaction07 PARTITION(",lv_Partition_MB,") AS ts
							LIMIT 1");
		PREPARE stmt1 FROM  @sql;
		EXECUTE stmt1; 
		DEALLOCATE PREPARE stmt1;
        
        IF @lv_HasData = 1 THEN
        
			SET @sql = 	CONCAT("
			INSERT INTO Temp_Transaction(TransID, AccountID, TransTime, FirstDeviceCode, IP, Flagged, Action, ActionResult, OS, Browser, URLDetails, TransSourceID)
			SELECT	ts.MBRawTransactionID AS TransID
				,	ts.MBAccountID AS AccountID
				,	ts.TransTime
				,	ts.MBDeviceID
				,	ts.IP
				,	s.ItemName AS Flagged
				,	ar.Action
				,	ar.ActionResult
				,	os.OSName
				,	NULL AS Browser
				,	NULL AS URLDetails 
				,	2 AS TransSourceID
			FROM DCS_DataCenter.MBTransaction07 PARTITION(",lv_Partition_MB,") AS ts
				LEFT JOIN DCS_DataCenter.MBOS AS os ON ts.MBOSID = os.ID
				LEFT JOIN DCS_DataCenter.ActionResult AS ar ON ts.ActionResultID = ar.ActionResultID
				LEFT JOIN DCS_DataCenter.StaticList AS s ON s.ListID = 1 AND s.ItemID = ts.Flagged AND s.Status = 1
			WHERE ts.SubscriberID = ",ip_SubscriberId," OR ",ip_SubscriberId," = -1
			ORDER BY ts.TransTime DESC
			LIMIT ",lv_LimitTrans_MB);
			
			PREPARE stmt1 FROM  @sql;
			EXECUTE stmt1; 
			DEALLOCATE PREPARE stmt1;
			
			SET lv_TotalTrans_MB = (SELECT COUNT(1) FROM Temp_Transaction);
			
			SET lv_LimitTrans_MB = ip_Length - lv_TotalTrans_MB;
            
        END IF;
        
        DELETE tmp
        FROM Temp_Partition AS tmp
        WHERE tmp.PartitionName = lv_Partition_MB;
        
        SET lv_Partition_MB = (SELECT	tmp.PartitionName
							FROM Temp_Partition AS tmp
							ORDER BY PartitionOrdinalPosition DESC
							LIMIT 1);    
		
    END WHILE;
    
	INSERT INTO Temp_CustDCSMBAccount(MBAccountID, CTSCustID, SubscriberName, UserName, UserName2)
	SELECT	tmp.AccountID AS MBAccountID
		,	cus.CTSCustID
		,	sb.SubscriberName
		,	cus.UserName
		,	cus.UserName2
	FROM Temp_Transaction AS tmp
		INNER JOIN DCS_DataCenter.MBAccount AS mb ON mb.ID = tmp.AccountID
		INNER JOIN CTS_Admin.Subscriber AS sb ON sb.SubscriberID = mb.SubscriberID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.UserName2 = CONCAT(sb.SubscriberPrefix, mb.LoginName) AND cus.SubscriberID = mb.SubscriberID
	WHERE tmp.CTSCustID IS NULL AND tmp.TransSourceID = 2;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustDCSMBAccount_Dup;
	CREATE TEMPORARY TABLE Temp_CustDCSMBAccount_Dup LIKE Temp_CustDCSMBAccount;

	INSERT INTO Temp_CustDCSMBAccount_Dup(MBAccountID, CTSCustID, SubscriberName, UserName, UserName2)
	SELECT	MBAccountID, CTSCustID, SubscriberName, UserName, UserName2
	FROM Temp_CustDCSMBAccount;

	INSERT INTO Temp_CustDCSMBAccount(MBAccountID, CTSCustID, SubscriberName, UserName, UserName2)
	SELECT	tmp.AccountID AS MBAccountID
		,	cus.CTSCustID
		,	sb.SubscriberName
		,	cus.UserName
		,	cus.UserName2
	FROM Temp_Transaction AS tmp
		INNER JOIN DCS_DataCenter.MBAccount AS mb ON mb.ID = tmp.AccountID
		INNER JOIN CTS_Admin.Subscriber AS sb ON sb.SubscriberID = mb.SubscriberID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.UserName = mb.LoginName AND cus.SubscriberID = mb.SubscriberID
	WHERE tmp.CTSCustID IS NULL AND tmp.TransSourceID = 2 AND NOT EXISTS (SELECT 1 FROM Temp_CustDCSMBAccount_Dup AS tmp2 WHERE tmp2.MBAccountID = tmp.AccountID);

	UPDATE Temp_Transaction AS tmp
		INNER JOIN Temp_CustDCSMBAccount AS mb ON mb.MBAccountID = tmp.AccountID
	SET		tmp.CTSCustID = mb.CTSCustID
		,	tmp.SubscriberName = mb.SubscriberName
		,	tmp.UserName = mb.UserName
		,	tmp.LoginID = mb.UserName2
	WHERE tmp.CTSCustID IS NULL AND tmp.TransSourceID = 2;
	/*** END MB Account ***/

    SELECT	tmpTs.UserName
		,	tmpTs.LoginID
		,	tmpTs.SubscriberName
		,	tmpTs.CTSCustID
		,	tmpTs.TransTime            
		,	tmpTs.FirstDeviceCode	
		,	tmpTs.IP
		,	tmpTs.Flagged
		,	tmpTs.Action
		,	tmpTs.ActionResult
		,	tmpTs.OS
		,	tmpTs.Browser
		,	tmpTs.URLDetails
		,	tmpTs.AccountID
		,	tmpTs.TransID
	FROM Temp_Transaction AS tmpTs
    ORDER BY tmpTs.TransTime DESC
	LIMIT ip_Length;           

END$$

DELIMITER ;
