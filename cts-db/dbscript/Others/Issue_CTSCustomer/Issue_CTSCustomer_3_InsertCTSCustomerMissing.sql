DELIMITER $$
#DROP PROCEDURE IF EXISTS CTS_DataCenter.Issue_CTSCustomer_3_InsertCTSCustomerMissing$$

CREATE PROCEDURE CTS_Adhoc.Issue_CTSCustomer_3_InsertCTSCustomerMissing_V3(IN ip_Batch INT)
BEGIN
	/*
		Created:	20200421@CaseyHuynh	
		Task :		Insert Missint CTSCustomer 
		DB:			CTS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	DECLARE i INT;
    DECLARE n INT;
    DECLARE k INT;
    
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
    SELECT 	MIN(CTSCustID), MAX(CTSCustID)
    INTO	i, n
    FROM	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
    WHERE	ms.SubscriberType IN (1,2);
    
	
	WHILE (i < n)
    DO
		SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
		SET k = (SELECT MAX(bt.CTSCustID) FROM ( SELECT ms.CTSCustID
										 FROM 	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
										 WHERE	NewCTSCustID = -1 AND ms.SubscriberType IN (1,2) AND ms.CTSCustID >= i
										 LIMIT	ip_Batch
										) AS bt);
												
		INSERT IGNORE INTO	CTS_DataCenter.CTSCustomer(CTSCustID, SubscriberID, UserName, UserName2, LastLoginTime)
		SELECT	ms.CTSCustID
				, ms.SubscriberID
				, ms.LoginName AS UserName
				, ms.LoginNameWithPrefix
				, MAX(ac.LastLoginTime)
		FROM 		CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
		INNER JOIN	DCS_DataCenter.Account AS ac
					ON ms.AccountID = ac.AccountID
		WHERE		ms.SubscriberType IN (1,2)
					AND NewCTSCustID = -1
                    AND ms.CTSCustID BETWEEN i AND k
		GROUP BY 	ms.CTSCustID
					, ms.SubscriberID
					, ms.LoginNameWithPrefix
					, ms.LoginName; 		
		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
		SET i = k + 1;
    END WHILE;
	
	 
	
END$$
DELIMITER ;