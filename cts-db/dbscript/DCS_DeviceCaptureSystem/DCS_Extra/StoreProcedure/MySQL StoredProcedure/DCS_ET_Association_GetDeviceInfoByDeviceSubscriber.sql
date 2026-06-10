/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Association_GetDeviceInfoByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Association_GetDeviceInfoByDeviceSubscriber`(
		IN ip_SubscriberID		INT
	,	IN ip_DeviceID			BIGINT UNSIGNED       
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230809@Casey.Huynh
		Task :		Return Association Info Of Device
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230809@Casey.Huynh: Created [Redmine ID: 192402]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Association_GetDeviceInfoByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_DeviceID:=1);
	*/
    #========SEARCH BY DeviceCode=====================
    DECLARE lv_AssociatedDevices	INT;
    DECLARE lv_AssociatedAccounts	INT;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_FirstSeenDate;
    CREATE TEMPORARY TABLE Temp_FirstSeenDate(
			SubscriberID	INT PRIMARY KEY
        ,	CreatedDate		DATETIME
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociationAccount;
    CREATE TEMPORARY TABLE Temp_AssociationAccount(
			AccountID	BIGINT UNSIGNED
        ,	DeviceID	BIGINT UNSIGNED
        
        ,	PRIMARY KEY PK_Temp_AssociationAccount_AccountIDDeviceID(AccountID, DeviceID)
    );
    
    INSERT INTO Temp_AssociationAccount(AccountID, DeviceID)
    SELECT 	ass.AccountID
		,	ass.DeviceID
    FROM DCS_Extra.Association AS ass
    WHERE ass.DeviceID = ip_DeviceID
		AND ass.SubscriberID = ip_SubscriberID;
        
	SELECT COUNT(DISTINCT AccountID) 
    INTO lv_AssociatedAccounts
    FROM Temp_AssociationAccount;    
	
	SELECT COUNT(DISTINCT ass.DeviceID) 
    INTO lv_AssociatedDevices
    FROM Temp_AssociationAccount AS tmpAa
		INNER JOIN DCS_Extra.Association AS ass ON ass.AccountID = tmpAa.AccountID AND ass.SubscriberID = ip_SubscriberID
	WHERE ass.DeviceID <> ip_DeviceID;
    
    SELECT	lv_AssociatedDevices AS AssociatedDevices
		,	lv_AssociatedAccounts AS AssociatedAccounts;
     
	INSERT INTO Temp_FirstSeenDate(SubscriberID, CreatedDate)
	SELECT	ass.SubscriberID
		,	MIN(ass.CreatedTime) AS CreatedDate
    FROM DCS_Extra.Association AS ass
    WHERE ass.DeviceID = ip_DeviceID
	GROUP BY ass.SubscriberID;
	
    SELECT	tmpFs.SubscriberID
		,	sub.SubscriberName
        ,	tmpFs.CreatedDate
    FROM Temp_FirstSeenDate AS tmpFs
		INNER JOIN DCS_Extra.Subscriber AS sub ON tmpFs.SubscriberID = sub.SubscriberID;
END$$
DELIMITER ;
