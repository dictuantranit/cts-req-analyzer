/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transaction_GetLatestBySubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transaction_GetLatestBySubscriber`(
		IN	ip_SubscriberID	INT	
    ,	IN	ip_Length		INT
    ,	IN	ip_Skip			INT
    ,	IN	ip_Take			INT
    ,	OUT	op_TotalItem	INT
    )
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230720@Casey.Huynh
		Task :		Get Association Account List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230720@Casey.Huynh: Created [Redmine ID: 189873]
            - 	20230809@Casey.Huynh: Show Device Info [Redmine ID: 192402]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Transaction_GetLatestBySubscriber(@ip_SubscriberID:=8000001,@ip_Length:=2000,@ip_Skip:=2, @ip_Take:=205, @op_TotalItem); SELECT @op_TotalItem;
            SELECT * FROM DCS_Extra.Transaction07 WHERE SubscriberID =8000001;
*/
	DECLARE lv_Partition		VARCHAR(50);
    DECLARE	lv_TotalTrans		INT DEFAULT 0;
    DECLARE lv_LimitTrans		INT DEFAULT 0;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
    CREATE TEMPORARY TABLE Temp_Transaction(	
			TransID			BIGINT UNSIGNED
        ,	LoginName		VARCHAR(50)
        ,	SubscriberID	INT
        ,	AccountID		BIGINT UNSIGNED
		,	TransTime		DATETIME(4)     
		,	FirstDeviceCode	VARCHAR(64)
		,	IP				VARCHAR(50)
		,	Country		VARCHAR(128)
        ,	City		VARCHAR(128)
        ,	Region		VARCHAR(128)
        ,	ISP			VARCHAR(128)
		,	Action			VARCHAR(100)
		,	ActionResult	VARCHAR(100)
		,	OS				VARCHAR(100)		
		,	Browser			VARCHAR(100)
		,	URLDetails		VARCHAR(250)
        ,	RobotTracking	VARCHAR(200)
        
        ,	PRIMARY KEY PK_Temp_Transaction(TransID)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Partition;
    CREATE TEMPORARY TABLE Temp_Partition(
			PartitionOrdinalPosition INT PRIMARY KEY
        ,	PartitionName	VARCHAR(100)
        
        ,	INDEX IX_Temp_Partition_PartitionName(PartitionName)
    );
    
    #================================================================
	DROP TEMPORARY TABLE IF EXISTS Temp_Flagged;
	CREATE TEMPORARY TABLE Temp_Flagged(
			Flagged 	SMALLINT PRIMARY KEY
        ,	DisplayName VARCHAR(200)
	);
    
    INSERT INTO Temp_Flagged(Flagged, DisplayName)
    SELECT	stl.ItemID
		,	stl.ItemName
    FROM DCS_Extra.StaticList AS stl
    WHERE stl.ListID = 1;
    
    INSERT INTO Temp_Partition(PartitionOrdinalPosition, PartitionName)
    SELECT	p.Partition_Ordinal_Position
		,	p.Partition_Name 
    FROM INFORMATION_SCHEMA.`PARTITIONS` AS p
    WHERE p.TABLE_SCHEMA = 'DCS_Extra' 
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
							FROM DCS_Extra.Transaction07 PARTITION(",lv_Partition,") AS ts
							LIMIT 1");
		PREPARE stmt1 FROM  @sql;
		EXECUTE stmt1; 
		DEALLOCATE PREPARE stmt1;
        
        IF @lv_HasData = 1 THEN
        
			SET @sql = 	CONCAT("
			INSERT INTO Temp_Transaction(TransTime, TransID, SubscriberID, AccountID, LoginName, FirstDeviceCode, Action, ActionResult, OS, Browser, URLDetails, IP, Country, Region, City, ISP, RobotTracking)
			SELECT	ts.TransTime			
				,	ts.TransID
				,	ts.SubscriberID
				,	ts.AccountID
				,	ts.LoginName
				,	ts.FirstDeviceCode
				,	ar.Action
				,	ar.ActionResult
				,	ua.OS
				,	ua.Browser
				,	ur.URLDetails
				,	ts.IP
				,	ip.Country
				,	ip.Region
				,	ip.City
				,	ip.ISP
				,	tmpFg.DisplayName AS RobotTracking
			FROM DCS_Extra.Transaction07 PARTITION(",lv_Partition,") AS ts
				LEFT JOIN DCS_Extra.IPInfo AS ip ON ip.IPInfoID = ts.IPInfoID
				LEFT JOIN DCS_Extra.UserAgent AS ua ON ts.UserAgentKey = ua.UserAgentKey
				LEFT JOIN DCS_Extra.ActionResult AS ar ON ts.ActionResultID = ar.ActionResultID
				LEFT JOIN DCS_Extra.URL AS ur ON ts.URLID = ur.URLID
				LEFT JOIN Temp_Flagged AS tmpFg ON ts.Flagged = tmpFg.Flagged
			WHERE ts.SubscriberID = ",ip_SubscriberId,"
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
    
	SET  op_TotalItem = (SELECT COUNT(1) FROM Temp_Transaction);
    
	SELECT 	tmp.TransTime		AS TransTime
		,	tmp.TransID			AS TransID
        ,	tmp.SubscriberID	AS SubscriberID
        ,	tmp.AccountID		AS AccountID
		,	tmp.LoginName		AS LoginName
		,	tmp.FirstDeviceCode	AS FirstDeviceCode
		,	tmp.Action			AS Action
		,	tmp.ActionResult	AS ActionResult
		,	tmp.OS				AS OS
		,	tmp.Browser			AS Browser
		,	tmp.URLDetails		AS URLDetails
		,	tmp.IP				AS IP
		,	tmp.Country
		,	tmp.Region
		,	tmp.City
		,	tmp.ISP
        ,	tmp.RobotTracking	AS RobotTracking
	FROM Temp_Transaction AS tmp
    ORDER BY TransTime DESC
    LIMIT ip_Skip, ip_Take;
    
END$$

DELIMITER ;
