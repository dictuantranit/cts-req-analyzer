DELIMITER $$

USE DCS_DataCenter$$

DROP PROCEDURE IF EXISTS DCS_DataCenter.zzzIssueDI_DeviceCode_Remove$$

CREATE PROCEDURE DCS_DataCenter.zzzIssueDI_DeviceCode_Remove()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong DI. Remove Record From 03-13 to 04-01
		DB:			DCS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
        
        SELECT 	COUNT(1), MIN(DeviceCodeID), MAX(DeviceCodeID)
		FROM	DCS_DataCenter.DeviceCode ad
		WHERE	ad.CreatedDate >= '2020-03-13' AND ad.CreatedDate < '2020-04-02';
		# 859192	12557267	14278302	
        
	*/
    
    DECLARE vr_DeviceCodeID BIGINT;
    
    SET vr_DeviceCodeID = 12860097;    
   
   DROP TEMPORARY TABLE IF EXISTS Temp_DeviceCodeID;
   CREATE TEMPORARY TABLE Temp_DeviceCodeID
   (
		DeviceCodeID	BIGINT
   );   
   
   WHILE EXISTS (SELECT DeviceCodeID
        FROM 	DCS_DataCenter.DeviceCode ad
        WHERE 	ad.CreatedDate >= '2020-03-13' AND ad.CreatedTime <= '2020-04-01 00:00:00' AND DeviceCodeID > vr_DeviceCodeID)  
   DO
		
        SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        
        TRUNCATE TABLE Temp_DeviceCodeID;
		INSERT INTO Temp_DeviceCodeID(DeviceCodeID)
        SELECT 	DeviceCodeID
        FROM 	DCS_DataCenter.DeviceCode ad
        WHERE 	ad.CreatedDate >= '2020-03-13' AND ad.CreatedTime <= '2020-04-01 00:00:00' AND DeviceCodeID > vr_DeviceCodeID
        LIMIT	2000;

        INSERT IGNORE INTO DCS_DataCenter.zzzIssueDI_DeviceCode
		SELECT 		ad.*
        FROM 		DCS_DataCenter.DeviceCode AS ad
        INNER JOIN	DCS_DataCenter.Temp_DeviceCodeID	AS ta 
					ON ad.DeviceCodeID = ta.DeviceCodeID
		LIMIT 		2000;
          
		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        
		DELETE 		ad
		FROM 		DCS_DataCenter.DeviceCode AS ad
        INNER JOIN	Temp_DeviceCodeID	AS ta 
					ON ad.DeviceCodeID = ta.DeviceCodeID;
      
		SET vr_DeviceCodeID = (SELECT MAX(DeviceCodeID) FROM Temp_DeviceCodeID);
	END WHILE;
END$$

DELIMITER ;