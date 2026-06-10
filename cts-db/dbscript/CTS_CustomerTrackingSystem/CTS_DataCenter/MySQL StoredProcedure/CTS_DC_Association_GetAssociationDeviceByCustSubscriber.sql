/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_GetAssociationDeviceByCustSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetAssociationDeviceByCustSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_CTSCustID		BIGINT UNSIGNED
	,	IN ip_NoOfRecord	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230601@Casey.Huynh
		Task :		Get Association Devices List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230601@Casey.Huynh: Created [Redmine ID: 185787]
            -	20250610@Aida.Tran: Exclude Test Account [Redmine ID: 227652]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL CTS_DC_Association_GetAssociationDeviceByCustSubscriber(@ip_SubscriberID:=6,@ip_CTSCustID:=2605665,@ip_NoOfRecord:=15); 
   
	*/
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedDevice;
	CREATE TEMPORARY TABLE Temp_AssociatedDevice(
			AccountID		BIGINT UNSIGNED
		,	DeviceID		BIGINT UNSIGNED
        ,	CTSCustID		BIGINT UNSIGNED
        ,	CreatedTime		DATETIME(4)
        
        ,	PRIMARY KEY PK_Temp_AssociatedDevice(AccountID, DeviceID)
        ,	INDEX IX_Temp_AssociatedDevice_DeviceID(DeviceID)
        ,	INDEX IX_Temp_AssociatedDevice_CTSCustID(CTSCustID)
    ); 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedAccount;
	CREATE TEMPORARY TABLE Temp_AssociatedAccount(
			AccountID		BIGINT UNSIGNED
		,	DeviceID		BIGINT UNSIGNED
        ,	CTSCustID		BIGINT UNSIGNED
        ,	CreatedTime		DATETIME(4)
        
        ,	PRIMARY KEY PK_Temp_AssociatedAccount(AccountID, DeviceID)
        ,	INDEX IX_Temp_AssociatedAccount_DeviceID(DeviceID)
        ,	INDEX IX_Temp_AssociatedAccount_CTSCustID(CTSCustID)
    );
		   
	DROP TEMPORARY TABLE IF EXISTS Temp_Device;
	CREATE TEMPORARY TABLE Temp_Device(
			DeviceID	BIGINT UNSIGNED PRIMARY KEY
        ,	CreatedTime	DATETIME(4)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE Temp_Account(
			AccountID BIGINT UNSIGNED PRIMARY KEY
        ,	CTSCustID BIGINT UNSIGNED
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedDeviceInfo;
	CREATE TEMPORARY TABLE Temp_AssociatedDeviceInfo(
			DeviceID			BIGINT UNSIGNED
        ,	AssociatedAccounts	INT
        ,	AssociatedDevices	INT
        ,	CreatedTime			DATETIME(4)
        
        ,	PRIMARY KEY PK_Temp_AssociatedAccount(DeviceID)
    );  
    
    #======GET Cust Association LIST: ip_CTSCustID AND ASSOCIATED CUSTOMER=======================================          

    INSERT INTO Temp_Device(DeviceID, CreatedTime)
	SELECT	ass.DeviceID
		,	ass.CreatedTime
    FROM CTS_DataCenter.CustDCSAccount AS cda
		INNER JOIN DCS_DataCenter.Association AS ass ON cda.AccountID = ass.AccountID
    WHERE cda.SubscriberID = ip_SubscriberID AND cda.CTSCustID = ip_CTSCustID
    ORDER BY  ass.CreatedDate DESC, ass.CreatedTime DESC
    LIMIT ip_NoOfRecord;        
  
    INSERT INTO Temp_AssociatedDevice(AccountID, DeviceID, CTSCustID,  CreatedTime)
    SELECT	ass.AccountID
		,	ass.DeviceID
		,	cda.CTSCustID
        ,	tmpDv.CreatedTime
    FROM Temp_Device AS tmpDv
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.DeviceID = tmpDv.DeviceID AND ass.SubscriberID = ip_SubscriberID 
        INNER JOIN CTS_DataCenter.CustDCSAccount AS cda ON cda.AccountID = ass.AccountID
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = cda.CTSCustID 
														AND cus.IsInternal = 0  
														AND cus.CurrencyID NOT IN (20, 27, 28, 72);

	INSERT INTO Temp_Account(AccountID, CTSCustID)
    SELECT DISTINCT tmpAd.AccountID
		,	tmpAd.CTSCustID
    FROM Temp_AssociatedDevice AS tmpAd;    
    
    INSERT INTO Temp_AssociatedAccount(AccountID, DeviceID, CTSCustID, CreatedTime)
    SELECT	tmpAc.AccountID
		,	ass.DeviceID
		,	tmpAc.CTSCustID
        ,	ass.CreatedTime
    FROM Temp_Account AS tmpAc
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.AccountID = tmpAc.AccountID;
     
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
		INNER JOIN DCS_DataCenter.Device AS dv ON dv.DeviceID = tmpAd.DeviceID
	ORDER BY dv.CreatedTime DESC;     
    
END$$
DELIMITER ;