DELIMITER $$

USE DCS_DataCenter$$

DROP PROCEDURE IF EXISTS DCS_DataCenter.zzzIssueDI_DeviceFingerprint_Remove$$

CREATE PROCEDURE DCS_DataCenter.zzzIssueDI_DeviceFingerprint_Remove()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong DI. Remove Record From 03-13 to 04-01
		DB:			DCS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
        
        SELECT 	COUNT(1), MIN(DeviceFingerprintID), MAX(DeviceFingerprintID)
		FROM	DCS_DataCenter.DeviceFingerprint ad
		WHERE	ad.CreatedDate >= '2020-03-13' AND ad.CreatedDate < '2020-04-02'; 
        # 2366688	13229687	16960627

        
	*/
    
    DECLARE vr_DeviceFingerprintID BIGINT;
    
    SET vr_DeviceFingerprintID = 13229686;
    
   
   DROP TEMPORARY TABLE IF EXISTS Temp_DeviceFingerprintID;
   CREATE TEMPORARY TABLE Temp_DeviceFingerprintID
   (
		DeviceFingerprintID	BIGINT
   );
      
   WHILE EXISTS (SELECT DeviceFingerprintID
        FROM 	DCS_DataCenter.DeviceFingerprint ad
        WHERE 	ad.CreatedDate >= '2020-03-13' AND ad.CreatedTime <= '2020-04-01 00:00:00' AND DeviceFingerprintID > vr_DeviceFingerprintID)  
   DO
		TRUNCATE TABLE Temp_DeviceFingerprintID;
        SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;     
      
		INSERT INTO Temp_DeviceFingerprintID(DeviceFingerprintID)
        SELECT 	DeviceFingerprintID
        FROM 	DCS_DataCenter.DeviceFingerprint ad
        WHERE 	ad.CreatedDate >= '2020-03-13' AND ad.CreatedTime <= '2020-04-01 00:00:00' AND DeviceFingerprintID > vr_DeviceFingerprintID
        LIMIT	2000;

        INSERT IGNORE INTO DCS_DataCenter.zzzIssueDI_DeviceFingerprint
		SELECT 		ad.*
        FROM 		DCS_DataCenter.DeviceFingerprint AS ad
        INNER JOIN	DCS_DataCenter.Temp_DeviceFingerprintID	AS ta 
					ON ad.DeviceFingerprintID = ta.DeviceFingerprintID
		LIMIT 		2000;
          
		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        
		DELETE 		ad
		FROM 		DCS_DataCenter.DeviceFingerprint AS ad
        INNER JOIN	Temp_DeviceFingerprintID	AS ta 
					ON ad.DeviceFingerprintID = ta.DeviceFingerprintID;
      
		SET vr_DeviceFingerprintID = (SELECT MAX(DeviceFingerprintID) FROM Temp_DeviceFingerprintID);
	END WHILE;
END$$

DELIMITER ;