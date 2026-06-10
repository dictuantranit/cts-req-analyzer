/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Report_MissingTransaction_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Report_MissingTransaction_Get`(
		IN ip_FromDate 	DATE
    ,	IN ip_ToDate 	DATE
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231017@Jonathan.Doan
	Task : Get report MissingTransaction
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20231017@Jonathan.Doan: Created [Redmine ID: 195332]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataTrace.DCS_DT_Report_MissingTransaction_Get('2023-10-01', '2023-10-05');
	*/
    DECLARE CONST_MISSINGLOGINTRANSACTION_TYPE SMALLINT DEFAULT 1;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MissingTransaction;
    
	CREATE TEMPORARY TABLE Temp_MissingTransaction(
			ID 						BIGINT UNSIGNED NOT NULL AUTO_INCREMENT
		, 	TransDate				DATETIME NOT NULL
		, 	SubscriberID			INT UNSIGNED DEFAULT NULL
		, 	SubscriberName			VARCHAR(50) DEFAULT NULL
		, 	CountCustWithoutTrans	INT UNSIGNED DEFAULT 0
		, 	CountCustMissingTrans	INT UNSIGNED DEFAULT 0
		,	PRIMARY KEY (`ID`)
		,	INDEX `IX_Temp_MissingTransaction_TransDate_SubscriberID` (`TransDate`, `SubscriberID`)
	);
    
    INSERT INTO Temp_MissingTransaction(TransDate, SubscriberID, SubscriberName, CountCustWithoutTrans, CountCustMissingTrans)
    SELECT 	mmt.TransDate
		,	mmt.SubscriberID
		,	sub.SubscriberName
		,	SUM(CASE WHEN dcs.CTSCustID IS NULL THEN 1 ELSE 0 END) AS CountCustWithoutTrans
		,	SUM(CASE WHEN dcs.CTSCustID IS NOT NULL THEN 1 ELSE 0 END) AS CountCustMissingTrans
    FROM DCS_DataTrace.MemberMissingTransaction AS mmt
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cts ON cts.CustID = mmt.CustID AND cts.SubscriberID = mmt.SubscriberID
		LEFT JOIN CTS_DataCenter.CustDCSAccount AS dcs ON dcs.SubscriberID = cts.SubscriberID AND dcs.CTSCustID = cts.CTSCustID
		LEFT JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = mmt.SubscriberID
	WHERE mmt.TransDate BETWEEN ip_FromDate AND ip_ToDate
		AND MissingTransactionType = CONST_MISSINGLOGINTRANSACTION_TYPE
	GROUP BY mmt.TransDate, mmt.SubscriberID;
    
    SELECT 	tmp.TransDate
		,	tmp.SubscriberID
		,	tmp.SubscriberName
		,	tmp.CountCustWithoutTrans
		,	tmp.CountCustMissingTrans
		,	IFNULL(lts.TotalTrans,0) AS TotalTrans
    FROM Temp_MissingTransaction AS tmp
		LEFT JOIN DCS_DataTrace.LoginTransactionSummaryBySubscriber AS lts ON lts.TransDate = tmp.TransDate AND lts.SubscriberID = tmp.SubscriberID;
END$$
DELIMITER ;
