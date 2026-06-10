/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Report_LoginTransactionByFlagged_GetByDateRange`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Report_LoginTransactionByFlagged_GetByDateRange`(
		IN ip_FromDate 	DATE
    ,	IN ip_ToDate 	DATE
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20240315@Jonathan.Doan
	Task : Get report LoginTransactionSummaryByFlagged
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20240315@Jonathan.Doan: Created [Redmine ID: 195332]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataTrace.DCS_DT_Report_LoginTransactionByFlagged_GetByDateRange('2024-03-15', '2024-03-15');
	*/
    select 	trans.TransDate
		,	trans.Flagged
		,	sl.Description AS FlaggedName
		,	SUM(trans.TotalTrans) AS TotalTrans
	from DCS_DataTrace.LoginTransactionSummaryByFlagged AS trans
		INNER JOIN DCS_DataCenter.StaticList AS sl ON sl.ListID = 1 AND sl.ItemID = trans.Flagged
	WHERE trans.TransDate BETWEEN ip_FromDate AND ip_ToDate
	GROUP BY trans.TransDate, trans.Flagged;
END$$
DELIMITER ;
