/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Association_GetAssociationDeviceByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Association_GetAssociationDeviceByDeviceSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_DeviceID		BIGINT UNSIGNED
	,	IN ip_NoOfRecord	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230809@Casey.Huynh
		Task :		Get Association Devices List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230809@Casey.Huynh: Created [Redmine ID: 192402]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Association_GetAssociationDeviceByDeviceSubscriber(@ip_SubscriberID:=8000005,@ip_DeviceID:=299,@ip_NoOfRecord:=15) 

	*/
    DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE Temp_Account(
			AccountID BIGINT UNSIGNED PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Device;
	CREATE TEMPORARY TABLE Temp_Device(
			DeviceID	BIGINT UNSIGNED PRIMARY KEY
        ,	CreatedTime	DATETIME(4)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_DistinctAccount;
	CREATE TEMPORARY TABLE Temp_DistinctAccount(
			AccountID BIGINT UNSIGNED PRIMARY KEY
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedDevice;
	CREATE TEMPORARY TABLE Temp_AssociatedDevice(
			AccountID		BIGINT UNSIGNED
		,	DeviceID		BIGINT UNSIGNED
        ,	CreatedTime		DATETIME(4)
        
        ,	PRIMARY KEY PK_Temp_AssociatedDevice(AccountID, DeviceID)
        ,	INDEX IX_Temp_AssociatedDevice_DeviceID(DeviceID)
    ); 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedAccount;
	CREATE TEMPORARY TABLE Temp_AssociatedAccount(
			AccountID		BIGINT UNSIGNED
		,	DeviceID		BIGINT UNSIGNED
        ,	CreatedTime		DATETIME(4)
        
        ,	PRIMARY KEY PK_Temp_AssociatedAccount(AccountID, DeviceID)
        ,	INDEX IX_Temp_AssociatedAccount_DeviceID(DeviceID)
    );
		   
	
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedDeviceInfo;
	CREATE TEMPORARY TABLE Temp_AssociatedDeviceInfo(
			DeviceID			BIGINT UNSIGNED
        ,	AssociatedAccounts	INT
        ,	AssociatedDevices	INT
        ,	CreatedTime			DATETIME(4)
        
        ,	PRIMARY KEY PK_Temp_AssociatedAccount(DeviceID)
    );  
    
    #======GET Cust Association LIST: ip_DeviceID AND ASSOCIATED CUSTOMER=======================================    
    
    INSERT INTO Temp_Account(AccountID)
    SELECT AccountID
    FROM DCS_Extra.Association AS ass 
    WHERE ass.SubscriberID = ip_SubscriberID AND ass.DeviceID = ip_DeviceID
    ORDER BY ass.CreatedDate DESC;
    
    INSERT IGNORE INTO Temp_Device(DeviceID, CreatedTime)
	SELECT	ass.DeviceID
		,	MAX(ass.CreatedTime) AS MaxCreatedTime
    FROM DCS_Extra.Association AS ass 
		INNER JOIN Temp_Account AS acc ON ass.AccountID = acc.AccountID 
	GROUP BY ass.DeviceID
    ORDER BY  MaxCreatedTime DESC
    LIMIT ip_NoOfRecord; 
    
    INSERT INTO Temp_AssociatedDevice(AccountID, DeviceID,  CreatedTime)
    SELECT	ass.AccountID
		,	ass.DeviceID
        ,	tmpDv.CreatedTime
    FROM Temp_Device AS tmpDv
		INNER JOIN DCS_Extra.Association AS ass ON ass.DeviceID = tmpDv.DeviceID AND ass.SubscriberID = ip_SubscriberID;
    
	INSERT INTO Temp_DistinctAccount(AccountID)
    SELECT DISTINCT tmpAd.AccountID
    FROM Temp_AssociatedDevice AS tmpAd;    
    
    INSERT INTO Temp_AssociatedAccount(AccountID, DeviceID, CreatedTime)
    SELECT	tmpAc.AccountID
		,	ass.DeviceID
        ,	ass.CreatedTime
    FROM Temp_DistinctAccount AS tmpAc
		INNER JOIN DCS_Extra.Association AS ass ON ass.AccountID = tmpAc.AccountID;
     
    INSERT INTO Temp_AssociatedDeviceInfo(DeviceID, AssociatedAccounts, AssociatedDevices, CreatedTime)
	SELECT	tmpAd.DeviceID
		,	COUNT(DISTINCT tmpAa.AccountID) AS AssociatedAccounts
        ,	COUNT(DISTINCT tmpAa.DeviceID)-1 AS AssociatedDevices
        ,	MAX(tmpAd.CreatedTime)
    FROM Temp_AssociatedDevice AS tmpAd
		INNER JOIN Temp_AssociatedAccount AS tmpAa ON tmpAd.AccountID = tmpAa.AccountID
	GROUP BY tmpAd.DeviceID;   
	    
    SELECT	dv.DeviceID
		,	dv.FirstDeviceCode AS DeviceCode
        ,	DATE(dv.CreatedTime) AS FirstSeenDate
        ,	tmpAd.AssociatedAccounts
        ,	tmpAd.AssociatedDevices
    FROM Temp_AssociatedDeviceInfo AS tmpAd
		INNER JOIN DCS_Extra.Device AS dv ON dv.DeviceID = tmpAd.DeviceID
	ORDER BY dv.CreatedTime DESC;     
    
END$$
DELIMITER ;