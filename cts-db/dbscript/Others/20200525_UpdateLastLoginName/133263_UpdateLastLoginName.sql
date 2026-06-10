DELIMITER $$

USE CTS_DataCenter$$

DROP PROCEDURE IF EXISTS CTS_Adhoc.UpdateLastLoginTime$$

CREATE PROCEDURE CTS_Adhoc.UpdateLastLoginTime()
BEGIN
	/*
		Created:	20200526@CaseyHuynh
		Task :		133263-Update Last Login Time
		DB:			
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
    DECLARE vrloopAccountID BIGINT UNSIGNED;
    DECLARE vrMaxAccountID BIGINT UNSIGNED;
    
    
     CREATE TABLE IF NOT EXISTS CTS_Adhoc.cs133263_LastLoginNameProcessing
    (
		loopAccountID	BIGINT UNSIGNED
        , minAccountID	BIGINT UNSIGNED
        , maxAccountID	BIGINT UNSIGNED
    );
    
    TRUNCATE TABLE CTS_Adhoc.cs133263_LastLoginNameProcessing;	
    
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 	  
    
    SELECT 	Min(AccountID), Max(AccountID)
    INTO 	vrLoopAccountID, vrMaxAccountID
    FROM	CTS_DataCenter.CustDCSAccount;
	
    INSERT INTO CTS_Adhoc.cs133263_LastLoginNameProcessing(loopAccountID, minAccountID, maxAccountID) 
    SELECT 	vrLoopAccountID -1 , vrLoopAccountID, vrMaxAccountID;

    DROP TEMPORARY TABLE IF EXISTS Temp_Account;
    CREATE TEMPORARY TABLE Temp_Account
	(
		CTSCustID 		BIGINT UNSIGNED
        , AccountID 		BIGINT UNSIGNED
		, LastLoginTime TIMESTAMP(4)
	);
	
    
    
    WHILE ( vrLoopAccountID < vrMaxAccountID)
    DO
		TRUNCATE TABLE Temp_Account;    
        
		SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;         
        INSERT INTO Temp_Account(CTSCustID, AccountID, LastLoginTime)
        SELECT  	cts.CTSCustID
					, cts.AccountID
					, acc.LastLoginTime
        FROM		CTS_DataCenter.CustDCSAccount AS cts
        INNER JOIN	DCS_DataCenter.Account AS acc
					ON cts.AccountID = acc.AccountID
		WHERE		cts.AccountID >= vrLoopAccountID
        LIMIT		5000;
        
        UPDATE 		CTS_DataCenter.CTSCustomer AS cus
        INNER JOIN	Temp_Account AS tmp_acc
					ON cus.CTSCustID = tmp_acc.CTSCustID
        SET			cus.LastLoginTime =  tmp_acc.LastLoginTime
        WHERE		cus.LastLoginTime < tmp_acc.LastLoginTime
					OR cus.LastLoginTime IS NULL;
        
        
        UPDATE CTS_Adhoc.cs133263_LastLoginNameProcessing
        SET loopAccountID = (SELECT IFNULL(MAX(AccountID),vrMaxAccountID+100000) FROM Temp_Account);
        
        SET vrLoopAccountID = (SELECT  loopAccountID  FROM  CTS_Adhoc.cs133263_LastLoginNameProcessing);
        
    END WHILE;
    
END$$

DELIMITER ;