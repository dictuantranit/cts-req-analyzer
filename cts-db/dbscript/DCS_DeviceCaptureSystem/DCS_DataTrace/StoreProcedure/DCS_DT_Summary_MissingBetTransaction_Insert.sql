/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Summary_MissingBetTransaction_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Summary_MissingBetTransaction_Insert`(
        IN ip_TransDate    	 	DATE
	,	IN ip_ListAccountID   	LONGTEXT
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231009@Jonathan.Doan
	Task : Insert MissingBetTransaction by range ID
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20231009@Jonathan.Doan: Created [Redmine ID: 194933]
		- 20231101@Jonathan.Doan: HF Deadlock [Redmine ID: 195332]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataTrace.DCS_DT_Summary_MissingBetTransaction_Insert('2023-10-07', '1,2,3,4');
	*/
    DECLARE CONST_SUMMARY_MAXTRANSDATE 			INT 		DEFAULT 2;
    DECLARE CONST_MISSINGBETTRANSACTION_TYPE 	SMALLINT 	DEFAULT 2;
    
    DECLARE lv_CurrentDatetime 		DATETIME DEFAULT CURRENT_TIMESTAMP();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_ListAccountCust;
	DROP TEMPORARY TABLE IF EXISTS Temp_BetTransactionSummary;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_ListAccountCust;
	CREATE TEMPORARY TABLE Temp_ListAccountCust(
			AccountID				BIGINT UNSIGNED PRIMARY KEY
        , 	SubscriberID			INT UNSIGNED DEFAULT 0
		, 	CustID					INT UNSIGNED DEFAULT NULL
        
		,	INDEX `IX_Temp_ListAccountCust_CustID` (`CustID`)
		,	INDEX `IX_Temp_ListAccountCust_SubscriberID_CustID` (`SubscriberID`, `CustID`)
	);
    
	CREATE TEMPORARY TABLE Temp_BetTransactionSummary(
			ID 						BIGINT UNSIGNED NOT NULL AUTO_INCREMENT
		, 	CustID					INT UNSIGNED DEFAULT NULL
		, 	SubscriberID			INT UNSIGNED DEFAULT 0
		,	PRIMARY KEY (`ID`)
		,	INDEX `IX_Temp_BetTransactionSummary_CustID` (`CustID`)
	);
    
    SET @sql = CONCAT("INSERT INTO Temp_ListAccountCust (AccountID) VALUES ('", REPLACE(ip_ListAccountID, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    UPDATE Temp_ListAccountCust AS tmp
		INNER JOIN CTS_DataCenter.CustDCSAccount AS dcs ON dcs.AccountID = tmp.AccountID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cts ON cts.CTSCustID = dcs.CTSCustID
    SET tmp.SubscriberID = dcs.SubscriberID,
		tmp.CustID = cts.CustID
	WHERE cts.RoleID = 1;
    
    INSERT INTO Temp_BetTransactionSummary(SubscriberID, CustID)
    SELECT 	DISTINCT
			cts.SubscriberID
		,	bt.CustID
    FROM DCS_DataTrace.BetTransactionSummary AS bt
		INNER JOIN CTS_DataCenter.CTSCustomer AS cts ON cts.CustID = bt.CustID
    WHERE bt.TransDate = ip_TransDate;
    
    /* == MissingTransaction == */
    DELETE FROM Temp_ListAccountCust WHERE CustID IS NULL;
    
    DELETE tmp_lac
    FROM Temp_ListAccountCust AS tmp_lac
		INNER JOIN Temp_BetTransactionSummary AS tmp_bt ON tmp_bt.CustID = tmp_lac.CustID;
        
    DELETE tmp_lac
    FROM Temp_ListAccountCust AS tmp_lac
		INNER JOIN DCS_DataTrace.MemberMissingTransaction AS mt ON mt.TransDate = ip_TransDate 
														AND mt.SubscriberID = tmp_lac.SubscriberID 
                                                        AND mt.MissingTransactionType = CONST_MISSINGBETTRANSACTION_TYPE
														AND mt.CustID = tmp_lac.CustID;
    
    INSERT IGNORE INTO DCS_DataTrace.MemberMissingTransaction(MissingTransactionType, TransDate, SubscriberID, CustID, CreatedTime)
    SELECT 	CONST_MISSINGBETTRANSACTION_TYPE AS MissingTransactionType
		,	ip_TransDate AS TransDate
		,	SubscriberID
		,	CustID
        ,	lv_CurrentDatetime AS CreatedTime
    FROM Temp_ListAccountCust;
    
END$$
DELIMITER ;
