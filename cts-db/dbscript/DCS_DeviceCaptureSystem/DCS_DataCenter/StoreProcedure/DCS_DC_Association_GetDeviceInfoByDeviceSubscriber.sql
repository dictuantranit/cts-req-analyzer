/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Association_GetDeviceInfoByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Association_GetDeviceInfoByDeviceSubscriber`(
		IN ip_SubscriberID		INT
	,	IN ip_DeviceID			BIGINT UNSIGNED       
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20250602@Aida.Tran
		Task :		Return Association Info Of Device
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 	20250602@Aida.Tran: Created [Redmine ID: 227652]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Association_GetDeviceInfoByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_DeviceID:=1);
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

	INSERT IGNORE INTO Temp_AssociationAccount(AccountID, DeviceID)
	SELECT 	ass.AccountID
		,	ass.DeviceID
	FROM DCS_DataCenter.Association AS ass
		INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON ass.AccountID = ca.AccountID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID 
													AND cus.IsInternal = 0 
													AND cus.CurrencyID NOT IN (20, 27, 28, 72)
	WHERE ass.DeviceID = ip_DeviceID
		AND ass.SubscriberID = ip_SubscriberID;

	SELECT COUNT(DISTINCT AccountID) 
	INTO lv_AssociatedAccounts
	FROM Temp_AssociationAccount;    
	
	SELECT COUNT(DISTINCT ass.DeviceID) 
	INTO lv_AssociatedDevices
	FROM Temp_AssociationAccount AS tmpAa
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.AccountID = tmpAa.AccountID AND ass.SubscriberID = ip_SubscriberID
	WHERE ass.DeviceID <> ip_DeviceID;

	SELECT	lv_AssociatedDevices AS AssociatedDevices
		,	lv_AssociatedAccounts AS AssociatedAccounts;

	INSERT INTO Temp_FirstSeenDate(SubscriberID, CreatedDate)
	SELECT	ass.SubscriberID
		,	MIN(ass.CreatedTime) AS CreatedDate
	FROM DCS_DataCenter.Association AS ass
	WHERE ass.DeviceID = ip_DeviceID
	GROUP BY ass.SubscriberID;
	
	SELECT	tmpFs.SubscriberID
		,	sub.SubscriberName
		,	tmpFs.CreatedDate
	FROM Temp_FirstSeenDate AS tmpFs
		INNER JOIN CTS_Admin.Subscriber AS sub ON tmpFs.SubscriberID = sub.SubscriberID;
END$$
DELIMITER ;