DELIMITER $$

USE CTS_DataCenter$$

DROP PROCEDURE IF EXISTS CTS_DataCenter.zzzIssueLoginName_Step14_UpdSubID_CTSCust_mansion88_4428to102$$

CREATE PROCEDURE CTS_DataCenter.zzzIssueLoginName_Step14_UpdSubID_CTSCust_mansion88_4428to102()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong LoginName
	*/
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;  
  
    WHILE EXISTS (	SELECT	CTSCustID 
					FROM 	CTS_DataCenter.CTSCustomer
					WHERE	SubscriberID = 4428 LIMIT 1)
   DO
		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        
        UPDATE	CTS_DataCenter.CTSCustomer 
        SET		SubscriberID = 102
        WHERE	SubscriberID = 4428
        LIMIT 	10000;
        
       	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;  
        
	END WHILE;
	
END$$

DELIMITER ;