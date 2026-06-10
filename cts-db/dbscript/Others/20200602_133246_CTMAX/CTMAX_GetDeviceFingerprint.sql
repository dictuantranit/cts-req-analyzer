DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.CTMAX_GetDeviceFingerprint$$

CREATE PROCEDURE CTS_Adhoc.CTMAX_GetDeviceFingerprint()
BEGIN
	/*
		Created:	20200519@Casey
		Task:		Remove Account NOT In CTS
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
    DECLARE fromID BIGINT DEFAULT 2796767 ;
    DECLARE toID BIGINT;
    
   /* SELECT 	MIN(DeviceID), MAX(DeviceID)
    INTO 	fromID, toID
    FROM 	CTS_Adhoc.csCTMAX_Device_bk AS dev; #2796768	12187138;
    */
   

	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
     WHILE  fromID <= 12187138 DO
        
        SET toID = (SELECT MAX(a.DeviceID) 
					FROM (	SELECT DeviceID 
							FROM CTS_Adhoc.csCTMAX_Device_bk AS dev
							WHERE DeviceID > fromID
							ORDER BY DeviceID
							LIMIT 10000) a
					);
        SELECT fromID, toID;
		INSERT INTO CTS_Adhoc.csCTMAX_DeviceFingerprint
		SELECT		def.*
		FROM 		DCS_DataCenter.DeviceFingerprint AS def
		INNER JOIN 	CTS_Adhoc.csCTMAX_Device_bk AS dev
					ON def.DeviceID = dev.DeviceID
		WHERE		dev.DeviceID BETWEEN fromID AND toID;
        
        SET fromID = toID;
        
	END WHILE;
END$$
DELIMITER ;