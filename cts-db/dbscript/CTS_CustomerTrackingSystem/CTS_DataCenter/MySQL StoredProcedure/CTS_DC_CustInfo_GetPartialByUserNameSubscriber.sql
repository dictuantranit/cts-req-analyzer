/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_GetPartialByUserNameSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetPartialByUserNameSubscriber`(
		IN ip_SubscriberID		INT
	,	IN ip_UserName			VARCHAR(50)
	,	IN ip_Skip				INT
	,	IN ip_Take				INT
	,	OUT	op_TotalItem		INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230601@Casey.Huynh
		Task :		Search parital Customer by UserName in subscribers
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230601@Casey.Huynh: Created [Redmine ID: 185787]
			- 	20250609@Aida.Tran: Updated exclude test account [Redmine ID: 227652]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL CTS_DC_CustInfo_GetPartialByUserNameSubscriber(@ip_SubscriberID:=6,@ip_NameList:='12BetAu', @ip_Skip:=0, @ip_Take:=100, @op_TotalItem1); SELECT @op_TotalItem1;

	*/   
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
	CREATE TEMPORARY TABLE Temp_Customer(
			UserName		VARCHAR(50)  PRIMARY KEY
		,	RegisterName	VARCHAR(50)
		,	CTSCustID		BIGINT UNSIGNED
		,	SubscriberID	INT
		,	LastLoginTime	DATETIME(4)

		,	INDEX IX_Temp_Customer_LastLoginTime(LastLoginTime)
	);

	#========SEARCH BY USERNAME=====================
	INSERT INTO Temp_Customer (CTSCustID, Username, RegisterName, SubscriberID, LastLoginTime)
	SELECT	cus.CTSCustID
		,	cus.Username
		,	cus.RegisterName
		,	cus.SubscriberID
		,	cus.LastLoginTime
	FROM CTS_DataCenter.CTSCustomer AS cus
	WHERE cus.SubscriberID = ip_SubscriberID 
		AND cus.RegisterName LIKE CONCAT(ip_UserName,'%') 
		AND cus.IsInternal = 0 
		AND cus.LastLoginTime IS NOT NULL
		AND cus.CurrencyID NOT IN (20, 27, 28, 72);

	#========SEARCH BY USERNAME2=====================
	INSERT IGNORE INTO Temp_Customer (CTSCustID, Username, RegisterName, SubscriberID, LastLoginTime)
	SELECT	cus.CTSCustID
		,	cus.Username
		,	cus.RegisterName
		,	cus.SubscriberID
		,	cus.LastLoginTime
	FROM CTS_DataCenter.CTSCustomer AS cus
	WHERE cus.SubscriberID = ip_SubscriberID 
		AND cus.UserName LIKE CONCAT(ip_UserName,'%') 
		AND cus.IsInternal = 0 
		AND cus.LastLoginTime IS NOT NULL
		AND cus.CurrencyID NOT IN (20, 27, 28, 72);

	SET op_TotalItem = (SELECT COUNT(1) FROM Temp_Customer);

	SELECT	tmpCus.CTSCustID
		,	tmpCus.Username
		,	tmpCus.RegisterName
		,	tmpCus.SubscriberID
	FROM Temp_Customer AS tmpCus
	ORDER BY tmpCus.LastLoginTime DESC
	LIMIT ip_Skip, ip_Take;

END$$
DELIMITER ;
