/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Device_GetByDeviceCodeSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Device_GetByDeviceCodeSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_DeviceCode	VARCHAR(32)
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20250526@Lando.Vu
	Task : Get Accounts Per Device report
	DB: DCS_DataCenter
	Original:

	Revisions:
		- 20250526@Lando.Vu: Created [Redmine ID: 227652]
		- 20250609@Aida.Tran: Updated exclude test account [Redmine ID: 227652]
		
	Param's Explanation (filtered by):

	Example:
		CALL DCS_DC_Device_GetByDeviceCodeSubscriber(@ip_SubscriberID:=2,@ip_DeviceCode:='4f143f8ccad246bd8cc95b2fa3202aa2');
	*/

	SELECT	dv.DeviceID 			AS DeviceID
		,	dv.FirstDeviceCode		AS DeviceCode
		,	ua.OS					AS OS
	FROM DCS_DataCenter.Device AS dv
		LEFT JOIN DCS_DataCenter.UserAgent AS ua ON ua.UserAgentKey = dv.UserAgentKey
	WHERE dv.FirstDeviceCode = ip_DeviceCode
		AND EXISTS (SELECT 1
					FROM DCS_DataCenter.Association AS ass
						INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON ass.AccountID = ca.AccountID
						INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID AND cus.IsInternal = 0 AND cus.CurrencyID NOT IN (20, 27, 28, 72)
					WHERE ass.DeviceID = dv.DeviceID
						AND ass.SubscriberID = ip_SubscriberID)
	ORDER BY dv.DeviceID ASC
	LIMIT 1;
END$$
DELIMITER ;
