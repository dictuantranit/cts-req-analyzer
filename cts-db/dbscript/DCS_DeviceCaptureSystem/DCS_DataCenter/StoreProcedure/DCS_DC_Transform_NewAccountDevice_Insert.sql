/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_NewAccountDevice_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_NewAccountDevice_Insert`(
		IN ip_NewAccountDeviceJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20231128@Jonathan.Doan
		Task : Insert into DCS_DataCenter.NewAccountDevice
		DB: DCS_DataCenter
		Original:

		Revisions:
			- 20231128@Jonathan.Doan: Created [Redmine ID: #196570]

		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Transform_NewAccountDevice_Insert('[{"AccountID":300016,"DeviceID":2,"RawTransID":1,"SubscriberID":168,"LoginName":"Test1","CreatedDate":"2023-11-29","TransTime":"2023-11-29 11:33:00.1234","UserAgentKey":"UserAgentKey12","IP":"127.0.0.2"}]');

	*/
    DECLARE CONST_MAXASSOCIATIONID_SYSTEMSETTINGID INT DEFAULT 118432914;
    
    DECLARE lv_CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    DECLARE lv_MaxAssociationID BIGINT UNSIGNED;
	
    SET lv_MaxAssociationID = IFNULL((SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_MAXASSOCIATIONID_SYSTEMSETTINGID), 0);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_NewAccountDeviceInsert;
        
	CREATE TEMPORARY TABLE Temp_NewAccountDeviceInsert(
			ID								INT UNSIGNED		NOT NULL AUTO_INCREMENT PRIMARY KEY
        ,	AccountID						BIGINT UNSIGNED
        ,	DeviceID						BIGINT UNSIGNED
        ,	RawTransID						BIGINT UNSIGNED
        ,	CreatedDate						DATETIME
        ,	LoginName						VARCHAR(100)
        ,	TransTime						DATETIME(4)
        ,	UserAgentKey					VARCHAR(32)
        ,	IP								VARCHAR(50)
        ,	AssociationID					BIGINT UNSIGNED
		,	IsNewRecord						TINYINT		 		DEFAULT 1
    );
    
    INSERT INTO Temp_NewAccountDeviceInsert(AccountID, DeviceID, RawTransID, CreatedDate, LoginName, TransTime, UserAgentKey, IP)
	SELECT 	tmp.AccountID
		,	tmp.DeviceID
		,	MIN(tmp.RawTransID) AS RawTransID
		,	MIN(tmp.CreatedDate) AS CreatedDate
		,	MIN(tmp.LoginName) AS LoginName
		,	MIN(tmp.TransTime) AS TransTime
		,	MIN(tmp.UserAgentKey) AS UserAgentKey
		,	MIN(tmp.IP) AS IP
    FROM JSON_TABLE(
			ip_NewAccountDeviceJson,
			 "$[*]" COLUMNS(
							AccountID		BIGINT UNSIGNED	PATH "$.AccountID"
						,	DeviceID		BIGINT UNSIGNED PATH "$.DeviceID"
						,	SubscriberID	INT 			PATH "$.SubscriberID"
						,	RawTransID		BIGINT UNSIGNED	PATH "$.RawTransID"
						,	CreatedDate		DATETIME		PATH "$.CreatedDate"
						,	LoginName		VARCHAR(100)	PATH "$.LoginName"
						,	TransTime		DATETIME(4)		PATH "$.TransTime"
						,	UserAgentKey	VARCHAR(32)		PATH "$.UserAgentKey"
						,	IP				VARCHAR(50)		PATH "$.IP"
					)
		) AS tmp
	WHERE tmp.AccountID IS NOT NULL
		AND tmp.DeviceID IS NOT NULL
		AND tmp.SubscriberID IN (2,168,271,2339,13659) /*Sub Alpha*/
	GROUP BY tmp.AccountID, tmp.DeviceID;
    
    UPDATE Temp_NewAccountDeviceInsert AS tmp
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.AssociationID > lv_MaxAssociationID
													AND ass.AccountID = tmp.AccountID 
													AND ass.DeviceID = tmp.DeviceID
	SET tmp.AssociationID = ass.AssociationID;
    
    UPDATE Temp_NewAccountDeviceInsert AS tmp
		INNER JOIN DCS_DataCenter.NewAccountDevice AS nad ON nad.AssociationID = tmp.AssociationID
    SET tmp.IsNewRecord = 0
    WHERE IsNewRecord = 1;
    
    INSERT IGNORE INTO DCS_DataCenter.NewAccountDevice(AssociationID, AccountID, DeviceID, RawTransID, RawCreatedDate, LoginName, TransTime, UserAgentKey, IP, Status, CreatedDate)
	SELECT 	AssociationID
		, 	AccountID
		, 	DeviceID
		, 	RawTransID
		, 	CreatedDate AS RawCreatedDate
		, 	LoginName
		, 	TransTime
		, 	UserAgentKey
		, 	IP
		,	0 AS Status
		,	lv_CreatedDate AS CreatedDate
	FROM Temp_NewAccountDeviceInsert
    WHERE IsNewRecord = 1
		AND AssociationID IS NOT NULL;
    
END$$

DELIMITER ;
