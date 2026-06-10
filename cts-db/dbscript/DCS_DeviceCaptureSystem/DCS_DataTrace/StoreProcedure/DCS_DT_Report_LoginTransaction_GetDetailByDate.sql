/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Report_LoginTransaction_GetDetailByDate`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Report_LoginTransaction_GetDetailByDate`(
		IN ip_TransDate DATE
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231017@Jonathan.Doan
	Task : Get report detail LoginTransaction by date
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20231017@Jonathan.Doan: Created [Redmine ID: 195332]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataTrace.DCS_DT_Report_LoginTransaction_GetDetailByDate('2023-10-04');
	*/
	DROP TEMPORARY TABLE IF EXISTS Temp_FlaggedGroup;
    
	CREATE TEMPORARY TABLE Temp_FlaggedGroup(
			FlaggedGroupID		SMALLINT UNSIGNED NOT NULL PRIMARY KEY
		, 	FlaggedGroupName	VARCHAR(50) DEFAULT NULL
	);
    
    INSERT INTO Temp_FlaggedGroup(FlaggedGroupID, FlaggedGroupName)
    SELECT 	DISTINCT 
			GroupID
		,	GroupName
    FROM DCS_DataCenter.StaticList
    WHERE ListID = 1;
    
	SELECT 	trans.TransDate
		,	trans.SubscriberID
		,	sub.SubscriberName
		,	trans.AccountID
		,	cts.CustID
		,	cts.Site
		,	cts.Currency
		,	cc.CustomerClass
		,	cc.CustomerClassName
		,	tmpF.FlaggedGroupName AS Flagged
		,	trans.TotalTrans
	FROM DCS_DataTrace.LoginTransactionSummary AS trans
		INNER JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = trans.SubscriberID
		INNER JOIN CTS_DataCenter.CustDCSAccount AS dcs ON dcs.AccountID = trans.AccountID
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cts ON cts.CTSCustID = dcs.CTSCustID
		LEFT JOIN CTS_DataCenter.CTSCustomerClassification AS ctscc ON ctscc.CustID = cts.CustID
		LEFT JOIN CTS_DataCenter.CustomerCategory cc on cc.CategoryID = ctscc.CategoryID
		LEFT JOIN Temp_FlaggedGroup AS tmpF ON tmpF.FlaggedGroupID = trans.FlaggedGroupID
	WHERE trans.TransDate = ip_TransDate;
END$$
DELIMITER ;
