DELIMITER $$

USE CTS_DataCenter$$

DROP PROCEDURE IF EXISTS CTS_DataCenter.zzzIssueLoginName_Step12_UpdSubID_CTSCust_asiabet88_4427to105$$

CREATE PROCEDURE CTS_DataCenter.zzzIssueLoginName_Step12_UpdSubID_CTSCust_asiabet88_4427to105()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong LoginName
	*/
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;  
  
   WHILE EXISTS (	SELECT	CTSCustID 
					FROM 	CTS_DataCenter.CTSCustomer
					WHERE	SubscriberID = 4427 LIMIT 1)
   DO
		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        
        UPDATE	CTS_DataCenter.CTSCustomer 
        SET		SubscriberID = 105
        WHERE	SubscriberID = 4427
        LIMIT 	10000;
        
       	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;  
        
	END WHILE;
    
	
END$$

DELIMITER ;