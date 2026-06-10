DELIMITER $$
CREATE DEFINER=`fps`@`%` PROCEDURE `zzzFixIssue_131578_CreatedDate_LastLoginTime_Processing`(IN ip_fromTransId BIGINT, IN ip_toTransId BIGINT, IN ip_isBK BOOLEAN)
BEGIN
	DECLARE v_maxId   BIGINT UNSIGNED default 1;
    DECLARE v_minId   BIGINT UNSIGNED default 0;
    DECLARE v_isBK BOOLEAN;       
    
    SET v_minId = ip_fromTransId;
    SET v_maxId = ip_toTransId;
    SET v_isBK = ip_isBK;
    
   SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ ;
   
   IF v_isBK THEN
			UPDATE DCS_DataCenter.Transaction_BK01 
				SET CreatedDate = DATE(TransTime) 
			WHERE (TransId BETWEEN v_minId AND v_maxId) AND CreatedDate != DATE(TransTime);
            
            UPDATE DCS_DataCenter.Account acc 
				JOIN (
					SELECT trans.AccountId, trans.SubscriberID, MAX(trans.TransTime) AS maxTransTime
						FROM DCS_DataCenter.Transaction_BK01 trans 
                        WHERE trans.TransId BETWEEN v_minId AND v_maxId
                        GROUP BY trans.AccountId, trans.SubscriberID) trans2
				ON acc.AccountID = trans2.AccountID
				SET 
						acc.LastLoginTime = 
                        CASE WHEN acc.LastLoginTime < trans2.maxTransTime THEN trans2.maxTransTime
                        ELSE acc.LastLoginTime
						END,
				acc.CreatedDate = DATE(acc.CreatedTime);
            
            UPDATE zzzTransaction_temp_planingByTransId 
				SET Status = true 
			WHERE FromTransId = v_minId AND ToTransId = v_maxId AND IsBK = true;
           
      ELSE
			UPDATE DCS_DataCenter.Transaction07 
				SET CreatedDate = DATE(TransTime) 
			WHERE (TransId BETWEEN v_minId AND v_maxId) AND CreatedDate != DATE(TransTime);
            
             UPDATE DCS_DataCenter.Account acc 
				JOIN (
					SELECT trans.AccountId, trans.SubscriberID, MAX(trans.TransTime) AS maxTransTime
						FROM DCS_DataCenter.Transaction07 trans 
                        WHERE trans.TransId BETWEEN v_minId AND v_maxId
                        GROUP BY trans.AccountId, trans.SubscriberID) trans2
				ON acc.AccountID = trans2.AccountID
				SET 
						acc.LastLoginTime = 
                        CASE WHEN acc.LastLoginTime < trans2.maxTransTime THEN trans2.maxTransTime
                        ELSE acc.LastLoginTime
						END,
				acc.CreatedDate = DATE(acc.CreatedTime);               
            
            UPDATE zzzTransaction_temp_planingByTransId 
				SET status = true 
			WHERE FromTransId = v_minId AND ToTransId = v_maxId AND IsBK = false;
      END IF;   
END$$
DELIMITER ;
