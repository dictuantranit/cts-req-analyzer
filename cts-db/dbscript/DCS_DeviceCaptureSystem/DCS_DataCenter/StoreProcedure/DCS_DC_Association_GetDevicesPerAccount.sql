/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Association_GetDevicesPerAccount`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Association_GetDevicesPerAccount`(
		IN ip_SubscriberID	INT
	,	IN ip_NoOfDevice	INT
	,	IN ip_LastDay		INT
	,	IN ip_PageSize		INT
	,	IN ip_PageIndex		INT

	,	OUT op_TotalPages	INT
	,	OUT op_TotalRows	INT
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20250521@Jonathan.Doan
	Task : Get Devices Per Account (Sub site)
	DB: DCS_DataCenter
	Original:

	Revisions:
		- 20230321@Jonathan.Doan: Created [Redmine ID: 227652]
        - 20250606@Aida.Tran: Updated Logic [Redmine ID: 227652] 
		
	Param's Explanation (filtered by):

	Example:
		SET @SubcriberID = 2;
		SET @NoOfDevice	= 1;
		SET @LastDay	= 100;
		SET @PageSize	= 25;
		SET @PageIndex	= 1;

		CALL DCS_DataCenter.DCS_DC_Association_GetDevicesPerAccount(@SubcriberID, @NoOfDevice, @LastDay, @PageSize, @PageIndex, @op_TotalPages, @op_TotalRows);
		SELECT @op_TotalPages,@op_TotalRows;
	*/

	DECLARE lv_CutoffDate	DATE;
	DECLARE lv_Offset 		INT;

	DROP TEMPORARY TABLE IF EXISTS Temp_AccountNoOfDevice;
	CREATE TEMPORARY TABLE Temp_AccountNoOfDevice (
			AccountID		BIGINT UNSIGNED PRIMARY KEY
		,	NoOfDevice		INT
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_CustomerInfo;
	CREATE TEMPORARY TABLE Temp_CustomerInfo (
			CTSCustID		BIGINT UNSIGNED PRIMARY KEY
		,	RegisterName	VARCHAR(50)
		,	UserName		VARCHAR(50)
		,	NoOfDevice		INT
	);

	SET lv_CutoffDate = DATE_SUB(NOW(), INTERVAL ip_LastDay DAY);

	INSERT INTO Temp_AccountNoOfDevice(AccountID, NoOfDevice)
	SELECT	ass.AccountID
		,	COUNT(ass.DeviceID) AS NoOfDevice
	FROM DCS_DataCenter.Association AS ass
		INNER JOIN DCS_DataCenter.Account AS acc ON ass.AccountID = acc.AccountID
	WHERE ass.SubscriberID = ip_SubscriberID
		AND acc.LastLoginTime >= lv_CutoffDate
	GROUP BY ass.AccountID
	HAVING COUNT(ass.DeviceID) >= ip_NoOfDevice;
    
    INSERT INTO Temp_CustomerInfo(CTSCustID, RegisterName, UserName, NoOfDevice)
	SELECT 	ca.CTSCustID
		,	cus.RegisterName
		,	cus.UserName
		,	tmp.NoOfDevice
	FROM Temp_AccountNoOfDevice AS tmp
		INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON tmp.AccountID = ca.AccountID AND ca.SubscriberID = ip_SubscriberID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID AND cus.IsInternal = 0 AND cus.CurrencyID NOT IN (20, 27, 28, 72);
    
	SET op_TotalRows = (SELECT COUNT(1) FROM Temp_CustomerInfo);

	IF op_TotalRows > 0 THEN
		SET ip_PageSize = LEAST(ip_PageSize, op_TotalRows);
		SET op_TotalPages = CEIL(op_TotalRows / ip_PageSize);
		SET lv_Offset = (ip_PageIndex - 1) * ip_PageSize;

		SELECT 	CTSCustID
			,	RegisterName
			,	UserName
			,	NoOfDevice
		FROM Temp_CustomerInfo
		ORDER BY NoOfDevice DESC, RegisterName ASC, UserName ASC
		LIMIT ip_PageSize
		OFFSET lv_Offset;
	ELSE
		SET op_TotalPages = 0;
		SET op_TotalRows = 0;
	END IF;

END$$
DELIMITER ;