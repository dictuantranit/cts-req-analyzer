/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_Account_UpdateLastLoginTime`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_Account_UpdateLastLoginTime`(
		IN ip_BatchSize 	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20231205@Long.Luu
		Task:		Fix deadlock issue [Redmine ID: #000000]
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20231205@Long.Luu: 		Created
			- 20240521@Victoria.Le: 	Edit SP [Redmine ID: #205345]
			
		Param's Explanation (filtered by):
        
        Example:
			CALL DCS_DC_Transform_Account_UpdateLastLoginTime(5000);
	*/ 
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN 
        GET DIAGNOSTICS CONDITION 1 @errCode = RETURNED_SQLSTATE, @errMsg = MESSAGE_TEXT;
        INSERT INTO CTS_DataCenter.Adhoc_StoredProcedureExecError(StoredProcedureName, ErrCode, ErrMsg, ErrDate, ErrDateTime)
        SELECT 'DCS_DC_Transform_Account_UpdateLastLoginTime', @errCode, @errMsg, NOW(), NOW();
        
		UPDATE CTS_DataCenter.SystemEventStatus 
		SET 	Status = 'Stop' 
			,  	LastExecTime = NOW()
		WHERE EventName = 'EV_DCS_DataCenter_Account_UpdateLastLoginTime' ;
    END;
    
	SET ip_BatchSize = 3000;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AccountLastLogin;  
	CREATE TEMPORARY TABLE Temp_AccountLastLogin(
			ID				BIGINT UNSIGNED
		,	AccountID 		BIGINT UNSIGNED PRIMARY KEY
		,	LastLoginTime 	TIMESTAMP(4) NOT NULL
    );
    
    INSERT INTO Temp_AccountLastLogin(ID, AccountID, LastLoginTime)
    SELECT 	MAX(main.ID)
		,	main.AccountID
		,	MAX(main.LastLoginTime)
	FROM DCS_DataCenter.AccountLastLoginTimeProcess AS main
		INNER JOIN (
						SELECT DISTINCT tll.AccountID, tll.ID
						FROM DCS_DataCenter.AccountLastLoginTimeProcess AS tll
							INNER JOIN DCS_DataCenter.Account AS acc ON acc.AccountID = tll.AccountID
						ORDER BY tll.ID ASC
						LIMIT ip_BatchSize 
						FOR UPDATE OF acc SKIP LOCKED
					) AS sub ON sub.AccountID = main.AccountID
	GROUP BY main.AccountID;
    
    UPDATE DCS_DataCenter.Account AS acc
        INNER JOIN	Temp_AccountLastLogin AS tll ON acc.AccountID = tll.AccountID
	SET	 acc.LastLoginTime = tll.LastLoginTime; 
    
    DELETE acc
	FROM DCS_DataCenter.AccountLastLoginTimeProcess AS acc
		INNER JOIN Temp_AccountLastLogin AS t ON acc.AccountID = t.AccountID
    WHERE acc.ID <= t.ID;
    
    ###########################################################
	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerLastLogin;  
	CREATE TEMPORARY TABLE Temp_CTSCustomerLastLogin(
			ID 				BIGINT UNSIGNED
		,	CTSCustID 		BIGINT UNSIGNED PRIMARY KEY
		,	LastLoginTime 	TIMESTAMP(4) NOT NULL
        ,	IsValid			BIT DEFAULT 1
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustInvalid;  
	CREATE TEMPORARY TABLE Temp_CTSCustInvalid(
			CTSCustID 		BIGINT UNSIGNED PRIMARY KEY
	);
    
    INSERT INTO Temp_CTSCustomerLastLogin(ID, CTSCustID, LastLoginTime)
    SELECT 	MAX(main.ID)
		,	main.CTSCustID
		,	MAX(main.LastLoginTime)
	FROM DCS_DataCenter.CTSCustomerLastLoginTimeProcess AS main
		INNER JOIN (
						SELECT DISTINCT tll.CTSCustID, tll.ID
						FROM DCS_DataCenter.CTSCustomerLastLoginTimeProcess AS tll
							LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tll.CTSCustID
						ORDER BY tll.ID ASC
						LIMIT ip_BatchSize
						FOR UPDATE OF cus SKIP LOCKED 
					) AS sub ON sub.CTSCustID = main.CTSCustID
	GROUP BY main.CTSCustID;
    
    INSERT IGNORE INTO Temp_CTSCustInvalid(CTSCustID)
    SELECT cus.CTSCustID
    FROM CTS_DataCenter.CTSCustomer AS cus
		INNER JOIN 	Temp_CTSCustomerLastLogin AS tmp_cus ON cus.CTSCustID = tmp_cus.CTSCustID
	WHERE cus.LastLoginTime > tmp_cus.LastLoginTime;
    
    UPDATE Temp_CTSCustomerLastLogin AS cus
		INNER JOIN Temp_CTSCustInvalid AS ci ON ci.CTSCustID = cus.CTSCustID
    SET cus.IsValid = 0
	;
	
	UPDATE CTS_DataCenter.CTSCustomer  cus
		INNER JOIN 	Temp_CTSCustomerLastLogin AS tmp_cus ON cus.CTSCustID = tmp_cus.CTSCustID AND tmp_cus.IsValid = 1
	SET cus.LastLoginTime = tmp_cus.LastLoginTime;
     
	DELETE acc
	FROM DCS_DataCenter.CTSCustomerLastLoginTimeProcess AS acc
		INNER JOIN Temp_CTSCustomerLastLogin AS t ON acc.CTSCustID = t.CTSCustID
    WHERE acc.ID <= t.ID;
    /*
	SET ip_BatchSize = 5000;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AccountLastLoginTimeProcess;  
	CREATE TEMPORARY TABLE Temp_AccountLastLoginTimeProcess(
			ID 				BIGINT UNSIGNED
		,	AccountID 		BIGINT UNSIGNED
		,	LastLoginTime 	TIMESTAMP(4) NOT NULL
		,	PRIMARY KEY (ID)     
        ,	INDEX 			IX_Temp_AccountLastLoginTimeProcess_AccountID(AccountID)
    );
    
    INSERT INTO Temp_AccountLastLoginTimeProcess(ID, AccountID, LastLoginTime)
    SELECT 	acc.ID
		,	acc.AccountID
        ,	acc.LastLoginTime
    FROM DCS_DataCenter.AccountLastLoginTimeProcess AS acc
    ORDER BY acc.ID ASC
    LIMIT ip_BatchSize;
    
    UPDATE DCS_DataCenter.Account 	AS acc
        INNER JOIN	Temp_AccountLastLoginTimeProcess AS tll ON acc.AccountID = tll.AccountID
	SET	 acc.LastLoginTime = tll.LastLoginTime; 
    
    DELETE FROM DCS_DataCenter.AccountLastLoginTimeProcess AS acc
    WHERE acc.ID IN (SELECT ID FROM Temp_AccountLastLoginTimeProcess);
    
    ###########################################################
	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerLastLoginTimeProcess;  
	CREATE TEMPORARY TABLE Temp_CTSCustomerLastLoginTimeProcess(
			ID 				BIGINT UNSIGNED
		,	CTSCustID 		BIGINT UNSIGNED
		,	LastLoginTime 	TIMESTAMP(4) NOT NULL
        ,	IsValid			BIT DEFAULT 1
		,	PRIMARY KEY (ID)     
        ,	INDEX 			IX_Temp_CTSCustomerLastLoginTimeProcess_CTSCustID(CTSCustID)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustInvalid;  
	CREATE TEMPORARY TABLE Temp_CTSCustInvalid(
			CTSCustID 		BIGINT UNSIGNED
        ,	INDEX 			IX_Temp_CTSCustInvalid_CTSCustID(CTSCustID)
    );
    
    INSERT INTO Temp_CTSCustomerLastLoginTimeProcess(ID, CTSCustID, LastLoginTime)
    SELECT 	cus.ID
		,	cus.CTSCustID
        ,	cus.LastLoginTime
    FROM DCS_DataCenter.CTSCustomerLastLoginTimeProcess AS cus
    ORDER BY cus.ID ASC
    LIMIT ip_BatchSize;
    
    INSERT INTO Temp_CTSCustInvalid(CTSCustID)
    SELECT cus.CTSCustID
    FROM CTS_DataCenter.CTSCustomer  cus
		INNER JOIN 	Temp_CTSCustomerLastLoginTimeProcess AS tmp_cus ON cus.CTSCustID = tmp_cus.CTSCustID
	WHERE cus.LastLoginTime > tmp_cus.LastLoginTime;
    
    UPDATE Temp_CTSCustomerLastLoginTimeProcess AS cust
    SET cust.IsValid = 0
    WHERE cust.CTSCustID IN (SELECT CTSCustID FROM Temp_CTSCustInvalid);
	
     UPDATE CTS_DataCenter.CTSCustomer  cus
        INNER JOIN 	Temp_CTSCustomerLastLoginTimeProcess AS tmp_cus ON cus.CTSCustID = tmp_cus.CTSCustID AND tmp_cus.IsValid = 1
	 SET cus.LastLoginTime = tmp_cus.LastLoginTime;
     
	DELETE FROM DCS_DataCenter.CTSCustomerLastLoginTimeProcess AS cust
    WHERE cust.ID IN (SELECT ID FROM Temp_CTSCustomerLastLoginTimeProcess);
*/

END$$
DELIMITER ;
