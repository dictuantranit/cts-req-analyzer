/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transaction_GetLatestBySubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transaction_GetLatestBySubscriber`(
		IN	ip_SubscriberID	INT	
    ,	IN	ip_Length		INT
    ,	IN	ip_Skip			INT
    ,	IN	ip_Take			INT
    ,	OUT	op_TotalItem	INT
    )
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230601@Casey.Huynh
		Task :		Get Association Account List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230601@Casey.Huynh: Created [Redmine ID: 185787]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Transaction_GetLatestBySubscriber(@ip_SubscriberID:=6,@ip_Length:=2000,@ip_Skip:=2, @ip_Take:=20, @op_TotalItem); SELECT @op_TotalItem;
            SELECT * FROM DCS_DataCenter.Transaction07 WHERE SubscriberID = 6;
*/
	DECLARE lv_Partition		VARCHAR(50);
    DECLARE	lv_TotalTrans		INT DEFAULT 0;
    DECLARE lv_LimitTrans		INT DEFAULT 0;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
    CREATE TEMPORARY TABLE Temp_Transaction(	
			TransID			BIGINT UNSIGNED
        ,	RegisterName	VARCHAR(50)
        ,	UserName		VARCHAR(50)
        ,	SubscriberID	INT
        ,	CTSCustID		BIGINT UNSIGNED
		,	TransTime		DATETIME(4)     
		,	FirstDeviceCode	VARCHAR(64)
		,	IP				VARCHAR(50)
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
    FROM DCS_DataCenter.StaticList AS stl
    WHERE stl.ListID = 1;
    
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

        SET @sql = 	CONCAT("
		INSERT INTO Temp_Transaction(TransTime, TransID, SubscriberID, CTSCustID, RegisterName, UserName, FirstDeviceCode, Action, ActionResult, OS, Browser, URLDetails, IP, RobotTracking)
        SELECT	ts.TransTime			
			,	ts.TransID
            ,	ts.SubscriberID
            ,	ca.CTSCustID
			,	cus.RegisterName
            ,	cus.UserName
			,	ts.FirstDeviceCode
			,	ar.Action
			,	ar.ActionResult
			,	ua.OS
			,	ua.Browser
			,	ur.URLDetails
            ,	ts.IP
            ,	tmpFg.DisplayName AS RobotTracking
		FROM DCS_DataCenter.Transaction07 PARTITION(",lv_Partition,") AS ts
			INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON ts.AccountID = ca.AccountID AND ca.SubscriberID = ts.SubscriberID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID AND cus.IsInternal = 0
			LEFT JOIN DCS_DataCenter.UserAgent AS ua ON ts.UserAgentKey = ua.UserAgentKey
			LEFT JOIN DCS_DataCenter.ActionResult AS ar ON ts.ActionResultID = ar.ActionResultID
			LEFT JOIN DCS_DataCenter.URL AS ur ON ts.URLID = ur.URLID AND ts.SubscriberID = ur.SubscriberID
            LEFT JOIN Temp_Flagged AS tmpFg ON ts.Flagged = tmpFg.Flagged
		WHERE ts.SubscriberID = ",ip_SubscriberId,"
        ORDER BY ts.TransTime DESC
        LIMIT ",lv_LimitTrans);
        
        PREPARE stmt1 FROM  @sql;
		EXECUTE stmt1; 
		DEALLOCATE PREPARE stmt1;
        
		SET lv_TotalTrans = (SELECT COUNT(1) FROM Temp_Transaction);
        
        SET lv_LimitTrans = ip_Length - lv_TotalTrans;
        
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
        ,	tmp.CTSCustID		AS CTSCustID
		,	tmp.RegisterName	AS RegisterName
        ,	tmp.UserName		AS UserName
		,	tmp.FirstDeviceCode	AS FirstDeviceCode
		,	tmp.Action			AS Action
		,	tmp.ActionResult	AS ActionResult
		,	tmp.OS				AS OS
		,	tmp.Browser			AS Browser
		,	tmp.URLDetails		AS URLDetails
		,	tmp.IP				AS IP
        ,	tmp.RobotTracking	AS RobotTracking
	FROM Temp_Transaction AS tmp
    ORDER BY TransTime DESC
    LIMIT ip_Skip, ip_Take;
    
END$$

DELIMITER ;
