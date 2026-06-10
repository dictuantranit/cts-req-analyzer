/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_GetByNameSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetByNameSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_UserName		VARCHAR(50)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230601@Casey.Huynh
		Task :		Search Customer by UserName in subscribers
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230601@Casey.Huynh: Created [Redmine ID: 185787]
			- 	20250609@Aida.Tran: Updated exclude test account [Redmine ID: 227652]
		Param's Explanation (filtered by):
			
		Example:
			CALL CTS_DC_CustInfo_GetByNameSubscriber(@ip_SubscriberID:=6,@ip_UserName:='12BETAUD01005');
			CALL CTS_DC_CustInfo_GetByNameSubscriber(@ip_SubscriberID:=6,@ip_UserName:='wintiger');
	*/   

	DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
	CREATE TEMPORARY TABLE Temp_Customer(
			UserName		VARCHAR(50)  PRIMARY KEY
		,	RegisterName	VARCHAR(50)
		,	CTSCustID		BIGINT UNSIGNED
		,	SubscriberID	INT        
	);
	
	#========SEARCH BY USERNAME2=====================
	INSERT INTO Temp_Customer (CTSCustID, Username, RegisterName, SubscriberID)
	SELECT	cus.CTSCustID
		,	cus.Username
		,	cus.RegisterName
		,	cus.SubscriberID
	FROM CTS_DataCenter.CTSCustomer AS cus
	WHERE cus.SubscriberID = ip_SubscriberID 
		AND cus.RegisterName = ip_UserName 
		AND cus.IsInternal = 0
		AND cus.CurrencyID NOT IN (20, 27, 28, 72);

	#========SEARCH BY USERNAME=====================
	INSERT IGNORE INTO Temp_Customer (CTSCustID, Username, RegisterName, SubscriberID)
	SELECT	cus.CTSCustID
		,	cus.Username
		,	cus.RegisterName
		,	cus.SubscriberID
	FROM CTS_DataCenter.CTSCustomer AS cus
	WHERE cus.SubscriberID = ip_SubscriberID 
		AND cus.Username = ip_UserName 
		AND cus.IsInternal = 0
		AND cus.CurrencyID NOT IN (20, 27, 28, 72);

	SELECT	tmpCus.CTSCustID
		,	tmpCus.Username
		,	tmpCus.RegisterName
		,	tmpCus.SubscriberID
	FROM Temp_Customer AS tmpCus;

END$$
DELIMITER ;
