DELIMITER $$
DROP PROCEDURE IF EXISTS CTS_DataCenter.Issue_CTSCustomer_2_GetNewCTSCustomer$$

CREATE PROCEDURE CTS_DataCenter.Issue_CTSCustomer_2_GetNewCTSCustomer()
BEGIN
	/*
		Created:	20200421@CaseyHuynh	
		Task :		GET NewCTSCustID
		DB:			CTS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	DECLARE i INT;
    DECLARE n INT;
    DECLARE k INT;
    
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
    SELECT 	MIN(CTSCustID), MAX(CTSCustID)
    INTO	i, n
    FROM	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
    WHERE	 NewCTSCustID = -1;
    
	
	WHILE (i < n)
    DO
		SET k = (SELECT MAX(bt.CTSCustID) FROM ( SELECT ms.CTSCustID
										 FROM 	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
										 WHERE	ms.CTSCustID >= i AND ms.LoginName IS NOT NULL
										 LIMIT	5000
										) AS bt);
												
		UPDATE CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
		INNER JOIN	CTS_DataCenter.CTSCustomer As cus
					ON ms.LoginName = cus.UserName
		SET 		ms.NewCTSCustID = cus.CTSCustID
        WHERE		ms.CTSCustID BETWEEN i AND k
					AND  NewCTSCustID = -1;
		
        
        UPDATE CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
		INNER JOIN	CTS_DataCenter.CTSCustomer As cus
					ON ms.LoginNameWithPrefix = cus.UserName2
		SET 		ms.NewCTSCustID = cus.CTSCustID
        WHERE		ms.CTSCustID BETWEEN i AND k
					AND NewCTSCustID = -1;
        
		
		SET i = k;
    END WHILE;
	
	 
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END$$
DELIMITER ;