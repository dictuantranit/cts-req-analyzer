DELIMITER $$

USE DCS_DataCenter$$

DROP PROCEDURE IF EXISTS DCS_DataCenter.zzzIssueAss_Remove_20200301_26_DCS_Transaction_BK01_Update$$

CREATE PROCEDURE DCS_DataCenter.zzzIssueAss_Remove_20200301_26_DCS_Transaction_BK01_Update()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		IssueRemoveAss_From20200301To20200326
		DB:			DCS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	  DECLARE vr_LastTransID BIGINT UNSIGNED;
   DROP TEMPORARY TABLE IF EXISTS Temp_TransID;
   CREATE TEMPORARY TABLE Temp_TransID
   (
		TransID	BIGINT
   );

   SET vr_LastTransID = (SELECT LastTransID FROM DCS_DataCenter.zzzIssueAss_Transaction_BK01 LIMIT 1); 
    
   WHILE EXISTS (SELECT 1 FROM DCS_DataCenter.Transaction_BK01 WHERE TransID > vr_LastTransID AND CreatedDate > '2020-02-29' AND CreatedDate < '2020-03-27' AND DeviceID > 0)  
   DO
	
		INSERT INTO Temp_TransID(TransID)
        SELECT 	TransID
        FROM 	DCS_DataCenter.Transaction_BK01
		WHERE 	TransID > vr_LastTransID
				AND CreatedDate > '2020-02-29' AND CreatedDate < '2020-03-27'
				AND  DeviceID > 0
		ORDER BY TransID ASC
		LIMIT 20000;
        
		UPDATE	 DCS_DataCenter.Transaction_BK01 AS tsbk
        INNER JOIN Temp_TransID AS tmt
					ON tmt.TransID = tsbk.TransID
        SET		DeviceID = 0
				, DeviceCodeID = NULL
                , FirstDeviceCode = NULL
                , DeviceStatus = NULL
                , DeviceFingerprintID = NULL;
		
		SET vr_LastTransID = (SELECT Max(TransID) FROM Temp_TransID);
        
        UPDATE	DCS_DataCenter.zzzIssueAss_Transaction_BK01
        SET TotalTrans = TotalTrans + 20000
			, LastTransID = vr_LastTransID; 
            
        TRUNCATE  TABLE Temp_TransID;        
	END WHILE;
END$$

DELIMITER ;