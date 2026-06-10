/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_ArchiveCustomer_Clean`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_ArchiveCustomer_Clean`()
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20210927@Aries.Nguyen
		Task :		Archive Customer
		DB:			CTS_DataCenter, DCS_DataCenter
		Original:

		Revisions:
			- 	20210927@Aries.Nguyen: 	Created [Redmine ID: #162277]
			- 	20211123@Aries.Nguyen: 	Clean data inactive association [Redmine ID: #165001]
			- 	20211216@Aries.Nguyen: 	Clean data Sum Account Login Info [Redmine ID: #165105]
			-	20220408@Casey.Huynh: 	Add AssociationGroupByAI [Redmine ID: #171222]
			-	20220713@Aries.Nguyen: 	HotFix Customer NULL CC [Redmine ID: #175406]
			-	20220720@Aries.Nguyen: 	Missing remove unused columns in 'CTS_DC_ArchiveCustomer_Clean' [Redmine ID: #175631]
			-	20220519@Aries.Nguyen: 	Clean data Classification BySport tables   [Redmine ID: #176992]
			- 	20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
			- 	20231023@Jonas.Huynh:	HF wrong reactivated category [Redmine ID: #193050]
			-	20240321@Thomas.Nguyen:	Clean data for Special CC BySport/History and history of special CC general [Redmine ID: #201360]
			-	20240628@Thomas.Nguyen: Renovate CC phase 2 [Redmine ID: #205317]
			- 	20241018@Thomas.Nguyen: CC Agent [Redmine ID: #185799]
			-	20250327@Casey.Huynh: 	Clean Table Customer_FirstTWTaggingCC [Redmine ID #221508]
			-	20250520@Thomas.Nguyen: Clean Table Customer_SpecialLicSubCC [Redmine ID #226847]
			- 	20250725@Winfred.Pham: Archive Agent and rescan Queue Considerable (Redmine ID: #219679)
			-	20251009@Thomas.Nguyen: Remove unused Tables AssociatedAccountMonitor, CustEvidenceFromFile, CustEvidenceLog, CustEvidenceQueue, SmartGroupHistory [Redmine ID: #241032]

		Param's Explanation (filtered by):	
        
        Example:
			CALL CTS_DC_ArchiveCustomer_Clean();
	*/
    
	DECLARE CONST_PARENTID_PA			INT;
	DECLARE	CONST_PARENTID_WRAPPER		INT;
	DECLARE lv_CurrentDateTime			DATETIME DEFAULT NOW();
    DECLARE lv_CustBatchSize 			INT;
    DECLARE lv_CleanTableBatchSize 		INT;
    DECLARE lv_LastID 					BIGINT UNSIGNED;
    DECLARE lv_NextID 					BIGINT UNSIGNED;
    DECLARE lv_Table 					VARCHAR(100);
    DECLARE lv_Count				    INT DEFAULT 0;
	DECLARE lv_AgentCreditList 			LONGTEXT DEFAULT NULL;
	DECLARE	CONST_ROLEID_AGENT 			TINYINT DEFAULT 2;
    
	SET CONST_PARENTID_PA 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_PARENTID_WRAPPER			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');

    DROP TEMPORARY TABLE IF EXISTS Temp_CustInfo;
    CREATE TEMPORARY TABLE Temp_CustInfo(
			ArchiveID	BIGINT UNSIGNED
		,	CustID		BIGINT UNSIGNED
		,	CTSCustID	BIGINT UNSIGNED
        ,	AccountID   BIGINT UNSIGNED
        ,	INDEX 		IX_Temp_CustInfo_CTSCustID(CTSCustID)
        ,	INDEX 		IX_Temp_CustInfo_CustID(CustID)
        ,	INDEX 		IX_Temp_CustInfo_AccountID(AccountID)
    );
    
    SELECT ParameterValue
	INTO lv_CustBatchSize
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 43; 
    
	SELECT ParameterValue
	INTO lv_CleanTableBatchSize
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 44;
    
    SELECT ParameterValue
	INTO lv_LastID 
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 45; 
    
    SELECT ParameterValue
	INTO lv_Table 
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 46; 
  
    INSERT IGNORE INTO Temp_CustInfo(ArchiveID,CustID,CTSCustID,AccountID)
    SELECT	ID
		,	CustID
		,	CTSCustID
        ,	AccountID
    FROM CTS_DataCenter.ArchiveCustomer_CTSCustomer
    WHERE ID > lv_LastID
		AND IsReactivated = 0
    ORDER BY ID ASC
    LIMIT lv_CustBatchSize;

	IF NOT EXISTS (SELECT 1 FROM Temp_CustInfo) THEN
		LEAVE sp; 
	END IF;
    
    /*************************************** 1. DCS_DataCenter.DeviceFingerprint *******************************/
    IF (lv_Table = 'DCS_DataCenter.DeviceFingerprint') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.ArchiveCustomer_Device) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_DeviceFingerprint_Clean;
			CREATE TEMPORARY TABLE Temp_DeviceFingerprint_Clean(
					DeviceID   			BIGINT UNSIGNED
				,	FingerprintCode   	VARCHAR(620) COLLATE utf8_unicode_ci
				,	PRIMARY KEY(DeviceID, FingerprintCode)
			);
            
            INSERT IGNORE INTO Temp_DeviceFingerprint_Clean(DeviceID, FingerprintCode)
            SELECT 	df.DeviceID
				,	df.FingerprintCode
			FROM DCS_DataCenter.DeviceFingerprint AS df
            WHERE EXISTS (SELECT 1 FROM DCS_DataCenter.ArchiveCustomer_Device AS dv  WHERE dv.DeviceID = df.DeviceID)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE df
			FROM  DCS_DataCenter.DeviceFingerprint AS df
				INNER JOIN Temp_DeviceFingerprint_Clean AS tmp ON tmp.DeviceID = df.DeviceID AND tmp.FingerprintCode = df.FingerprintCode;
			
            UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'DCS_DataCenter.DeviceFingerprint'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_DeviceFingerprint_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
            
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
		SET lv_Table = 'DCS_DataCenter.DeviceCode';
    END IF;
    
    /*************************************** 2. DCS_DataCenter.DeviceCode **************************************/
    IF (lv_Table = 'DCS_DataCenter.DeviceCode') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.ArchiveCustomer_Device) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_DeviceCode_Clean;
			CREATE TEMPORARY TABLE Temp_DeviceCode_Clean(
					DeviceCodeID   	BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_DeviceCode_Clean(DeviceCodeID)
            SELECT 	dc.DeviceCodeID
			FROM DCS_DataCenter.DeviceCode AS dc
            WHERE EXISTS (SELECT 1 FROM DCS_DataCenter.ArchiveCustomer_Device AS dv  WHERE dv.DeviceID = dc.DeviceID)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE dc
			FROM  DCS_DataCenter.DeviceCode AS dc
				INNER JOIN Temp_DeviceCode_Clean AS tmp ON tmp.DeviceCodeID = dc.DeviceCodeID;
			
            UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'DCS_DataCenter.DeviceCode'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_DeviceCode_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
            
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
		SET lv_Table = 'DCS_DataCenter.Device';
    END IF;
    
    /*************************************** 3. DCS_DataCenter.Device ******************************************/
    IF (lv_Table = 'DCS_DataCenter.Device') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.ArchiveCustomer_Device) THEN
            DELETE dv
			FROM  DCS_DataCenter.Device AS dv
				INNER JOIN DCS_DataCenter.ArchiveCustomer_Device AS tmp ON tmp.DeviceID = dv.DeviceID;
			
            SELECT COUNT(1)
            INTO lv_Count
            FROM DCS_DataCenter.ArchiveCustomer_Device;
            
            DELETE dv
			FROM  DCS_DataCenter.ArchiveCustomer_Device AS dv;
            
            UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'DCS_DataCenter.Device'
			WHERE ParameterID = 46;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
            
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
		SET lv_Table = 'DCS_DataCenter.Association';
    END IF;
	
    /*************************************** 4. DCS_DataCenter.Association *************************************/
    IF (lv_Table = 'DCS_DataCenter.Association') THEN
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.Association AS ass  WHERE  ass.AccountID IN (SELECT tmp.AccountID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_Association_Clean;
			CREATE TEMPORARY TABLE Temp_Association_Clean(
					AccountID   	BIGINT UNSIGNED
				,	DeviceID   		BIGINT UNSIGNED
				,	PRIMARY KEY(AccountID, DeviceID)
			);
            
            INSERT IGNORE INTO Temp_Association_Clean(AccountID, DeviceID)
            SELECT 	ass.AccountID
				, 	ass.DeviceID
			FROM DCS_DataCenter.Association AS ass
            WHERE  ass.AccountID IN (SELECT tmp.AccountID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            INSERT INTO DCS_DataCenter.ArchiveCustomer_Device(AccountID, DeviceID)
			SELECT  tmp.AccountID 
				,	tmp.DeviceID
			FROM Temp_Association_Clean AS tmp
			WHERE NOT EXISTS (SELECT 1 
							  FROM DCS_DataCenter.Association AS ass 
							  WHERE ass.DeviceID = tmp.DeviceID 
								AND ass.AccountID != tmp.AccountID);
            
            DELETE ass
			FROM  DCS_DataCenter.Association AS ass
				INNER JOIN Temp_Association_Clean AS tmp ON tmp.AccountID = ass.AccountID AND tmp.DeviceID = ass.DeviceID;
			
            IF EXISTS(SELECT 1 FROM DCS_DataCenter.ArchiveCustomer_Device) THEN
				UPDATE  CTS_DataCenter.SystemParameter 
				SET ParameterValue = 'DCS_DataCenter.DeviceFingerprint'
				WHERE ParameterID = 46;
                
                LEAVE sp;
            ELSE 
				UPDATE  CTS_DataCenter.SystemParameter 
				SET ParameterValue = 'DCS_DataCenter.Association'
				WHERE ParameterID = 46;
            END IF;
            
			
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_Association_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'DCS_DataCenter.Account';
    END IF;
	
    /*************************************** 5. DCS_DataCenter.Account *****************************************/
	IF (lv_Table = 'DCS_DataCenter.Account') THEN 
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.Account AS acc WHERE  acc.AccountID IN (SELECT tmp.AccountID FROM Temp_CustInfo AS tmp)) THEN
			DELETE acc
			FROM DCS_DataCenter.Account AS acc
				INNER JOIN  Temp_CustInfo AS tmp ON acc.AccountID = tmp.AccountID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'DCS_DataCenter.Account'
			WHERE ParameterID = 46;
			
			LEAVE sp;
        END IF;
        
        SET lv_Table = 'DCS_DataCenter.SumAccountLoginTotal';
    END IF; 
    
    /*************************************** 6. DCS_DataCenter.SumAccountLoginTotal ******************************/
	IF (lv_Table = 'DCS_DataCenter.SumAccountLoginTotal') THEN 
		IF EXISTS (SELECT 1  FROM DCS_DataCenter.SumAccountLoginTotal AS acc WHERE  acc.AccountID IN (SELECT tmp.AccountID FROM Temp_CustInfo AS tmp)) THEN
			DELETE acc
			FROM DCS_DataCenter.SumAccountLoginTotal AS acc
				INNER JOIN  Temp_CustInfo AS tmp ON acc.AccountID = tmp.AccountID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'DCS_DataCenter.SumAccountLoginTotal'
			WHERE ParameterID = 46;
			
			LEAVE sp;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.AssociatedAccountNotification';
    END IF; 
    
    /*************************************** 8. CTS_DataCenter.AssociatedAccountNotification *******************/
    IF (lv_Table = 'CTS_DataCenter.AssociatedAccountNotification') THEN 
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociatedAccountNotification AS ass WHERE  ass.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedAccountNotification_Clean;
			CREATE TEMPORARY TABLE Temp_AssociatedAccountNotification_Clean(
					AccountNewAssID   	BIGINT UNSIGNED  PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociatedAccountNotification_Clean(AccountNewAssID)
            SELECT ass.AccountNewAssID
			FROM CTS_DataCenter.AssociatedAccountNotification AS ass
			WHERE  ass.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_DataCenter.AssociatedAccountNotification AS ass
			WHERE  ass.AccountNewAssID IN (SELECT tmp.AccountNewAssID FROM Temp_AssociatedAccountNotification_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.AssociatedAccountNotification'
			WHERE ParameterID = 46;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociatedAccountNotification_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        SET lv_Table = 'CTS_DataCenter.AssociationByAI-From';
    END IF;
    
    /*************************************** 9. CTS_DataCenter.AssociationByAI *********************************/
    IF (lv_Table = 'CTS_DataCenter.AssociationByAI-From') THEN  
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByAI AS ai WHERE  ai.FromCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByAI_Clean(
					AssID	BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByAI_Clean(AssID)
            SELECT 	ai.AssID
			FROM CTS_DataCenter.AssociationByAI  AS ai
			WHERE  ai.FromCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_DataCenter.AssociationByAI AS ass
				INNER JOIN Temp_AssociationByAI_Clean AS tmp ON tmp.AssID = ass.AssID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.AssociationByAI-From'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByAI_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
		SET lv_Table = 'CTS_DataCenter.AssociationByAI-To';
    END IF;
    
    IF (lv_Table = 'CTS_DataCenter.AssociationByAI-To') THEN  
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByAI AS ai WHERE  ai.ToCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByAI_Clean(
					AssID	BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByAI_Clean(AssID)
            SELECT 	ai.AssID
			FROM CTS_DataCenter.AssociationByAI AS ai
			WHERE  ai.ToCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_DataCenter.AssociationByAI AS ass
				INNER JOIN Temp_AssociationByAI_Clean AS tmp ON tmp.AssID = ass.AssID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.AssociationByAI-To'
			WHERE ParameterID = 46;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByAI_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.AssociationGroupByAI';
    END IF;
    
    IF (lv_Table = 'CTS_DataCenter.AssociationGroupByAI') THEN  
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationGroupByAI AS asg WHERE  asg.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationGroupByAI_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationGroupByAI_Clean(
					CustID 		BIGINT UNSIGNED NOT NULL
				,	GroupID 	BIGINT UNSIGNED NOT NULL
                
                ,	PRIMARY KEY (CustID, GroupID)
			) ENGINE=InnoDB;
            
            INSERT IGNORE INTO Temp_AssociationGroupByAI_Clean(CustID, GroupID)
            SELECT 	asg.CustID
				,	asg.GroupID
			FROM CTS_DataCenter.AssociationGroupByAI AS asg
			WHERE  asg.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE asg
			FROM CTS_DataCenter.AssociationGroupByAI AS asg
				INNER JOIN Temp_AssociationGroupByAI_Clean AS tmp ON tmp.CustID = asg.CustID AND tmp.GroupID = asg.GroupID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.AssociationGroupByAI'
			WHERE ParameterID = 46;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationGroupByAI_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.AssociationByDevice';
    END IF;
	
   /**************************************** 10. CTS_DataCenter.AssociationByDevice ****************************/
    IF (lv_Table = 'CTS_DataCenter.AssociationByDevice') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByDevice  AS dv WHERE dv.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByDevice_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByDevice_Clean(
					CTSAssDevID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByDevice_Clean(CTSAssDevID)
            SELECT 	dv.CTSAssDevID
			FROM CTS_DataCenter.AssociationByDevice AS dv
			WHERE  dv.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE dv
			FROM CTS_DataCenter.AssociationByDevice AS dv
			WHERE  dv.CTSAssDevID IN (SELECT tmp.CTSAssDevID FROM Temp_AssociationByDevice_Clean AS tmp);
        
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.AssociationByDevice'
			WHERE ParameterID = 46;
        
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByDevice_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.AssociationByIP-From';
	END IF; 
    
	/*************************************** 11. CTS_DataCenter.AssociationByIP ********************************/
    IF (lv_Table = 'CTS_DataCenter.AssociationByIP-From') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByIP AS ip WHERE ip.FromCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByIP_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByIP_Clean(ID)
            SELECT 	ip.ID
			FROM CTS_DataCenter.AssociationByIP AS ip
			WHERE  ip.FromCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE ip
			FROM CTS_DataCenter.AssociationByIP AS ip
			WHERE  ip.ID IN (SELECT tmp.ID FROM Temp_AssociationByIP_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.AssociationByIP-From'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByIP_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.AssociationByIP-To';
	 END IF; 
     
	IF (lv_Table = 'CTS_DataCenter.AssociationByIP-To') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByIP AS ip WHERE ip.ToCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByIP_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByIP_Clean(ID)
            SELECT 	ip.ID
			FROM CTS_DataCenter.AssociationByIP AS ip
			WHERE  ip.ToCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE 
			FROM CTS_DataCenter.AssociationByIP AS ip
			WHERE  ip.ID IN (SELECT tmp.ID FROM Temp_AssociationByIP_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.AssociationByIP-To'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByIP_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.AssociationRemove-From';
	 END IF;   
     
     
    /*************************************** 13. CTS_DataCenter.AssociationRemove ****************************/
    IF (lv_Table = 'CTS_DataCenter.AssociationRemove-From') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationRemove AS rm WHERE rm.FromCTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp))  THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationRemove_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationRemove_Clean(
					FromCTSCustID   	BIGINT UNSIGNED  
				,	ToCTSCustID			BIGINT UNSIGNED
                ,	PRIMARY KEY(FromCTSCustID, ToCTSCustID)
			);
            
            INSERT IGNORE INTO Temp_AssociationRemove_Clean(FromCTSCustID, ToCTSCustID)
            SELECT 	rm.FromCTSCustID
				,	rm.ToCTSCustID
			FROM CTS_DataCenter.AssociationRemove AS rm
			WHERE  rm.FromCTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_DataCenter.AssociationRemove AS ass
				INNER JOIN Temp_AssociationRemove_Clean AS tmp ON tmp.FromCTSCustID = ass.FromCTSCustID AND tmp.ToCTSCustID = ass.ToCTSCustID;
			
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.AssociationRemove-From'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationRemove_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.AssociationRemove-To';
	END IF;  
    
    IF (lv_Table = 'CTS_DataCenter.AssociationRemove-To') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationRemove AS rm WHERE rm.ToCTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationRemove_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationRemove_Clean(
					FromCTSCustID   	BIGINT UNSIGNED  
				,	ToCTSCustID			BIGINT UNSIGNED
                ,	PRIMARY KEY(FromCTSCustID, ToCTSCustID)
			);
            
            INSERT IGNORE INTO Temp_AssociationRemove_Clean(FromCTSCustID, ToCTSCustID)
            SELECT 	rm.FromCTSCustID
				,	rm.ToCTSCustID
			FROM CTS_DataCenter.AssociationRemove AS rm
			WHERE  rm.ToCTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_DataCenter.AssociationRemove AS ass
				INNER JOIN Temp_AssociationRemove_Clean AS tmp ON tmp.FromCTSCustID = ass.FromCTSCustID AND tmp.ToCTSCustID = ass.ToCTSCustID;
			
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.AssociationRemove-To'
			WHERE ParameterID = 46;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationRemove_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CTSCustomerClassification';
	 END IF; 

	/*************************************** 14. CTS_DataCenter.CTSCustomerClassification, CTSCustomerClassification_BySport ********************/
    IF (lv_Table = 'CTS_DataCenter.CTSCustomerClassification') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CTSCustomerClassification AS clss WHERE clss.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassification_Clean;
			CREATE TEMPORARY TABLE Temp_CTSCustomerClassification_Clean(
					CustID   			BIGINT UNSIGNED  
				,	ParentID			INT UNSIGNED
                ,	CategoryID			INT
                ,	PRIMARY KEY(CustID, ParentID, CategoryID)
			);
            
            DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassification_Archive;
			CREATE TEMPORARY TABLE Temp_CTSCustomerClassification_Archive(
					ArchiveID			BIGINT UNSIGNED PRIMARY KEY
				,	CustID   			BIGINT 
			);
            
			DROP TEMPORARY TABLE IF EXISTS Temp_CustLatestCate;
    		CREATE TEMPORARY TABLE 		Temp_CustLatestCate (
        			CustID				BIGINT UNSIGNED
				,	ParentID			INT UNSIGNED
				,	LatestCateID   		INT UNSIGNED
				,	PRIMARY KEY(CustID, ParentID, LatestCateID)
    		);  

            INSERT IGNORE INTO Temp_CTSCustomerClassification_Clean(CustID, ParentID, CategoryID)
            SELECT 	clss.CustID
				,	clss.ParentID
                ,	clss.CategoryID
			FROM CTS_DataCenter.CTSCustomerClassification AS clss
			WHERE  clss.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            INSERT IGNORE INTO Temp_CTSCustomerClassification_Archive(ArchiveID, CustID)
            SELECT 	arc.ID, arc.CustID
			FROM CTS_DataCenter.ArchiveCustomer_CTSCustomer AS arc 
				INNER JOIN Temp_CustInfo AS temp ON temp.ArchiveID = arc.ID AND arc.CustSubID = 0
			WHERE arc.CategoryID IS NULL;
            
			INSERT IGNORE INTO Temp_CustLatestCate(CustID, ParentID, LatestCateID)
			SELECT tmp.CustID, cate.ParentID, cate.CategoryID
			FROM Temp_CustInfo AS tmp,
			LATERAL
				(
					SELECT cls.CustID, cls.ParentID, cls.CategoryID
					FROM CTS_DataCenter.CTSCustomerClassification AS cls
						INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cls.CategoryID = cate.CategoryID AND cate.IsActive = 1
					WHERE cls.CustID = tmp.CustID AND cls.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY  cate.CustomerClassPriority ASC 
							, cls.LastModifiedDate DESC
					LIMIT 1
				) AS cate;

            IF EXISTS (SELECT 1 FROM Temp_CTSCustomerClassification_Archive) THEN
				UPDATE CTS_DataCenter.ArchiveCustomer_CTSCustomer AS arc
					INNER JOIN Temp_CTSCustomerClassification_Archive AS temp ON temp.ArchiveID = arc.ID
					INNER JOIN Temp_CustLatestCate AS cate ON cate.CustID = arc.CustID
				SET arc.CategoryID = cate.LatestCateID;
            END IF;

			IF EXISTS (SELECT 1 FROM Temp_CustLatestCate WHERE ParentID = CONST_PARENTID_PA) THEN
				UPDATE CTS_DataCenter.TVSVoidRequest AS tvs
					INNER JOIN Temp_CustLatestCate AS cate ON cate.CustID = tvs.CustID AND cate.ParentID = CONST_PARENTID_PA
				SET		tvs.IsDisabled = 1
					,	tvs.ArchivedDate = lv_CurrentDateTime
				WHERE tvs.IsDisabled = 0;

				UPDATE CTS_DataCenter.CTSRobotUser AS cru
					INNER JOIN Temp_CustLatestCate AS cate ON cate.CustID = cru.CustID AND cate.ParentID = CONST_PARENTID_PA
				SET		cru.IsDisabled = 1
					,	cru.ArchivedDate = lv_CurrentDateTime
				WHERE cru.IsDisabled = 0;

				UPDATE CTS_DataCenter.RobotDetection AS rd
					INNER JOIN Temp_CustLatestCate AS cate ON cate.CustID = rd.CustID AND cate.ParentID = CONST_PARENTID_PA
				SET		rd.IsDisabled = 1
				WHERE rd.IsDisabled = 0;

				UPDATE CTS_DataCenter.TWRobotUser AS tru
					INNER JOIN Temp_CustLatestCate AS cate ON cate.CustID = tru.CustID AND cate.ParentID = CONST_PARENTID_PA
				SET		tru.IsDisabled = 1
					,	tru.ArchivedDate = lv_CurrentDateTime
				WHERE tru.IsDisabled = 0;

				UPDATE CTS_DataCenter.CustomerLoginInfoDetection AS cld
					INNER JOIN Temp_CustLatestCate AS cate ON cate.CustID = cld.CustID AND cate.ParentID = CONST_PARENTID_PA
				SET		cld.IsDisabled = 1
					,	cld.ArchivedDate = lv_CurrentDateTime
				WHERE cld.IsDisabled = 0;
			END IF;

            DELETE cl
			FROM CTS_DataCenter.CTSCustomerClassification AS cl
				INNER JOIN Temp_CTSCustomerClassification_Clean AS tmp ON tmp.CustID = cl.CustID 
																		AND tmp.ParentID = cl.ParentID
																		AND tmp.CategoryID = cl.CategoryID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CTSCustomerClassification'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CTSCustomerClassification_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CTSCustomerClassification_BySport';
	 END IF; 

     IF (lv_Table = 'CTS_DataCenter.CTSCustomerClassification_BySport') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CTSCustomerClassification_BySport AS clss WHERE clss.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassification_BySport_Clean;
			CREATE TEMPORARY TABLE Temp_CTSCustomerClassification_BySport_Clean(
					CustID   			BIGINT UNSIGNED  
				,	SportID				BIGINT UNSIGNED
				,	ParentID			INT UNSIGNED
				,	CategoryID			INT UNSIGNED
                ,	PRIMARY KEY(CustID, SportID, ParentID, CategoryID)
			);
            
            INSERT IGNORE INTO Temp_CTSCustomerClassification_BySport_Clean(CustID, SportID, ParentID, CategoryID)
            SELECT 	clss.CustID
				,	clss.SportID
				,	clss.ParentID
				,	clss.CategoryID
			FROM CTS_DataCenter.CTSCustomerClassification_BySport AS clss
			WHERE  clss.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE cl
			FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cl
				INNER JOIN Temp_CTSCustomerClassification_BySport_Clean AS tmp ON tmp.CustID = cl.CustID 
																		AND tmp.SportID = cl.SportID
																		AND tmp.ParentID = cl.ParentID
																		AND tmp.CategoryID = cl.CategoryID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CTSCustomerClassification_BySport'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CTSCustomerClassification_BySport_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CTSCustomerClassification_History';
	 END IF; 
     
    /*************************************** 15. CTS_DataCenter.CTSCustomerClassification_History, CTSCustomerClassification_BySport_History ************/
    IF (lv_Table = 'CTS_DataCenter.CTSCustomerClassification_History') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CTSCustomerClassification_History AS his WHERE his.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassification_History_Clean;
			CREATE TEMPORARY TABLE Temp_CTSCustomerClassification_History_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_CTSCustomerClassification_History_Clean(ID)
            SELECT 	his.ID
			FROM CTS_DataCenter.CTSCustomerClassification_History AS his
			WHERE  his.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE his
			FROM CTS_DataCenter.CTSCustomerClassification_History AS his
			WHERE  his.ID IN (SELECT tmp.ID FROM Temp_CTSCustomerClassification_History_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CTSCustomerClassification_History'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CTSCustomerClassification_History_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CTSCustomerClassification_BySport_History';
	 END IF; 
     
     IF (lv_Table = 'CTS_DataCenter.CTSCustomerClassification_BySport_History') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS his WHERE his.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassification_BySport_History_Clean;
			CREATE TEMPORARY TABLE Temp_CTSCustomerClassification_BySport_History_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_CTSCustomerClassification_BySport_History_Clean(ID)
            SELECT 	his.ID
			FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS his
			WHERE  his.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE his
			FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS his
			WHERE  his.ID IN (SELECT tmp.ID FROM Temp_CTSCustomerClassification_BySport_History_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CTSCustomerClassification_BySport_History'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CTSCustomerClassification_BySport_History_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CTSCustomerClassification_InputDataLog';
	 END IF; 
     
    /*************************************** 16. CTS_DataCenter.CTSCustomerClassification_InputDataLog *******/
    IF (lv_Table = 'CTS_DataCenter.CTSCustomerClassification_InputDataLog') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CTSCustomerClassification_InputDataLog AS lo WHERE lo.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN 
			DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassification_InputDataLog_Clean;
			CREATE TEMPORARY TABLE Temp_CTSCustomerClassification_InputDataLog_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_CTSCustomerClassification_InputDataLog_Clean(ID)
            SELECT 	lo.ID
			FROM CTS_DataCenter.CTSCustomerClassification_InputDataLog AS lo
			WHERE  lo.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE lo
			FROM CTS_DataCenter.CTSCustomerClassification_InputDataLog AS lo
			WHERE  lo.ID IN (SELECT tmp.ID FROM Temp_CTSCustomerClassification_InputDataLog_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CTSCustomerClassification_InputDataLog'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CTSCustomerClassification_InputDataLog_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CustDCSAccount';
	 END IF; 
    
    /*************************************** 17. CTS_DataCenter.CustDCSAccount *******************************/
	IF (lv_Table = 'CTS_DataCenter.CustDCSAccount') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CustDCSAccount AS cu WHERE cu.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DELETE cu
			FROM CTS_DataCenter.CustDCSAccount AS cu
			WHERE  cu.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CustDCSAccount'
			WHERE ParameterID = 46;
					
			LEAVE sp;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CustEvidence-Leve0';
	 END IF; 
    
    /*************************************** 18. CTS_DataCenter.CustEvidence *********************************/
	IF (lv_Table = 'CTS_DataCenter.CustEvidence-Leve0') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CustEvidence AS ev WHERE ev.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CustEvidence_Clean;
			CREATE TEMPORARY TABLE Temp_CustEvidence_Clean(
					CustEvidID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_CustEvidence_Clean(CustEvidID)
            SELECT 	ev.CustEvidID
			FROM CTS_DataCenter.CustEvidence AS ev
			WHERE  ev.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE ev
			FROM CTS_DataCenter.CustEvidence AS ev
			WHERE  ev.CustEvidID IN (SELECT tmp.CustEvidID FROM Temp_CustEvidence_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CustEvidence-Leve0'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CustEvidence_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CustEvidence-Leve2';
	 END IF; 
     
    IF (lv_Table = 'CTS_DataCenter.CustEvidence-Leve2') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CustEvidence AS ev WHERE ev.FromCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CustEvidence_Clean;
			CREATE TEMPORARY TABLE Temp_CustEvidence_Clean(
					CustEvidID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_CustEvidence_Clean(CustEvidID)
            SELECT 	ev.CustEvidID
			FROM CTS_DataCenter.CustEvidence AS ev
			WHERE  ev.FromCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE ev
			FROM CTS_DataCenter.CustEvidence  AS ev
			WHERE  ev.CustEvidID IN (SELECT tmp.CustEvidID FROM Temp_CustEvidence_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CustEvidence-Leve2'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CustEvidence_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CustException-From';
	 END IF;         
	
	/*************************************** 22. CTS_DataCenter.CustException ********************************/
	IF (lv_Table = 'CTS_DataCenter.CustException-From') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CustException AS ex WHERE ex.FromCTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CustException_Clean;
			CREATE TEMPORARY TABLE Temp_CustException_Clean(
					FromCTSCustID   	BIGINT UNSIGNED  
				,	ToCTSCustID			BIGINT UNSIGNED
                ,	PRIMARY KEY(FromCTSCustID, ToCTSCustID)
			);
            
            INSERT IGNORE INTO Temp_CustException_Clean(FromCTSCustID, ToCTSCustID)
            SELECT 	ex.FromCTSCustID
				,	ex.ToCTSCustID
			FROM CTS_DataCenter.CustException AS ex
			WHERE  ex.FromCTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_DataCenter.CustException AS ass
				INNER JOIN Temp_CustException_Clean AS tmp ON tmp.FromCTSCustID = ass.FromCTSCustID AND tmp.ToCTSCustID = ass.ToCTSCustID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CustException-From'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CustException_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CustException-To';
	 END IF; 
     
    IF (lv_Table = 'CTS_DataCenter.CustException-To') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CustException AS ex WHERE ex.ToCTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CustException_Clean;
			CREATE TEMPORARY TABLE Temp_CustException_Clean(
					FromCTSCustID   	BIGINT UNSIGNED  
				,	ToCTSCustID			BIGINT UNSIGNED
                ,	PRIMARY KEY(FromCTSCustID, ToCTSCustID)
			);
            
            INSERT IGNORE INTO Temp_CustException_Clean(FromCTSCustID, ToCTSCustID)
            SELECT 	ex.FromCTSCustID
				,	ex.ToCTSCustID
			FROM CTS_DataCenter.CustException  AS ex
			WHERE  ex.ToCTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_DataCenter.CustException AS ass
				INNER JOIN Temp_CustException_Clean AS tmp ON tmp.FromCTSCustID = ass.FromCTSCustID AND tmp.ToCTSCustID = ass.ToCTSCustID;
			
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CustException-To'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CustException_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CustRetractEvidence';
	 END IF; 
     
    /*************************************** 23. CTS_DataCenter.CustRetractEvidence ***************************/
	IF (lv_Table = 'CTS_DataCenter.CustRetractEvidence' ) THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CustRetractEvidence  AS ev WHERE ev.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CustRetractEvidence_Clean;
			CREATE TEMPORARY TABLE Temp_CustRetractEvidence_Clean(
					CTSCustID   		BIGINT UNSIGNED  
				,	EvidenceID			BIGINT UNSIGNED
                ,	PRIMARY KEY(CTSCustID, EvidenceID)
			);
            
			INSERT IGNORE INTO Temp_CustRetractEvidence_Clean(CTSCustID, EvidenceID)
            SELECT 	ev.CTSCustID
				,	ev.EvidenceID
			FROM CTS_DataCenter.CustRetractEvidence AS ev
			WHERE  ev.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ev
			FROM CTS_DataCenter.CustRetractEvidence AS ev
				INNER JOIN Temp_CustRetractEvidence_Clean AS tmp ON tmp.CTSCustID = ev.CTSCustID
															AND tmp.EvidenceID = ev.EvidenceID;
			
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CustRetractEvidence'
			WHERE ParameterID = 46;
		   
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CustRetractEvidence_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.SpecialCustomerClass';
	 END IF; 

    /*************************************** 29. CTS_DataCenter.SpecialCustomerClass **************************/
    IF (lv_Table = 'CTS_DataCenter.SpecialCustomerClass') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.SpecialCustomerClass As sp WHERE sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_SpecialCustomerClass_Clean;
			CREATE TEMPORARY TABLE Temp_SpecialCustomerClass_Clean(
					CTSCustID   			BIGINT UNSIGNED 
				,	CreatedFromFunction		TINYINT
                ,	PRIMARY KEY(CTSCustID, CreatedFromFunction)
			);
            
            INSERT IGNORE INTO Temp_SpecialCustomerClass_Clean(CTSCustID, CreatedFromFunction)
            SELECT 	sp.CTSCustID
				,	sp.CreatedFromFunction
			FROM CTS_DataCenter.SpecialCustomerClass As sp
			WHERE  sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
			DELETE sp
			FROM CTS_DataCenter.SpecialCustomerClass AS sp
				INNER JOIN Temp_SpecialCustomerClass_Clean AS tmp ON tmp.CTSCustID = sp.CTSCustID
																AND tmp.CreatedFromFunction = sp.CreatedFromFunction;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.SpecialCustomerClass'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_SpecialCustomerClass_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.TaggingExclusion';
	 END IF;    
     
    /*************************************** 30. CTS_DataCenter.TaggingExclusion ******************************/
    IF (lv_Table = 'CTS_DataCenter.TaggingExclusion') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.TaggingExclusion AS tag WHERE tag.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_TaggingExclusion_Clean;
			CREATE TEMPORARY TABLE Temp_TaggingExclusion_Clean(
					CTSCustID   	BIGINT UNSIGNED PRIMARY KEY 
			);
            
            INSERT IGNORE INTO Temp_TaggingExclusion_Clean(CTSCustID)
            SELECT 	tag.CTSCustID
			FROM CTS_DataCenter.TaggingExclusion AS tag
			WHERE  tag.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE tag
			FROM CTS_DataCenter.TaggingExclusion AS tag
			WHERE  tag.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_TaggingExclusion_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.TaggingExclusion'
			WHERE ParameterID = 46;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_TaggingExclusion_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;

		SET lv_Table = 'CTS_Archive.CTSCustomerAssociationStatus';
	 END IF;   
      
	/*************************************** 31. CTS_Archive.CTSCustomerAssociationStatus *********************/
	IF (lv_Table = 'CTS_Archive.CTSCustomerAssociationStatus') THEN 
		IF EXISTS (SELECT 1  FROM CTS_Archive.CTSCustomerAssociationStatus AS acc WHERE  acc.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DELETE acc
			FROM CTS_Archive.CTSCustomerAssociationStatus AS acc
				INNER JOIN  Temp_CustInfo AS tmp ON acc.CTSCustID = tmp.CTSCustID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_Archive.CTSCustomerAssociationStatus'
			WHERE ParameterID = 46;
			
			LEAVE sp;
        END IF;
        
        SET lv_Table = 'CTS_Archive.AssociationByAI_Arc-From';
    END IF; 
    
    /*************************************** 32. CTS_Archive.AssociationByAI_Arc ******************************/
	IF (lv_Table = 'CTS_Archive.AssociationByAI_Arc-From') THEN  
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByAI_Arc AS ai WHERE ai.FromCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByAI_Clean(
					ID   	BIGINT UNSIGNED  PRIMARY KEY 
			);
            
            INSERT IGNORE INTO Temp_AssociationByAI_Clean(ID)
            SELECT ai.ID
			FROM CTS_Archive.AssociationByAI_Arc AS ai
			WHERE  ai.FromCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_Archive.AssociationByAI_Arc AS ass
				INNER JOIN Temp_AssociationByAI_Clean AS tmp ON tmp.ID = ass.ID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_Archive.AssociationByAI_Arc-From'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByAI_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
		SET lv_Table = 'CTS_Archive.AssociationByAI_Arc-To';
    END IF;
    
    IF (lv_Table = 'CTS_Archive.AssociationByAI_Arc-To') THEN  
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByAI_Arc AS ai WHERE ai.ToCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByAI_Clean(
					ID   	BIGINT UNSIGNED  PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByAI_Clean(ID)
            SELECT 	ai.ID
			FROM CTS_Archive.AssociationByAI_Arc AS ai
			WHERE  ai.ToCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_Archive.AssociationByAI_Arc AS ass
				INNER JOIN Temp_AssociationByAI_Clean AS tmp ON tmp.ID = ass.ID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_Archive.AssociationByAI_Arc-To'
			WHERE ParameterID = 46;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByAI_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_Archive.AssociationGroupByAI_Arc';
    END IF; 
    
    IF (lv_Table = 'CTS_Archive.AssociationGroupByAI_Arc') THEN  
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationGroupByAI_Arc AS ai WHERE ai.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationGroupByAI_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationGroupByAI_Clean(
					ID   	BIGINT UNSIGNED  PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationGroupByAI_Clean(ID)
            SELECT 	ai.ID
			FROM CTS_Archive.AssociationGroupByAI_Arc AS ai
			WHERE  ai.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
            LIMIT lv_CleanTableBatchSize;
            
            DELETE ass
			FROM CTS_Archive.AssociationGroupByAI_Arc AS ass
				INNER JOIN Temp_AssociationGroupByAI_Clean AS tmp ON tmp.ID = ass.ID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_Archive.AssociationGroupByAI_Arc'
			WHERE ParameterID = 46;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationGroupByAI_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_Archive.AssociationByDevice_Arc';
    END IF; 
    
	/*************************************** 33. CTS_Archive.AssociationByDevice_Arc ***************************/
    IF (lv_Table = 'CTS_Archive.AssociationByDevice_Arc') THEN
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByDevice_Arc AS dv WHERE dv.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByDevice_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByDevice_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByDevice_Clean(ID)
            SELECT 	dv.ID
			FROM CTS_Archive.AssociationByDevice_Arc AS dv
			WHERE  dv.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE dv
			FROM CTS_Archive.AssociationByDevice_Arc AS dv
			WHERE  dv.ID IN (SELECT tmp.ID FROM Temp_AssociationByDevice_Clean AS tmp);
        
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_Archive.AssociationByDevice_Arc'
			WHERE ParameterID = 46;
        
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByDevice_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_Archive.AssociationByIP_Arc-From';
	END IF; 
    
    /*************************************** 34. CTS_Archive.AssociationByIP_Arc *******************************/
    IF (lv_Table = 'CTS_Archive.AssociationByIP_Arc-From') THEN
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByIP_Arc AS ip WHERE ip.FromCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByIP_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByIP_Clean(ID)
            SELECT 	ip.ID
			FROM CTS_Archive.AssociationByIP_Arc AS ip
			WHERE  ip.FromCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE ip
			FROM CTS_Archive.AssociationByIP_Arc AS ip
			WHERE  ip.ID IN (SELECT tmp.ID FROM Temp_AssociationByIP_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_Archive.AssociationByIP_Arc-From'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByIP_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_Archive.AssociationByIP_Arc-To';
	 END IF; 
     
	IF (lv_Table = 'CTS_Archive.AssociationByIP_Arc-To') THEN
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByIP_Arc AS ip WHERE ip.ToCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByIP_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_AssociationByIP_Clean(ID)
            SELECT 	ip.ID
			FROM CTS_Archive.AssociationByIP_Arc AS ip
			WHERE  ip.ToCustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE ip
			FROM CTS_Archive.AssociationByIP_Arc AS ip
			WHERE  ip.ID IN (SELECT tmp.ID FROM Temp_AssociationByIP_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_Archive.AssociationByIP_Arc-To'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByIP_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.SpecialCustomerClass_BySport';
	 END IF;   

	/*************************************** 36. CTS_DataCenter.SpecialCustomerClass_BySport **************************/
    IF (lv_Table = 'CTS_DataCenter.SpecialCustomerClass_BySport') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.SpecialCustomerClass_BySport As sp WHERE sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_SpecialCustomerClass_BySport_Clean;
			CREATE TEMPORARY TABLE Temp_SpecialCustomerClass_BySport_Clean(
					CTSCustID   			BIGINT UNSIGNED 
				,	SportID					SMALLINT
                ,	PRIMARY KEY(CTSCustID, SportID)
			);
            
            INSERT IGNORE INTO Temp_SpecialCustomerClass_BySport_Clean(CTSCustID, SportID)
            SELECT 	sp.CTSCustID
				,	sp.SportID
			FROM CTS_DataCenter.SpecialCustomerClass_BySport As sp
			WHERE  sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
			DELETE sp
			FROM CTS_DataCenter.SpecialCustomerClass_BySport AS sp
				INNER JOIN Temp_SpecialCustomerClass_BySport_Clean AS tmp ON tmp.CTSCustID = sp.CTSCustID
																AND tmp.SportID = sp.SportID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.SpecialCustomerClass_BySport'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_SpecialCustomerClass_BySport_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.SpecialCustomerClass_History';
	 END IF;    

	/*************************************** 37. CTS_DataCenter.SpecialCustomerClass_History **************************/
    IF (lv_Table = 'CTS_DataCenter.SpecialCustomerClass_History') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.SpecialCustomerClass_History As sp WHERE sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_SpecialCustomerClass_History_Clean;
			CREATE TEMPORARY TABLE Temp_SpecialCustomerClass_History_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_SpecialCustomerClass_History_Clean(ID)
            SELECT 	sp.ID
			FROM CTS_DataCenter.SpecialCustomerClass_History As sp
			WHERE  sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
			DELETE sp
			FROM CTS_DataCenter.SpecialCustomerClass_History AS sp
				INNER JOIN Temp_SpecialCustomerClass_History_Clean AS tmp ON tmp.ID = sp.ID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.SpecialCustomerClass_History'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_SpecialCustomerClass_History_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.SpecialCustomerClass_BySport_History';
	 END IF;

	/*************************************** 38. CTS_DataCenter.SpecialCustomerClass_BySport_History **************************/
    IF (lv_Table = 'CTS_DataCenter.SpecialCustomerClass_BySport_History') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.SpecialCustomerClass_BySport_History As sp WHERE sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_SpecialCustomerClass_BySport_History_Clean;
			CREATE TEMPORARY TABLE Temp_SpecialCustomerClass_BySport_History_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_SpecialCustomerClass_BySport_History_Clean(ID)
            SELECT 	sp.ID
			FROM CTS_DataCenter.SpecialCustomerClass_BySport_History As sp
			WHERE  sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
			DELETE sp
			FROM CTS_DataCenter.SpecialCustomerClass_BySport_History AS sp
				INNER JOIN Temp_SpecialCustomerClass_BySport_History_Clean AS tmp ON tmp.ID = sp.ID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.SpecialCustomerClass_BySport_History'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_SpecialCustomerClass_BySport_History_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CTSCustomerClassificationAgency';
	 END IF;

	 /*************************************** 39. CTS_DataCenter.CTSCustomerClassificationAgency ********************/
    IF (lv_Table = 'CTS_DataCenter.CTSCustomerClassificationAgency') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clss WHERE clss.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassificationAgency_Clean;
			CREATE TEMPORARY TABLE Temp_CTSCustomerClassificationAgency_Clean(
					CustID   			BIGINT UNSIGNED  
				,	ParentID			INT UNSIGNED
                ,	CategoryID			INT
                ,	PRIMARY KEY(CustID, ParentID, CategoryID)
			);
            
            DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassificationAgency_Archive;
			CREATE TEMPORARY TABLE Temp_CTSCustomerClassificationAgency_Archive(
					ArchiveID			BIGINT UNSIGNED PRIMARY KEY
				,	CustID   			BIGINT 
			);

            INSERT IGNORE INTO Temp_CTSCustomerClassificationAgency_Clean(CustID, ParentID, CategoryID)
            SELECT 	clss.CustID
				,	clss.ParentID
                ,	clss.CategoryID
			FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clss
			WHERE  clss.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            INSERT IGNORE INTO Temp_CTSCustomerClassificationAgency_Archive(ArchiveID, CustID)
            SELECT 	arc.ID, arc.CustID
			FROM CTS_DataCenter.ArchiveCustomer_CTSCustomer AS arc 
				INNER JOIN Temp_CustInfo AS temp ON temp.ArchiveID = arc.ID AND arc.CustSubID = 0
			WHERE arc.CategoryID IS NULL;

            IF EXISTS (SELECT 1 FROM Temp_CTSCustomerClassificationAgency_Archive) THEN
				UPDATE CTS_DataCenter.ArchiveCustomer_CTSCustomer AS arc
					INNER JOIN Temp_CTSCustomerClassificationAgency_Archive AS temp ON temp.ArchiveID = arc.ID
					,	LATERAL	(
							SELECT cls.CustID, cls.ParentID, cls.CategoryID
							FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
								INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON cls.CategoryID = cate.CategoryID AND cate.IsActive = 1
							WHERE cls.CustID = arc.CustID
							ORDER BY  cate.CustomerClassPriority ASC 
									, cls.LastModifiedDate DESC
							LIMIT 1
						) AS cate
				SET arc.CategoryID = cate.CategoryID;
            END IF;

            DELETE cl
			FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cl
				INNER JOIN Temp_CTSCustomerClassificationAgency_Clean AS tmp ON tmp.CustID = cl.CustID 
																		AND tmp.ParentID = cl.ParentID
																		AND tmp.CategoryID = cl.CategoryID;
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CTSCustomerClassificationAgency'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CTSCustomerClassificationAgency_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.CTSCustomerClassificationAgency_History';
	 END IF; 

	/*************************************** 40. CTS_DataCenter.CTSCustomerClassificationAgency_History ************/
    IF (lv_Table = 'CTS_DataCenter.CTSCustomerClassificationAgency_History') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS his WHERE his.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassificationAgency_History_Clean;
			CREATE TEMPORARY TABLE Temp_CTSCustomerClassificationAgency_History_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_CTSCustomerClassificationAgency_History_Clean(ID)
            SELECT 	his.ID
			FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS his
			WHERE  his.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE his
			FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS his
			WHERE  his.ID IN (SELECT tmp.ID FROM Temp_CTSCustomerClassificationAgency_History_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.CTSCustomerClassificationAgency_History'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CTSCustomerClassificationAgency_History_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
        SET lv_Table = 'CTS_DataCenter.Customer_FirstTWTaggingCC';
	 END IF; 
	/*************************************** 41. CTS_DataCenter.Customer_FirstTWTaggingCC ******************************/
    IF (lv_Table = 'CTS_DataCenter.Customer_FirstTWTaggingCC') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.Customer_FirstTWTaggingCC AS tag WHERE tag.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_Customer_FirstTWTaggingCC_Clean;
			CREATE TEMPORARY TABLE Temp_Customer_FirstTWTaggingCC_Clean(
					CustID   	BIGINT UNSIGNED PRIMARY KEY 
			);
            
            INSERT IGNORE INTO Temp_Customer_FirstTWTaggingCC_Clean(CustID)
            SELECT 	tag.CustID
			FROM CTS_DataCenter.Customer_FirstTWTaggingCC AS tag
			WHERE  tag.CustID IN (SELECT tmp.CustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            
            DELETE tag
			FROM CTS_DataCenter.Customer_FirstTWTaggingCC AS tag
			WHERE  tag.CustID IN (SELECT tmp.CustID FROM Temp_Customer_FirstTWTaggingCC_Clean AS tmp);
			
			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.Customer_FirstTWTaggingCC'
			WHERE ParameterID = 46;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_Customer_FirstTWTaggingCC_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;


		SET lv_Table = 'CTS_DataCenter.CTSCustomer';
	 END IF;   	

	 /*************************************** 42. CTS_DataCenter.Customer_SpecialLicSubCC ******************************/
    IF (lv_Table = 'CTS_DataCenter.Customer_SpecialLicSubCC') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.Customer_SpecialLicSubCC As sp WHERE sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_Customer_SpecialLicSubCC_Clean;
			CREATE TEMPORARY TABLE Temp_Customer_SpecialLicSubCC_Clean(
					ID   BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_Customer_SpecialLicSubCC_Clean(ID)
            SELECT 	sp.ID
			FROM CTS_DataCenter.Customer_SpecialLicSubCC As sp
			WHERE  sp.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp)
			LIMIT lv_CleanTableBatchSize;
            		
			UPDATE CTS_DataCenter.Customer_SpecialLicSubCC AS sp
				INNER JOIN Temp_Customer_SpecialLicSubCC_Clean AS tmp ON tmp.ID = sp.ID
			SET		sp.IsDisabled = 1
				,	sp.ArchivedDate = lv_CurrentDateTime
			WHERE  sp.IsDisabled = 0;

			UPDATE  CTS_DataCenter.SystemParameter 
			SET ParameterValue = 'CTS_DataCenter.Customer_SpecialLicSubCC'
			WHERE ParameterID = 46;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_Customer_SpecialLicSubCC_Clean;
            
            IF lv_Count >= lv_CleanTableBatchSize THEN
				LEAVE sp;
            END IF;
			
            SET lv_CleanTableBatchSize = lv_CleanTableBatchSize - lv_Count;
        END IF;
        
		SET lv_Table = 'CTS_DataCenter.CTSCustomer';
	 END IF; 
    /*************************************** 43. CTS_DataCenter.CTSCustomer ************************************/
	
	SELECT  GROUP_CONCAT(DISTINCT tmpCus.Recommend) AS CustJson 
	INTO lv_AgentCreditList	
	FROM CTS_DataCenter.CTSCustomer AS tmpCus
	WHERE tmpCus.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp) AND tmpCus.CustSubID = 0 
	AND tmpCus.IsLicensee = 0; 

    DELETE cus
	FROM CTS_DataCenter.CTSCustomer AS cus
	WHERE  cus.CTSCustID IN (SELECT tmp.CTSCustID FROM Temp_CustInfo AS tmp);

	IF lv_AgentCreditList IS NOT NULL THEN        
		CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_CDQueue_Insert(1, lv_AgentCreditList);
    END IF;  
  
    UPDATE  CTS_DataCenter.SystemParameter 
	SET ParameterValue = 'DCS_DataCenter.Association'
	WHERE ParameterID = 46;
    
    SELECT MAX(ArchiveID) 
    INTO lv_NextID
    FROM Temp_CustInfo;
    
    UPDATE  CTS_DataCenter.SystemParameter 
	SET ParameterValue = lv_NextID
	WHERE ParameterID = 45;

	UPDATE CTS_DataCenter.ArchiveCustomer_CTSCustomer AS ar 
	SET	ar.ProcessedDate = lv_CurrentDateTime
    WHERE EXISTS (SELECT 1 FROM Temp_CustInfo AS tmp WHERE ar.ID = tmp.ArchiveID);
    
END$$
DELIMITER ;

