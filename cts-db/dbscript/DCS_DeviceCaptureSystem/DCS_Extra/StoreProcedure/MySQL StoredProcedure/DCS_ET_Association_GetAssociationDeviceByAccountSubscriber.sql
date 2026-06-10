/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Association_GetAssociationDeviceByAccountSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Association_GetAssociationDeviceByAccountSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_AccountID		BIGINT UNSIGNED
	,	IN ip_NoOfRecord	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230720@Casey.Huynh
		Task :		Get Association Devices List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230720@Casey.Huynh: Created [Redmine ID: 189873]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Association_GetAssociationDeviceByAccountSubscriber(@ip_SubscriberID:=8000001,@ip_AccountID:=19,@ip_NoOfRecord:=15); 
   
	*/
    
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
		   
	DROP TEMPORARY TABLE IF EXISTS Temp_Device;
	CREATE TEMPORARY TABLE Temp_Device(
			DeviceID	BIGINT UNSIGNED PRIMARY KEY
        ,	CreatedTime	DATETIME(4)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE Temp_Account(
			AccountID BIGINT UNSIGNED PRIMARY KEY
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedDeviceInfo;
	CREATE TEMPORARY TABLE Temp_AssociatedDeviceInfo(
			DeviceID			BIGINT UNSIGNED
        ,	AssociatedAccounts	INT
        ,	AssociatedDevices	INT
        ,	CreatedTime			DATETIME(4)
        
        ,	PRIMARY KEY PK_Temp_AssociatedAccount(DeviceID)
    );  
    
    #======GET Cust Association LIST: ip_AccountID AND ASSOCIATED CUSTOMER=======================================          

    INSERT INTO Temp_Device(DeviceID, CreatedTime)
	SELECT	ass.DeviceID
		,	ass.CreatedTime
    FROM DCS_Extra.Association AS ass 
    WHERE ass.SubscriberID = ip_SubscriberID AND ass.AccountID = ip_AccountID
    ORDER BY  ass.CreatedDate DESC, ass.CreatedTime DESC
    LIMIT ip_NoOfRecord;        
  	
    INSERT INTO Temp_AssociatedDevice(AccountID, DeviceID,  CreatedTime)
    SELECT	ass.AccountID
		,	ass.DeviceID
        ,	tmpDv.CreatedTime
    FROM Temp_Device AS tmpDv
		INNER JOIN DCS_Extra.Association AS ass ON ass.DeviceID = tmpDv.DeviceID AND ass.SubscriberID = ip_SubscriberID;
    
	INSERT INTO Temp_Account(AccountID)
    SELECT DISTINCT tmpAd.AccountID
    FROM Temp_AssociatedDevice AS tmpAd;    
    
    INSERT INTO Temp_AssociatedAccount(AccountID, DeviceID, CreatedTime)
    SELECT	tmpAc.AccountID
		,	ass.DeviceID
        ,	ass.CreatedTime
    FROM Temp_Account AS tmpAc
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