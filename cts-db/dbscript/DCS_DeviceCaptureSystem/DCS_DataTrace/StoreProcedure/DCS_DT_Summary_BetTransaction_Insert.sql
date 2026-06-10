/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Summary_BetTransaction_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Summary_BetTransaction_Insert`(
    IN ip_BetTransactionJson LONGTEXT
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231003@Jonathan.Doan
	Task : Insert data into BetTransactionSummary
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20231003@Jonathan.Doan: Created [Redmine ID: 194933]
		- 20231026@Jonathan.Doan: Refactor code [Redmine ID: 195332]
		
	Param's Explanation (filtered by):

	Example:
		SET sql_safe_updates = 0;
        CALL DCS_DataTrace.DCS_DT_Summary_BetTransaction_Insert('[{"TransDate":"2023-10-04","CustID":1,"BetCount":100,"FirstBetTransactionTime":"2023-10-04 05:04:00","LastBetTransactionTime":"2023-10-04 10:05:00"}]');
	*/
    
    DECLARE lv_CurrentDatetime DATETIME DEFAULT CURRENT_TIMESTAMP();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_InputTrans;
	#======GET DATA FROM RAW TRANSACTION===========================
	CREATE TEMPORARY TABLE Temp_InputTrans(
			ID 							BIGINT UNSIGNED NOT NULL AUTO_INCREMENT
		, 	TransDate					DATETIME NOT NULL
		, 	CustID						INT UNSIGNED DEFAULT NULL
		, 	BetCount					INT UNSIGNED DEFAULT 0
		, 	FirstBetTransactionTime		DATETIME DEFAULT NULL
		, 	LastBetTransactionTime		DATETIME DEFAULT NULL
		, 	IsUpdate					BOOL DEFAULT 0
		,	PRIMARY KEY (`ID`)
	);
	
    INSERT INTO Temp_InputTrans(TransDate, CustID, BetCount, FirstBetTransactionTime, LastBetTransactionTime)
	SELECT	tmp.TransDate
		,	tmp.CustID
		,	tmp.BetCount
		,	tmp.FirstBetTransactionTime
		,	tmp.LastBetTransactionTime
	FROM JSON_TABLE(
			ip_BetTransactionJson,
			 "$[*]" COLUMNS(
					TransDate					DATETIME			PATH "$.TransDate"
				,	CustID						INT UNSIGNED		PATH "$.CustID"
				,	BetCount					INT UNSIGNED		PATH "$.BetCount"
				,	FirstBetTransactionTime		DATETIME			PATH "$.FirstBetTransactionTime"
				,	LastBetTransactionTime		DATETIME			PATH "$.LastBetTransactionTime"
			)
		) AS tmp;

	
    DELETE tmp
    FROM Temp_InputTrans AS tmp
		INNER JOIN DCS_DataTrace.BetTransactionSummary AS bt ON bt.TransDate = tmp.TransDate AND bt.CustID = tmp.CustID;
    
	INSERT IGNORE INTO DCS_DataTrace.BetTransactionSummary(TransDate, CustID, BetCount, FirstBetTransactionTime, LastBetTransactionTime, CreatedTime)
	SELECT 	tmp.TransDate
		,	tmp.CustID
        ,	tmp.BetCount
        ,	tmp.FirstBetTransactionTime
        ,	tmp.LastBetTransactionTime
        ,	lv_CurrentDatetime AS CreatedTime
    FROM Temp_InputTrans AS tmp;
END$$
DELIMITER ;
