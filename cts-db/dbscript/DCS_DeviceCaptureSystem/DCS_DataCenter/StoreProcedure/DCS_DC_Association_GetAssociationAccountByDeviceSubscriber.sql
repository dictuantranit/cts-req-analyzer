/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Association_GetAssociationAccountByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Association_GetAssociationAccountByDeviceSubscriber`(
		IN ip_SubscriberID		INT
	,	IN ip_DeviceID			BIGINT UNSIGNED
	,	IN ip_NoOfRecord		INT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20250602@Aida.Tran
		Task :		Get Association Account List BY DeviceID
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 	20250602@Aida.Tran: Created [Redmine ID: 227652]
			
		Param's Explanation (filtered by):
			@ip_NoOfRecord = 0 GET All Association Account
			@ip_NoOfRecord > 0 GET ip_NoOfRecord Association Account
			
		Example:
			CALL DCS_DC_Association_GetAssociationAccountByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_DeviceID:=1,@ip_NoOfRecord:=2); 
			CALL DCS_DC_Association_GetAssociationAccountByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_DeviceID:=1,@ip_NoOfRecord:=0); 
   
	*/
	DROP TEMPORARY TABLE IF EXISTS Temp_Association;
	CREATE TEMPORARY TABLE Temp_Association(
			AccountID		BIGINT UNSIGNED
		,	DeviceID		BIGINT UNSIGNED
		,	CreatedTime		DATETIME(4)

		,	PRIMARY KEY PK_Temp_Association(AccountID, DeviceID)
		,	INDEX IX_Temp_Association_DeviceID(DeviceID)
		,	INDEX IX_Temp_Association_CreatedTime(CreatedTime)
	); 

	DROP TEMPORARY TABLE IF EXISTS Temp_AccountID;
	CREATE TEMPORARY TABLE Temp_AccountID(
			AccountID			BIGINT UNSIGNED PRIMARY KEY
		,	LastCreatedTime		DATETIME(4)
		
		,	INDEX IX_Temp_AccountID_LastCreatedTime(LastCreatedTime)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedAccount;
	CREATE TEMPORARY TABLE Temp_AssociatedAccount(
			AccountID			BIGINT UNSIGNED PRIMARY KEY
		,	UserName 			VARCHAR(50)
		,	RegisterName		VARCHAR(50)
		,	DeviceInCommon		INT
		,	OtherDeives			INT
		,	AssociatedAccount	INT
		,	MaxCreatedTime		DATETIME(4)

		,	INDEX IX_Temp_AssociatedAccount(MaxCreatedTime DESC)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_AccountAssociation;
	CREATE TEMPORARY TABLE Temp_AccountAssociation(
			RootAccountID 		BIGINT UNSIGNED
		,	DeviceID 			BIGINT UNSIGNED
		,	CreatedTime 		DATETIME(4)
		,	AssAccountID 		BIGINT UNSIGNED
		, 	PRIMARY KEY PK_Temp_AccountAssociation(RootAccountID,DeviceID, AssAccountID));
	
	#======GET Cust Association LIST: ip_DeviceID AND ASSOCIATED CUSTOMER=======================================    

	IF ip_NoOfRecord > 0 THEN 

		INSERT INTO Temp_AccountID(AccountID, LastCreatedTime)
		SELECT 	DISTINCT 
				ass.AccountID
			,	MAX(ass.CreatedTime) AS LastCreatedTime
		FROM DCS_DataCenter.Association AS ass
		WHERE ass.DeviceID = ip_DeviceID 
			AND ass.SubscriberID = ip_SubscriberID
		GROUP BY ass.AccountID
		ORDER BY LastCreatedTime DESC
		LIMIT ip_NoOfRecord;   

	END IF;
	
	IF ip_NoOfRecord = 0 THEN 

		INSERT INTO Temp_AccountID(AccountID, LastCreatedTime)
		SELECT 	DISTINCT
				ass.AccountID
			,	MAX(ass.CreatedTime) AS LastCreatedTime
		FROM DCS_DataCenter.Association AS ass
		WHERE ass.DeviceID = ip_DeviceID 
			AND ass.SubscriberID = ip_SubscriberID
		GROUP BY ass.AccountID
		ORDER BY LastCreatedTime DESC;
		
	END IF;

	#=====GET ASSOCIATION LIST OF ALL Association Cust===============================================================================
	INSERT IGNORE INTO Temp_Association(AccountID, DeviceID, CreatedTime)
	SELECT	ass.AccountID
		,	ass.DeviceID
		,	tmpAcc.LastCreatedTime
	FROM DCS_DataCenter.Association AS ass
		INNER JOIN Temp_AccountID AS tmpAcc ON ass.SubscriberID = ip_SubscriberID AND ass.AccountID = tmpAcc.AccountID;

	INSERT IGNORE INTO Temp_AccountAssociation(RootAccountID, DeviceId, CreatedTime, AssAccountID)
	SELECT	tmpAs.AccountID
		, 	tmpAs.DeviceID
		,	tmpAs.CreatedTime
		,	ass.AccountID
	FROM Temp_Association AS tmpAs
		LEFT JOIN DCS_DataCenter.Association AS ass ON ass.SubscriberID = ip_SubscriberID 
													AND tmpAs.DeviceID = ass.DeviceID 
                                                    AND tmpAs.AccountID <> ass.AccountID;

	INSERT INTO Temp_AssociatedAccount(AccountID, RegisterName, UserName, DeviceInCommon, OtherDeives, AssociatedAccount, MaxCreatedTime)
	SELECT	tmpAs.RootAccountID AS AccountID
		,	cus.RegisterName
		,	cus.UserName
		,	COUNT(DISTINCT CASE WHEN tmpAs.AssAccountID > 0 THEN tmpAs.DeviceID ELSE NULL END) AS DeviceInCommon
		,	COUNT(DISTINCT tmpAs.DeviceID) - COUNT(DISTINCT CASE WHEN tmpAs.AssAccountID > 0 THEN tmpAs.DeviceID ELSE NULL END) AS OtherDevices
		,	COUNT(DISTINCT CASE WHEN tmpAs.AssAccountID > 0 THEN tmpAs.AssAccountID ELSE NULL END) AS AsscociatedAccount
		,	MAX(tmpAs.CreatedTime) AS MaxCreatedTime
	FROM Temp_AccountAssociation AS tmpAs		
		INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON tmpAs.RootAccountID = ca.AccountID AND ca.SubscriberID = ip_SubscriberID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID 
													AND cus.IsInternal = 0 
													AND cus.CurrencyID NOT IN (20, 27, 28, 72)
	GROUP BY tmpAs.RootAccountID;

	SELECT	tmpAa.AccountID
		,	tmpAa.RegisterName
		,	tmpAa.UserName
		,	tmpAa.DeviceInCommon
		,	tmpAa.OtherDeives
		,	tmpAa.AssociatedAccount
	FROM Temp_AssociatedAccount AS tmpAa
	ORDER BY tmpAa.MaxCreatedTime DESC;
	
END$$
DELIMITER ;