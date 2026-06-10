DELIMITER $$
CREATE DEFINER=`fps`@`%` PROCEDURE `zzzFixIssue_131578_CreatedDate_LastLoginTime_Processing_Customer`(IN ip_size INT, IN ip_MaxAccountId BIGINT)
BEGIN
	DECLARE v_maxId   BIGINT UNSIGNED default 1;
    DECLARE v_minId   BIGINT UNSIGNED default 0;
	DECLARE v_take INT;
    
    SET v_take = ip_size;
    SET v_maxId = ip_MaxAccountId;
    
    CREATE TABLE IF NOT EXISTS DCS_DataCenter.zzzTransaction_temp_AccountId (
		  Id INT NOT NULL AUTO_INCREMENT,  
 		  FromAccountId BIGINT, 
          ToAccountId BIGINT,
          Status BOOLEAN,  
          MaxAccountId BIGINT,
		  PRIMARY KEY  (Id),
          INDEX RangeIndex(FromAccountId, ToAccountId)
		);
    
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ ;
    
    WHILE v_maxId is not null && v_maxId != 0 DO    
		SELECT Min(a.AccountID), Max(a.AccountID) INTO v_minId, v_maxId 
			FROM (SELECT AccountID FROM DCS_DataCenter.Account WHERE AccountID > v_maxId order by accountid LIMIT v_take) as a;
            
		IF v_minId is not null && v_maxId is not null THEN
			INSERT INTO DCS_DataCenter.zzzTransaction_temp_AccountId(FromAccountId, ToAccountId, Status, MaxAccountId)
					VALUE(v_minId, v_maxId, false, v_maxId); 
                    
			UPDATE CTS_DataCenter.CTSCustomer cus 
            JOIN (
				SELECT acc.LastLoginTime as LastLoginTime, cusacc.CTSCustID as CTSCustId  FROM DCS_DataCenter.Account as acc 
					INNER JOIN CTS_DataCenter.CustDCSAccount cusacc ON acc.AccountID = cusacc.AccountID
				WHERE acc.AccountID BETWEEN v_minId AND v_maxId) tmpAcc
			ON cus.CTSCustID = tmpAcc.CTSCustId
            SET cus.LastLoginTime = CASE WHEN tmpAcc.LastLoginTime > cus.LastLoginTime THEN tmpAcc.LastLoginTime
                        ELSE cus.LastLoginTime
						END;
            
           UPDATE DCS_DataCenter.zzzTransaction_temp_AccountId SET status = true WHERE FromAccountId = v_minId and ToAccountId = v_maxId;
        END IF;
    END WHILE;
END$$
DELIMITER ;
