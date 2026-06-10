DELIMITER $$

USE DCS_DataCenter$$

DROP PROCEDURE IF EXISTS DCS_DataCenter.zzzIssueDI_Device_RemoveUM$$

CREATE PROCEDURE DCS_DataCenter.zzzIssueDI_Device_Remove_UM()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong DI. Remove Record From 03-13 to 04-01
		DB:			DCS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
        
        SELECT 	COUNT(1), MIN(DeviceID), MAX(DeviceID)
		FROM	DCS_DataCenter.Device ad
		WHERE	ad.CreatedDate >= '2020-04-01' AND ad.CreatedTime <= '2020-04-01 5:00:00';
		#10141	7422656	7438793
	*/
    
    DECLARE vr_DeviceID BIGINT;
    
    SET vr_DeviceID = 7422655;
    
   
   DROP TEMPORARY TABLE IF EXISTS Temp_DeviceID;
   CREATE TEMPORARY TABLE Temp_DeviceID
   (
		DeviceID	BIGINT
   );
   
   
   WHILE EXISTS (SELECT DeviceID
        FROM 	DCS_DataCenter.Device ad
        WHERE 	ad.CreatedDate >= '2020-04-01' AND ad.CreatedTime <= '2020-04-01 5:00:00' AND DeviceID > vr_DeviceID)  
   DO
		
        SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        
        TRUNCATE TABLE Temp_DeviceID;
		INSERT INTO Temp_DeviceID(DeviceID)
        SELECT 	DeviceID
        FROM 	DCS_DataCenter.Device ad
        WHERE 	ad.CreatedDate >= '2020-04-01' AND ad.CreatedTime <= '2020-04-01 5:00:00' AND DeviceID > vr_DeviceID
        LIMIT	2000;

        INSERT IGNORE INTO DCS_DataCenter.zzzIssueDI_Device_UM
		SELECT 		ad.*
        FROM 		DCS_DataCenter.Device AS ad
        INNER JOIN	DCS_DataCenter.Temp_DeviceID	AS ta 
					ON ad.DeviceID = ta.DeviceID;
          
		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        
		DELETE 		ad
		FROM 		DCS_DataCenter.Device AS ad
        INNER JOIN	Temp_DeviceID	AS ta 
					ON ad.DeviceID = ta.DeviceID;
      
		SET vr_DeviceID = (SELECT MAX(DeviceID) FROM Temp_DeviceID);
	END WHILE;
END$$

DELIMITER ;