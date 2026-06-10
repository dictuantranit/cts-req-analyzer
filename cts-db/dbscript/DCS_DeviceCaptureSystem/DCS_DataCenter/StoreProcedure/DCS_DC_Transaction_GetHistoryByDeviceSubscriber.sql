/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transaction_GetHistoryByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transaction_GetHistoryByDeviceSubscriber`(
		IN	ip_SubscriberID	INT	
	,	IN	ip_FromDate		DATE
	,	IN	ip_ToDate 		DATE
	,	IN	ip_DeviceID		BIGINT UNSIGNED
	,	IN	ip_Skip			INT
	,	IN	ip_Take			INT
	,	OUT	op_TotalItem	INT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20250604@Aida.Tran
		Task :		Get Transaction List By Device
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 	20250609@Aida.Tran: Created [Redmine ID: 227652]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Transaction_GetHistoryByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_FromDate:='2023-01-01',@ip_ip_ToDate:='2023-07-15',@ip_DeviceID:=1,@ip_Skip:=0, @ip_Take:=2000, @op_TotalItem); SELECT @op_TotalItem;    

	*/
	SET @TotalRow = 0;

	SELECT 	tmp.TransID				AS TransID
		,	tmp.TransTime			AS TransTime
		,	tmp.RegisterName		AS RegisterName
		,	tmp.UserName			AS UserName
		,	tmp.AccountID			AS AccountID
		,	tmp.Action				AS Action
		,	tmp.ActionResult		AS ActionResult
		,	tmp.OS					AS OS
		,	tmp.Browser				AS Browser
		,	tmp.URLDetails			AS URLDetails
		,	tmp.IP					AS IP
		,	tmp.ItemName			AS RobotTracking
	FROM	(
			SELECT 	@TotalRow := @TotalRow + 1
				,	trs.TransID
				,	trs.TransTime
				,	cus.RegisterName
				,	cus.UserName
				,	trs.AccountID
				,	ar.Action
				,	ar.ActionResult
				,	uag.OS
				,	uag.Browser
				,	ur.URLDetails
				,	trs.IP
				,	stl.ItemName 
			FROM DCS_DataCenter.Transaction07 AS trs
				INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON trs.AccountID = ca.AccountID AND ca.SubscriberID = ip_SubscriberID
				INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID AND cus.IsInternal = 0 AND cus.CurrencyID NOT IN (20, 27, 28, 72)
				LEFT JOIN DCS_DataCenter.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
				LEFT JOIN DCS_DataCenter.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
				LEFT JOIN DCS_DataCenter.URL AS ur ON trs.URLID = ur.URLID
				LEFT JOIN DCS_DataCenter.StaticList AS stl ON stl.ListID = 1 AND stl.ItemID = trs.Flagged
			WHERE trs.SubscriberID = ip_SubscriberID 
				AND trs.CreatedDate BETWEEN ip_FromDate AND ip_ToDate 
				AND trs.DeviceID = ip_DeviceID
			) AS tmp
		ORDER BY TransTime DESC            
		LIMIT ip_Skip, ip_Take;
		
		SET op_TotalItem = @TotalRow;

END$$

DELIMITER ;
