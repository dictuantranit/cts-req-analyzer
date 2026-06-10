/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Summary_MissingBetTransaction_GetPackage`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Summary_MissingBetTransaction_GetPackage`(
		IN ip_TransDate     DATE
	,	IN ip_BatchSize     INT
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231009@Jonathan.Doan
	Task : Get Package of MissingBetTransaction by batch
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20231009@Jonathan.Doan: Created [Redmine ID: 194933]
		- 20231101@Jonathan.Doan: HF Deadlock [Redmine ID: 195332]
		- 20231019@Jonathan.Doan: Get data from table LoginTransactionSummaryByAccount [Redmine ID: 195332]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataTrace.DCS_DT_Summary_MissingBetTransaction_GetPackage('2023-10-07', 10);
	*/    
    DECLARE lv_CurrentDatetime 	DATETIME 		DEFAULT CURRENT_TIMESTAMP();
	DECLARE lv_TotalRecord 		INT UNSIGNED 	DEFAULT 0;
	DECLARE lv_NoOfBatch 		INT UNSIGNED 	DEFAULT 0;
    
    IF EXISTS (SELECT 1 FROM DCS_DataTrace.BetTransactionSummary WHERE TransDate = ip_TransDate LIMIT 1) THEN
    
		DROP TEMPORARY TABLE IF EXISTS Temp_GroupByAccount; 
		DROP TEMPORARY TABLE IF EXISTS Temp_LoginTransactionSummaryByAccount; 
		
		CREATE TEMPORARY TABLE Temp_GroupByAccount(
				AccountID		INT UNSIGNED PRIMARY KEY
		);
		
		CREATE TEMPORARY TABLE Temp_LoginTransactionSummaryByAccount(
				ListAccountID	LONGTEXT
			,   BatchCount		INT
		);
		
		SET @RowId = 0;
		
        INSERT INTO Temp_GroupByAccount(AccountID)
        SELECT DISTINCT AccountID
        FROM DCS_DataTrace.LoginTransactionSummaryByAccount
        WHERE TransDate = ip_TransDate;
        
		SET lv_TotalRecord 	= (SELECT COUNT(1) FROM Temp_GroupByAccount);
		SET lv_NoOfBatch 	= CEIL(lv_TotalRecord/ip_BatchSize);
        
		INSERT INTO Temp_LoginTransactionSummaryByAccount (ListAccountID, BatchCount)
		SELECT  GROUP_CONCAT(DISTINCT tmp.AccountID) AS ListAccountID
			,   COUNT(1) AS BatchCount
		FROM (
			SELECT	@RowId := @RowId+1
				,   AccountID	
				,   CEIL(@RowId/ip_BatchSize) AS batchID
			FROM Temp_GroupByAccount
		) AS tmp
		GROUP BY tmp.batchID;
		
		SELECT ListAccountID
		FROM Temp_LoginTransactionSummaryByAccount;
    END IF;
END$$
DELIMITER ;
