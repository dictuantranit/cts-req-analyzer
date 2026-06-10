/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Report_LoginTransactionByBrowser_GetByDateRange`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Report_LoginTransactionByBrowser_GetByDateRange`(
		IN ip_FromDate 	DATE
    ,	IN ip_ToDate 	DATE
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20240315@Jonathan.Doan
	Task : Get report LoginTransactionSummaryByBrowser
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20240315@Jonathan.Doan: Created [Redmine ID: 195332]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataTrace.DCS_DT_Report_LoginTransactionByBrowser_GetByDateRange('2024-03-15', '2024-03-15');
	*/
	select 	trans.TransDate
		,	trans.BrowserID
		,	br.BrowserName
		,	trans.OSID
		,	os.OSName
		,	trans.DeviceTypeID
		,	dt.DeviceType
		,	SUM(trans.TotalTrans) AS TotalTrans
		,	SUM(trans.TotalInvalidBrowers) AS TotalInvalidBrowers
		,	SUM(trans.TotalBotTrans) AS TotalBotTrans
	from DCS_DataTrace.LoginTransactionSummaryByBrowser AS trans
		INNER JOIN DCS_DataTrace.Browser AS br ON br.ID = trans.BrowserID
		INNER JOIN DCS_DataTrace.OS AS os ON os.ID = trans.OSID
		INNER JOIN DCS_DataTrace.DeviceType AS dt ON dt.ID = trans.DeviceTypeID
	WHERE trans.TransDate BETWEEN ip_FromDate AND ip_ToDate
	GROUP BY trans.TransDate, trans.BrowserID, trans.OSID, trans.DeviceTypeID;

END$$
DELIMITER ;
