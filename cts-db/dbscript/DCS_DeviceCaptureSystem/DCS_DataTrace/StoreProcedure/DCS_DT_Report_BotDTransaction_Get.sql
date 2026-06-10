/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Report_BotDTransaction_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Report_BotDTransaction_Get`(
		IN ip_FromDate 	DATE
    ,	IN ip_ToDate 	DATE
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231017@Jonathan.Doan
	Task : Get report BotDTransaction
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20231017@Jonathan.Doan: Created [Redmine ID: 195332]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataTrace.DCS_DT_Report_BotDTransaction_Get('2023-10-01', '2023-10-06');
	*/
    
	DROP TEMPORARY TABLE IF EXISTS Temp_LoginTrans;
    
	CREATE TEMPORARY TABLE Temp_LoginTrans(
			ID					BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY
		, 	TransDate			DATETIME NOT NULL
		, 	SubscriberID		INT UNSIGNED DEFAULT NULL
		, 	SubscriberName		VARCHAR(50) DEFAULT NULL
		, 	FlaggedGroupID		SMALLINT DEFAULT NULL
		, 	FlaggedGroupName	VARCHAR(200) DEFAULT NULL
		, 	TotalTrans			INT UNSIGNED DEFAULT NULL
		,	KEY `IX_Temp_LoginTrans_FlaggedGroupID` (`FlaggedGroupID`)
	);
    
    INSERT INTO Temp_LoginTrans(TransDate, SubscriberID, SubscriberName, FlaggedGroupID, TotalTrans)
	SELECT 	trans.TransDate
		,	trans.SubscriberID
		,	sub.SubscriberName
		,	trans.FlaggedGroupID
		,	SUM(trans.TotalTrans) AS TotalTrans
	FROM DCS_DataTrace.LoginTransactionSummary AS trans
		INNER JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = trans.SubscriberID
	WHERE trans.TransDate BETWEEN ip_FromDate AND ip_ToDate
	GROUP BY trans.TransDate, trans.SubscriberID, trans.FlaggedGroupID;
    
    UPDATE Temp_LoginTrans AS tmp
		INNER JOIN DCS_DataCenter.StaticList AS sl ON sl.ListID = 1 AND sl.GroupID = tmp.FlaggedGroupID
	SET tmp.FlaggedGroupName = sl.GroupName;
    
    SELECT 	TransDate
		,	SubscriberID
        ,	SubscriberName
        ,	FlaggedGroupName AS Flagged
        ,	TotalTrans
	FROM Temp_LoginTrans;
    
END$$
DELIMITER ;
