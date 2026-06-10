DELIMITER $$

USE CTS_DataCenter$$

DROP PROCEDURE IF EXISTS CTS_DataCenter.zzzIssueLoginName_Step6_CustIDNULL_CustDCSAccount_Backup$$

CREATE PROCEDURE CTS_DataCenter.zzzIssueLoginName_Step6_CustIDNULL_CustDCSAccount_Backup()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong LoginName
	*/
    
	DECLARE vr_MaxID BIGINT;
    
	DECLARE vr_FromID BIGINT;
    DECLARE vr_ToID BIGINT;
 
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;  
	
    SELECT	MIN(zz.CTSCustID), MAX(zz.CTSCustID)
    INTO 	vr_FromID, vr_MaxID
	FROM 	CTS_DataCenter.zzzIssueLoginName_CTSCustomer AS zz;
    #INNER JOIN 	CTS_DataCenter.CustDCSAccount AS ct
	#			ON ct.CTSCustID = zz.CTSCustID;
    

   WHILE (vr_FromID < vr_MaxID)  
   DO
		SET vr_ToID = (	SELECT MAX(tmp.CTSCustID) 
							FROM (SELECT CTSCustID FROM CTS_DataCenter.zzzIssueLoginName_CTSCustomer WHERE CTSCustID >= vr_FromID LIMIT 10000) AS tmp);
                            
		INSERT INTO CTS_DataCenter.zzzIssueLoginName_CustDCSAccount
        SELECT 		ct.*
        FROM 		CTS_DataCenter.CustDCSAccount 					AS ct
        INNER JOIN	CTS_DataCenter.zzzIssueLoginName_CTSCustomer	AS zz
					ON ct.CTSCustID = zz.CTSCustID
        WHERE		ct.CTSCustID BETWEEN vr_FromID AND vr_ToID;
        
        SET vr_FromID = vr_ToID + 1 ;
        
	END WHILE;
    
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END$$

DELIMITER ;