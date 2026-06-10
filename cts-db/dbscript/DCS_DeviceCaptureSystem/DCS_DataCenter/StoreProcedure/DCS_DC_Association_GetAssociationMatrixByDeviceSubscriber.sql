/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Association_GetAssociationMatrixByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Association_GetAssociationMatrixByDeviceSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_DeviceID		BIGINT UNSIGNED
	,	IN ip_NoOfCustomer	INT
	,	IN ip_NoOfDevice	INT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20250602@Aida.Tran
		Task :		Get Matrix By Device
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 	20250602@Aida.Tran: Created [Redmine ID: 227652]
			
		Param's Explanation (filtered by):
			
		Example:
				CALL DCS_DC_Association_GetAssociationMatrixByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_DeviceID:=1,@ip_NoOfCustomer:=16, @ip_NoOfDevice:=100);
				CALL DCS_DC_Association_GetAssociationMatrixByDeviceSubscriber(8000001, 141, 15, 100);

	*/
    
	#======GET Cust Association LIST: ip_DeviceID AND ASSOCIATED CUSTOMER=======================================  
	DROP TEMPORARY TABLE IF EXISTS Temp_Matrix;
	CREATE TEMPORARY TABLE Temp_Matrix(
			DeviceID			BIGINT UNSIGNED		
		,	CreatedTime			DATETIME(4)
		,	FirstDeviceCode		VARCHAR(32)
		,	AccountID			BIGINT UNSIGNED
		,	RegisterName		VARCHAR(50)
		,	UserName			VARCHAR(50)
		,	AssCreatedTime		DATETIME(4)

		,	PRIMARY KEY (DeviceID, AccountID)        
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_RootDevice;
	CREATE TEMPORARY TABLE Temp_RootDevice(
			DeviceID			BIGINT UNSIGNED	PRIMARY KEY
		,	FirstDeviceCode		VARCHAR(32)
		,	CreatedTime 		DATETIME(4)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_AccountAssociation;
	CREATE TEMPORARY TABLE Temp_AccountAssociation(
			AccountID 			BIGINT UNSIGNED PRIMARY KEY
		,	LastAssCreatedTime	DATETIME(4)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE Temp_Account(
			AccountID 			BIGINT UNSIGNED PRIMARY KEY
		,	CreatedTime			DATETIME(4)
	);
	#==============================================
	INSERT INTO Temp_Account(AccountID, CreatedTime)
	SELECT	ass.AccountID
		,	MAX(ass.CreatedTime) AS LastCreatedTime
	FROM DCS_DataCenter.Association AS ass
	WHERE ass.SubscriberID = ip_SubscriberID 
		AND ass.DeviceID = ip_DeviceID
	GROUP BY ass.AccountID
	ORDER BY LastCreatedTime DESC
	LIMIT ip_NoOfCustomer;  

	INSERT IGNORE INTO Temp_RootDevice(DeviceID, FirstDeviceCode, CreatedTime)
	SELECT	dv.DeviceID
		,	dv.FirstDeviceCode
		,	dv.CreatedTime
	FROM Temp_Account AS tmpAc
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.AccountID = tmpAc.AccountID
		INNER JOIN DCS_DataCenter.Device AS dv ON dv.DeviceID = ass.DeviceID        
	ORDER BY  dv.CreatedTime DESC
	LIMIT ip_NoOfDevice;    

	INSERT IGNORE INTO Temp_Matrix(DeviceID, FirstDeviceCode, CreatedTime, AccountID, RegisterName, UserName, AssCreatedTime )
	SELECT  ass.DeviceID
		,	dv.FirstDeviceCode
		,	dv.CreatedTime
		,	ass.AccountID
		,	cus.RegisterName
		,	cus.UserName
		,	ass.CreatedTime
	FROM Temp_Account AS tmpAc
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.AccountID = tmpAc.AccountID
		INNER JOIN Temp_RootDevice AS dv ON dv.DeviceID = ass.DeviceID
		INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON tmpAc.AccountID = ca.AccountID AND ca.SubscriberID = ip_SubscriberID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID 
													AND cus.IsInternal = 0 
													AND cus.CurrencyID NOT IN (20, 27, 28, 72)
	;

	INSERT INTO Temp_AccountAssociation(AccountID, LastAssCreatedTime)
	SELECT	tmpMt.AccountID
		,	MAX(AssCreatedTime) AS LastAssCreatedTime
	FROM Temp_Matrix AS tmpMt
	GROUP BY tmpMt.AccountID
	ORDER BY LastAssCreatedTime DESC; 

	SELECT	tmpMt.AccountID
		,	tmpMt.RegisterName
		,	tmpMt.UserName
		,	tmpMt.DeviceID
		,	tmpMt.FirstDeviceCode
		,	tmpMt.CreatedTime
	FROM Temp_Matrix AS tmpMt
		INNER JOIN Temp_AccountAssociation AS tmpAc ON tmpAc.AccountID = tmpMt.AccountID
	ORDER BY tmpAc.LastAssCreatedTime DESC;
	
END$$
DELIMITER ;