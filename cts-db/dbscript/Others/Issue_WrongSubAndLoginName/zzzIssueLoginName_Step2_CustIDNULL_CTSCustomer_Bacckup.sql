DELIMITER $$

USE CTS_DataCenter$$

DROP PROCEDURE IF EXISTS CTS_DataCenter.zzzIssueLoginName_Step2_CustIDNULL_CTSCustomer_Bacckup$$

CREATE PROCEDURE CTS_DataCenter.zzzIssueLoginName_Step2_CustIDNULL_CTSCustomer_Bacckup()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong LoginName
	*/
    
	DECLARE vr_MaxID BIGINT;
	DECLARE vr_LoopID BIGINT;
 
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;  
	SET vr_MaxID = (SELECT	MAX(CTSCustID)
					FROM 	CTS_DataCenter.CTSCustomer
					WHERE	CustID IS NULL AND SubscriberID NOT IN (2367,2328)); 
                    
   SET vr_LoopID = (SELECT	IFNULL(MAX(CTSCustID),0) FROM CTS_DataCenter.zzzIssueLoginName_CTSCustomer); 
   WHILE (vr_LoopID < vr_MaxID)  
   DO

        INSERT INTO CTS_DataCenter.zzzIssueLoginName_CTSCustomer
        SELECT 	*
        FROM	CTS_DataCenter.CTSCustomer 
        WHERE	CustID IS NULL AND SubscriberID NOT IN (2367,2328)
				AND CTSCustID > vr_LoopID
        LIMIT 	5000;
        
        SET vr_LoopID = (SELECT	MAX(CTSCustID) FROM CTS_DataCenter.zzzIssueLoginName_CTSCustomer);
	END WHILE;
    
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END$$

DELIMITER ;