/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Association_GetAccountsPerDevice`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Association_GetAccountsPerDevice`(
		IN ip_SubscriberID	INT
	,	IN ip_LastDay		INT
    ,	IN ip_NoOfAccount	INT
    ,	IN ip_PageSize 		INT
    ,	IN ip_PageIndex 	INT
    
    ,	OUT op_TotalPages 	INT
    ,	OUT op_TotalRows 	INT
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20250520@Lando.Vu
	Task : Get Accounts Per Device report
	DB: DCS_DataCenter
	Original:

	Revisions:
		- 20250520@Lando.Vu: Created [Redmine ID: 227652]
        - 20250606@Aida.Tran: Updated logic [Redmine ID: 227652]
		
	Param's Explanation (filtered by):

	Example:
		SET @SubcriberID 	= 2;
		SET @LastDay		= 100;
		SET @NoOfAccount	= 1;
		SET @PageSize		= 25;
		SET @PageIndex		= 1;

		CALL DCS_DataCenter.DCS_DC_Association_GetAccountsPerDevice(@SubcriberID, @LastDay, @NoOfAccount, @PageSize, @PageIndex, @TotalPages, @TotalRows);
        SELECT @TotalPages, @TotalRows
	*/
    
    DECLARE lv_CutoffDate	DATE;
    DECLARE lv_Offset 		INT;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_DeviceIDNoOfAccount;
	CREATE TEMPORARY TABLE Temp_DeviceIDNoOfAccount (
            DeviceID		BIGINT UNSIGNED PRIMARY KEY
		,	NoOfAccount		INT
	);
    
	SET lv_CutoffDate = DATE_SUB(NOW(), INTERVAL ip_LastDay DAY);

	INSERT INTO Temp_DeviceIDNoOfAccount(DeviceID, NoOfAccount)
	SELECT	ass.DeviceID
		,	COUNT(ass.AccountID) AS NoOfAccount
	FROM DCS_DataCenter.Association AS ass
        INNER JOIN DCS_DataCenter.Account AS acc ON ass.AccountID = acc.AccountID
        INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON ass.AccountID = ca.AccountID
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID AND cus.IsInternal = 0 AND cus.CurrencyID NOT IN (20, 27, 28, 72)
	WHERE ass.SubscriberID = ip_SubscriberID
		AND acc.LastLoginTime >= lv_CutoffDate
	GROUP BY ass.DeviceID
	HAVING COUNT(ass.AccountID) >= ip_NoOfAccount;
    
    SET op_TotalRows = (SELECT COUNT(1) FROM Temp_DeviceIDNoOfAccount);
    
    IF op_TotalRows > 0 THEN
		SET ip_PageSize = LEAST(ip_PageSize, op_TotalRows);
		SET op_TotalPages = CEIL(op_TotalRows / ip_PageSize);
		SET lv_Offset = (ip_PageIndex - 1) * ip_PageSize;
        
		SELECT	tmp.DeviceID
			,	device.FirstDeviceCode AS DeviceNo
			,	tmp.NoOfAccount
		FROM Temp_DeviceIDNoOfAccount AS tmp
			INNER JOIN DCS_DataCenter.Device AS device ON tmp.DeviceID = device.DeviceID
		ORDER BY tmp.NoOfAccount DESC, tmp.DeviceID ASC
		LIMIT ip_PageSize
		OFFSET lv_Offset;
	ELSE
		SET op_TotalPages = 0;
		SET op_TotalRows = 0;
    END IF;
    
END$$
DELIMITER ;
