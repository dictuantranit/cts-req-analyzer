DELIMITER $$

USE CTS_DataCenter$$

DROP PROCEDURE IF EXISTS DCS_DataCenter.zzzIssueDI_Update_202003013_0401_DCS_Transaction$$

CREATE PROCEDURE DCS_DataCenter.zzzIssueDI_Update_202003013_0401_DCS_Transaction()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong DI. Remove Record From 03-13 to 04-01
		DB:			DCS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
        
        SELECT 	COUNT(1), MIN(TransID), MAX(TransID)
		FROM	DCS_DataCenter.Transaction ad
		WHERE	ad.CreatedDate >= '2020-03-27' AND ad.CreatedDate < '2020-04-02'; # 2869500	690557506	693649302
	*/
   DECLARE vr_LastTransID BIGINT UNSIGNED;

   DROP TEMPORARY TABLE IF EXISTS Temp_TransID;
   CREATE TEMPORARY TABLE Temp_TransID
   (
		TransID	BIGINT
   );

	SET vr_LastTransID = 695664845; 
    
   WHILE EXISTS (SELECT 1 FROM DCS_DataCenter.Transaction WHERE TransID > vr_LastTransID AND CreatedDate >= '2020-03-27' AND TransTime <= '2020-04-01 00:00:00' AND DeviceID = 0 AND DeviceCode IS NOT NULL )  
   DO
		TRUNCATE  TABLE Temp_TransID; 
		SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        
        INSERT INTO Temp_TransID(TransID)
        SELECT 	TransID
        FROM 	DCS_DataCenter.Transaction
		WHERE 	TransID > vr_LastTransID AND CreatedDate >= '2020-03-27' AND TransTime <= '2020-04-01 00:00:00' AND DeviceID = 0  AND DeviceCode IS NOT NULL
		ORDER BY TransID ASC
		LIMIT 1000;
        SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        
		UPDATE	 	DCS_DataCenter.Transaction AS ts
        INNER JOIN 	Temp_TransID AS tmt
					ON tmt.TransID = ts.TransID
        SET		DeviceID = 0
				, DeviceCodeID = NULL
                , FirstDeviceCode = NULL
                , DeviceStatus = NULL
                , DeviceFingerprintID = NULL;
		
		SET vr_LastTransID = (SELECT Max(TransID) FROM Temp_TransID);
        
		
	END WHILE;
END$$

DELIMITER ;