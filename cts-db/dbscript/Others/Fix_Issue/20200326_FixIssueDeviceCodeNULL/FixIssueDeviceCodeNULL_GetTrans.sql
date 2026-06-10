DELIMITER $$

DROP PROCEDURE IF EXISTS DCS_DataCenter.zzzFixIssueDeviceCodeNULL_GetTrans$$

CREATE PROCEDURE DCS_DataCenter.zzzFixIssueDeviceCodeNULL_GetTrans()
BEGIN
/*
	Created: 20190730@Casey.Huynh
	Task : FixIssueDeviceCodeNULL
	DB: DCS_DataCenter
	Original:
		
*/  	
	DECLARE	var_MaxTrans BIGINT UNSIGNED;

    
    SET var_MaxTrans = (SELECT MAX(TransID) FROM DCS_DataCenter.zzzFixIssueDeviceCodeNULL); #Min(615491748)
   
    # =================================================================
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;     
    WHILE EXISTS(	SELECT 	TransID
			FROM	DCS_DataCenter.Transaction_temp AS tt	
            WHERE	DeviceCode IS NOT NULL
					AND tt.CreatedDate < '2020-03-01'
                    AND tt.TransID > var_MaxTrans)
    DO		
			SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;    
			INSERT IGNORE INTO DCS_DataCenter.zzzFixIssueDeviceCodeNULL(
						TransID,LoginName,TransTime,SubscriberID,AccountID,URLID,DeviceCodeID,DeviceID,FirstDeviceCode,DeviceStatus,DeviceFingerprintID
						,UserAgentKey,IP,IPID,ActionResultID,Flagged,PluginID,TransStatus,CreatedDate,InsertTime,DeviceCode,FingerprintCode,FingerprintMoreInfo)           
			SELECT		tt.TransID, tt.LoginName, tt.TransTime, tt.SubscriberID, tt.AccountID, tt.URLID, tt.DeviceCodeID, tt.DeviceID, tt.FirstDeviceCode, tt.DeviceStatus, tt.DeviceFingerprintID
						, tt.UserAgentKey, tt.IP, tt.IPID, tt.ActionResultID, tt.Flagged, tt.PluginID, tt.TransStatus, tt.CreatedDate, tt.InsertTime, tt.DeviceCode, tt.FingerprintCode, tt.FingerprintMoreInfo
			FROM 		DCS_DataCenter.Transaction_temp AS tt
			WHERE		tt.DeviceCode IS NOT NULL
                        AND tt.CreatedDate < '2020-03-01'
                        AND tt.TransID > var_MaxTrans
			LIMIT 		1000;  
            
			SET var_MaxTrans 	= (SELECT MAX(TransID) FROM DCS_DataCenter.zzzFixIssueDeviceCodeNULL);
			SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;    
    END WHILE;
END$$
DELIMITER ;
