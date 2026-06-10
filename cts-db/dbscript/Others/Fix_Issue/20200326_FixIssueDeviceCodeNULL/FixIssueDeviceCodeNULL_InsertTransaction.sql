DELIMITER $$

DROP PROCEDURE IF EXISTS DCS_DataCenter.zzzFixIssueDeviceCodeNULL_InsertTransaction$$

CREATE PROCEDURE DCS_DataCenter.zzzFixIssueDeviceCodeNULL_InsertTransaction()
BEGIN
/*
	Created: 20190730@Casey.Huynh
	Task : FixIssueDeviceCodeNULL
	DB: DCS_DataCenter
	Original:
		
*/  	

    DROP TEMPORARY TABLE IF EXISTS Temp_TransID;
    CREATE TEMPORARY TABLE Temp_TransID
    (
			TransID BIGINT UNSIGNED
    );
    
   
    # =================================================================
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  
    WHILE EXISTS (SELECT TransID FROM zzzFixIssueDeviceCodeNULL WHERE FixedStatus = 0)
    DO		
			
			INSERT INTO Temp_TransID(TransID)
			SELECT 	TransID
            FROM 	DCS_DataCenter.zzzFixIssueDeviceCodeNULL
            WHERE 	FixedStatus = 0
            LIMIT 	1000;
			SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
            
            DELETE 	ts
            FROM		DCS_DataCenter.Transaction07 AS ts
            INNER JOIN	Temp_TransID 			AS tmp
						ON	ts.TransID = tmp.TransID;
			
            SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
            INSERT IGNORE INTO DCS_DataCenter.Transaction
			(TransID,
			LoginName,
			TransTime,
			SubscriberID,
			AccountID,
			URLID,
			DeviceCodeID,
			DeviceID,
			FirstDeviceCode,
			DeviceStatus,
			DeviceFingerprintID,
			UserAgentKey,
			IP,
			IPID,
			ActionResultID,
			Flagged,
			PluginID,
			TransStatus,
			CreatedDate,
			InsertTime,
			DeviceCode,
			FingerprintCode,
			FingerprintMoreInfo)
            SELECT ft.TransID,
			ft.LoginName,
			ft.TransTime,
			ft.SubscriberID,
			ft.AccountID,
			ft.URLID,
			ft.DeviceCodeID,
			ft.DeviceID,
			ft.FirstDeviceCode,
			ft.DeviceStatus,
			ft.DeviceFingerprintID,
			ft.UserAgentKey,
			ft.IP,
			ft.IPID,
			ft.ActionResultID,
			ft.Flagged,
			ft.PluginID,
			ft.TransStatus,
			ft.CreatedDate,
			ft.InsertTime,
			ft.DeviceCode,
			ft.FingerprintCode,
			ft.FingerprintMoreInfo
            FROM		DCS_DataCenter.zzzFixIssueDeviceCodeNULL AS  ft
            INNER JOIN	Temp_TransID 			AS tmp
						ON	ft.TransID = tmp.TransID;    
                        
            SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
			UPDATE 		DCS_DataCenter.zzzFixIssueDeviceCodeNULL AS ft
            INNER JOIN	Temp_TransID 			AS tmp
						ON	ft.TransID = tmp.TransID
			SET			FixedStatus = 1;
            
            TRUNCATE TABLE Temp_TransID;
            SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    END WHILE;
END$$
DELIMITER ;
