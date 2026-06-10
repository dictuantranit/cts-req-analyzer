DELIMITER $$
DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_DC_ArchiveData_Transaction07_Move$$
CREATE DEFINER=`fps`@`%` PROCEDURE DCS_DataCenter.DCS_DC_ArchiveData_Transaction07_Move(IN ip_ArchivedDate DATETIME, IN ip_NoOfRecord INT, OUT ip_Completed BOOLEAN)
BEGIN
	/*
	Created: 	20200723@Casey.Huynh
	Task : 		Enhance Archive Data From Transaction07 to Transaction90
	DB: 		DCS_DataCenter
	Original:

	Revisions:
	Param's Explanation (filtered by):
	*/
    DECLARE vrArchivedDate  DATETIME;
	DECLARE vrMinID  BIGINT UNSIGNED;
    DECLARE vrMaxID  BIGINT UNSIGNED;
    #=========================================================    
	
    SET ip_Completed = FALSE;
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    
    SET vrMinID = (SELECT MAX(ToTransId) FROM DCS_DataCenter.ArchiveTransLog WHERE ArchivedDate = ip_ArchivedDate AND Moved = 1);
	SET vrMaxID = (SELECT ToTransID FROM DCS_DataCenter.ArchiveHistory AS ah  WHERE ah.ArchivedDate = ip_ArchivedDate);
    
     SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ ;
    
    IF(vrMinID IS NULL)
    THEN
		SET 	vrMinID = (SELECT FromTransID-1 FROM DCS_DataCenter.ArchiveHistory AS ah  WHERE ah.ArchivedDate = ip_ArchivedDate);
        UPDATE 	DCS_DataCenter.ArchiveHistory
        SET		StartTime = NOW()
        WHERE  	ArchivedDate = ip_ArchivedDate;	
    END IF;

    IF (vrMinID = vrMaxID) 
    THEN
		UPDATE DCS_DataCenter.ArchiveHistory
		SET		Status = 1
				, MovedEndTime = NOW()
        WHERE  	ArchivedDate = ip_ArchivedDate;
        
		SET ip_Completed = TRUE;
	ELSE
		SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
		INSERT IGNORE INTO  DCS_DataCenter.Transaction90(TransID, LoginName, TransTime, SubscriberID, AccountID
					, URLID, DeviceCodeID, DeviceID, FirstDeviceCode, DeviceStatus, DeviceFingerprintID
					, UserAgentKey, IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, InsertTime)        
		SELECT 		ts07.TransID, ts07.LoginName, ts07.TransTime, ts07.SubscriberID, ts07.AccountID
					, ts07.URLID, ts07.DeviceCodeID, ts07.DeviceID, ts07.FirstDeviceCode, ts07.DeviceStatus, ts07.DeviceFingerprintID
					, ts07.UserAgentKey, ts07.IP, ts07.IPID, ts07.ActionResultID, ts07.Flagged, ts07.PluginID, ts07.TransStatus, ts07.CreatedDate, ts07.InsertTime
		FROM		DCS_DataCenter.Transaction07 AS ts07        
		WHERE 		ts07.CreatedDate = ip_ArchivedDate 
					AND ts07.TransId > vrMinID
        ORDER BY 	ts07.TransId
        LIMIT 		ip_NoOfRecord;  
        
        SET vrMaxID = (SELECT  Max(TransID) FROM DCS_DataCenter.Transaction90 WHERE CreatedDate = ip_ArchivedDate);       
        
        SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ ;

        IF (vrMinID < vrMaxID)
        THEN
			INSERT INTO DCS_DataCenter.ArchiveTransLog(FromTransId, ToTransId,  Moved, Deleted, ArchivedDate)
			VALUES(vrMinID + 1, vrMaxID, 1, FALSE, ip_ArchivedDate);
            SET vrMinID = vrMaxID;
        END IF;
    END IF;

END$$
DELIMITER ;

