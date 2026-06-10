DELIMITER $$
CREATE DEFINER=`fps`@`%` PROCEDURE `DCS_ST_ArchiveProcessedTransaction`(IN ip_NumOfDays int)
BEGIN
	/*
		Created: 20200408@Terry.Nguyen
		Task : Archive processed raw transaction
		DB: ProcessedTransaction
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
    
	DECLARE v_fromDate DATETIME;
    DECLARE v_executedDate DATETIME;
	DECLARE v_createdDate DATETIME;
    DECLARE v_queryDate DATETIME;
    DECLARE v_bkTotalDay INT;
    DECLARE v_maxId INT UNSIGNED default 1;
    DECLARE v_maxTransId BIGINT UNSIGNED default 1;
    DECLARE v_minTransId BIGINT UNSIGNED default 0;
    
    SET v_fromDate = DATE_SUB(current_date(), INTERVAL ip_NumOfDays DAY);
    SET v_executedDate = NOW();
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Schedule;
	CREATE TEMPORARY TABLE Temp_Schedule
    (
		Id INTEGER NOT NULL AUTO_INCREMENT PRIMARY KEY,
		CreatedDate DATETIME,  
        Status boolean default false,
		INDEX (CreatedDate)
    );  
    
    INSERT 
		INTO DCS_RawTransaction.ArchiveTransactionLog(ExecutedDate,IsCompleted, StartTime, EndTime)
		VALUES(v_executedDate, false, NOW(), NOW());
        
    INSERT INTO Temp_Schedule(CreatedDate)
    SELECT DISTINCT CreatedDate FROM DCS_RawTransaction.ProcessedTransaction WHERE DATE(CreatedDate) < v_fromDate;
    
    CREATE TABLE IF NOT EXISTS DCS_RawTransaction.ProcessedTransaction_BK LIKE DCS_RawTransaction.ProcessedTransaction;    
    SELECT MAX(CreatedDate) INTO v_createdDate FROM DCS_RawTransaction.ProcessedTransaction_BK;    
    SET v_bkTotalDay = DATEDIFF(Current_DATE(), DATE(v_createdDate));
    IF v_bkTotalDay >= 2 THEN
		TRUNCATE TABLE DCS_RawTransaction.ProcessedTransaction_BK;
    END IF;
    
    #====================== 
    WHILE v_maxId is not null && v_maxId != 0 DO 
		SELECT MAX(id) into v_maxId FROM Temp_Schedule WHERE Status = false;
        SELECT CreatedDate INTO v_queryDate FROM Temp_Schedule WHERE Id = v_maxId;
        
         WHILE v_maxTransId is not null && v_maxTransId != 0 DO
			SELECT MAX(a.TransId), MIN(a.TransId) INTO v_maxTransId, v_minTransId FROM 
            (SELECT TransId FROM DCS_RawTransaction.ProcessedTransaction WHERE CreatedDate = DATE(v_queryDate) ORDER BY TransId LIMIT 1000) a;
            
             INSERT INTO DCS_RawTransaction.ProcessedTransaction_BK
				SELECT * FROM DCS_RawTransaction.ProcessedTransaction 
				WHERE TransId BETWEEN v_minTransId AND v_maxTransId;
             
             DELETE 
					FROM DCS_RawTransaction.ProcessedTransaction 
			 WHERE  TransId BETWEEN v_minTransId AND v_maxTransId;            
             
         END WHILE;
        
    END WHILE;  
	#======================    
    
    UPDATE DCS_RawTransaction.ArchiveTransactionLog 
		SET IsCompleted = true,
			EndTime = NOW()
	WHERE ExecutedDate = v_executedDate;       
END$$
DELIMITER ;
