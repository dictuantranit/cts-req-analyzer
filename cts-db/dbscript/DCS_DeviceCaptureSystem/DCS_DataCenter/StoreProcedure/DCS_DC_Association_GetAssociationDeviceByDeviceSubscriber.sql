/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Association_GetAssociationDeviceByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Association_GetAssociationDeviceByDeviceSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_DeviceID		BIGINT UNSIGNED
	,	IN ip_NoOfRecord	INT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20250602@Aida.Tran
		Task :		Get Association Devices List
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 	20250602@Aida.Tran: Created [Redmine ID: 227652]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Association_GetAssociationDeviceByDeviceSubscriber(@ip_SubscriberID:=8000005,@ip_DeviceID:=299,@ip_NoOfRecord:=15) 

	*/
	DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE Temp_Account(
			AccountID 		BIGINT UNSIGNED PRIMARY KEY
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Device;
	CREATE TEMPORARY TABLE Temp_Device(
			DeviceID		BIGINT UNSIGNED PRIMARY KEY
		,	CreatedTime		DATETIME(4)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_DistinctAccount;
	CREATE TEMPORARY TABLE Temp_DistinctAccount(
			AccountID 		BIGINT UNSIGNED PRIMARY KEY
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedDevice;
	CREATE TEMPORARY TABLE Temp_AssociatedDevice(
			AccountID		BIGINT UNSIGNED
		,	DeviceID		BIGINT UNSIGNED

		,	PRIMARY KEY PK_Temp_AssociatedDevice(AccountID, DeviceID)
		,	INDEX IX_Temp_AssociatedDevice_DeviceID(DeviceID)
	); 

	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedAccount;
	CREATE TEMPORARY TABLE Temp_AssociatedAccount(
			AccountID		BIGINT UNSIGNED
		,	DeviceID		BIGINT UNSIGNED

		,	PRIMARY KEY PK_Temp_AssociatedAccount(AccountID, DeviceID)
		,	INDEX IX_Temp_AssociatedAccount_DeviceID(DeviceID)
	);
		   
	

	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedDeviceInfo;
	CREATE TEMPORARY TABLE Temp_AssociatedDeviceInfo(
			DeviceID			BIGINT UNSIGNED
		,	AssociatedAccounts	INT
		,	AssociatedDevices	INT

		,	PRIMARY KEY PK_Temp_AssociatedDevice(DeviceID)
	);

	#======GET Cust Association LIST: ip_DeviceID AND ASSOCIATED CUSTOMER=======================================    
	INSERT IGNORE INTO Temp_Account(AccountID)
	SELECT ass.AccountID
	FROM DCS_DataCenter.Association AS ass
		INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON ass.AccountID = ca.AccountID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID 
													AND cus.IsInternal = 0 
													AND cus.CurrencyID NOT IN (20, 27, 28, 72)
	WHERE ass.SubscriberID = ip_SubscriberID 
		AND ass.DeviceID = ip_DeviceID
	ORDER BY ass.CreatedDate DESC;

	IF ip_NoOfRecord > 0 THEN 

		INSERT IGNORE INTO Temp_Device(DeviceID, CreatedTime)
		SELECT	ass.DeviceID
			,	MAX(ass.CreatedTime) AS MaxCreatedTime
		FROM DCS_DataCenter.Association AS ass 
			INNER JOIN Temp_Account AS acc ON ass.AccountID = acc.AccountID 
		GROUP BY ass.DeviceID
		ORDER BY MaxCreatedTime DESC
		LIMIT ip_NoOfRecord; 

	END IF;

	IF ip_NoOfRecord = 0 THEN 

		INSERT IGNORE INTO Temp_Device(DeviceID, CreatedTime)
		SELECT	ass.DeviceID
			,	MAX(ass.CreatedTime) AS MaxCreatedTime
		FROM DCS_DataCenter.Association AS ass 
			INNER JOIN Temp_Account AS acc ON ass.AccountID = acc.AccountID 
		GROUP BY ass.DeviceID
		ORDER BY MaxCreatedTime DESC;

	END IF;

	INSERT INTO Temp_AssociatedDevice(AccountID, DeviceID)
	SELECT	ass.AccountID
		,	ass.DeviceID
	FROM Temp_Device AS tmpDv
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.SubscriberID = ip_SubscriberID AND ass.DeviceID = tmpDv.DeviceID;

	INSERT INTO Temp_DistinctAccount(AccountID)
	SELECT DISTINCT tmpAd.AccountID
	FROM Temp_AssociatedDevice AS tmpAd;    

	INSERT INTO Temp_AssociatedAccount(AccountID, DeviceID)
	SELECT	tmpAc.AccountID
		,	ass.DeviceID
	FROM Temp_DistinctAccount AS tmpAc
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.AccountID = tmpAc.AccountID;

	INSERT INTO Temp_AssociatedDeviceInfo(DeviceID, AssociatedAccounts, AssociatedDevices)
	SELECT	tmpAd.DeviceID
		,	COUNT(DISTINCT tmpAa.AccountID) AS AssociatedAccounts
		,	COUNT(DISTINCT tmpAa.DeviceID)-1 AS AssociatedDevices
	FROM Temp_AssociatedDevice AS tmpAd
		INNER JOIN Temp_AssociatedAccount AS tmpAa ON tmpAd.AccountID = tmpAa.AccountID
	GROUP BY tmpAd.DeviceID;

	SELECT	dv.DeviceID
		,	dv.FirstDeviceCode AS DeviceCode
		,	DATE(dv.CreatedTime) AS FirstSeenDate
		,	tmpAd.AssociatedAccounts
		,	tmpAd.AssociatedDevices
	FROM Temp_AssociatedDeviceInfo AS tmpAd
		INNER JOIN DCS_DataCenter.Device AS dv ON dv.DeviceID = tmpAd.DeviceID
	ORDER BY dv.CreatedTime DESC;     
END$$
DELIMITER ;