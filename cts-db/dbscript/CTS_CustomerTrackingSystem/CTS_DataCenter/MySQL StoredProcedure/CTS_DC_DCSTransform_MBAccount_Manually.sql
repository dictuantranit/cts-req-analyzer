/*<info serverAlias="CTSMain-CTS_Adhoc" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_DCSTransform_MBAccount_Manually`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_DCSTransform_MBAccount_Manually`(
		IN ip_BatchSize INT
)
  SQL SECURITY INVOKER
BEGIN
/*
	Created:	20250409@Casey.Huynh
		Task:		Transform MBAccount to CTS
		DB:			CTS_DataCenter
		Original:

		Revisions:
      - 20250409@Casey.Huynh: Created [Redmined: #221973]

		Param's Explanation (filtered by):
        
	*/  
	DECLARE CONST_SYSTEMPARAM_LASTACCOUNTID INT DEFAULT 190;
    
    DECLARE lv_LastAccountID	BIGINT UNSIGNED;
	DECLARE lv_MaxAccountID		BIGINT UNSIGNED;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MBAccount;
	CREATE TEMPORARY TABLE Temp_MBAccount (	
			MBAccountID		BIGINT UNSIGNED PRIMARY KEY
		,	SubscriberID	INT NOT NULL
		,	LoginName		VARCHAR(100) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'     
        ,	CTSCustID		BIGINT UNSIGNED
        
        ,	INDEX IX_Temp_MBAccount_CTSCustID(CTSCustID)
	);  

    SET lv_LastAccountID = 0;
	
    SELECT MAX(acc.ID)
    INTO lv_MaxAccountID
    FROM DCS_DataCenter.MBAccount AS acc;
    
    WHILE (lv_LastAccountID < lv_MaxAccountID) DO	
    
		DELETE tmpAcc 
        FROM Temp_MBAccount AS tmpAcc;
        
		INSERT INTO Temp_MBAccount (MBAccountID, SubscriberID, LoginName)        
		SELECT	acc.ID
			,	acc.SubscriberID
			,	acc.LoginName
		FROM 	DCS_DataCenter.MBAccount AS acc
		WHERE	acc.IsCTSTransformed = 0
			AND acc.ID > lv_LastAccountID
			AND acc.ID <= lv_MaxAccountID
		ORDER BY acc.ID ASC
		LIMIT	ip_BatchSize;
        
        UPDATE Temp_MBAccount AS tmpAcc
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.RegisterName = tmpAcc.LoginName AND cus.SubscriberID = tmpAcc.SubscriberID
		SET tmpAcc.CTSCustID = cus.CTSCustID;
        
		UPDATE Temp_MBAccount AS tmpAcc
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.UserName = tmpAcc.LoginName AND cus.SubscriberID = tmpAcc.SubscriberID
		SET tmpAcc.CTSCustID = cus.CTSCustID
        WHERE tmpAcc.CTSCustID IS NULL;
        
        INSERT IGNORE INTO CTS_DataCenter.CustDCSMBAccount(CTSCustID, MBAccountID, SubscriberID, InsertedTime)
        SELECT	tmpAcc.CTSCustID
			,	tmpAcc.MBAccountID
            ,	tmpAcc.SubscriberID
            ,	CURRENT_TIMESTAMP(4) AS InsertedTime
        FROM Temp_MBAccount AS tmpAcc
        WHERE tmpAcc.CTSCustID IS NOT NULL; 
		
        UPDATE DCS_DataCenter.MBAccount AS acc
			INNER JOIN Temp_MBAccount AS tmpAcc ON tmpAcc.MBAccountID = acc.ID 
		SET acc.IsCTSTransformed = 1
        WHERE tmpAcc.CTSCustID IS NOT NULL;
        
        SET lv_LastAccountID = (SELECT MAX(MBAccountID) FROM Temp_MBAccount);
        
		UPDATE CTS_DataCenter.SystemParameter AS sys
        SET sys.ParameterValue = IFNULL(lv_LastAccountID,0)
		WHERE sys.ParameterID = CONST_SYSTEMPARAM_LASTACCOUNTID;
        
	END WHILE;   
        
END$$

DELIMITER ;
