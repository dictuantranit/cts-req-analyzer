/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_FP_DeviceEvolutionInsert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_FP_DeviceEvolutionInsert`(
    IN ip_DeviceEvolutionJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20240729@Jonathan.Doan
	    Task : Change Data Flow Ver. 6
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20240729@Jonathan.Doan: Created [RedmineID: #206403]
	    Param's Explanation (filtered by):
        
        Example:
			SET sql_safe_updates = 0;
			CALL DCS_DC_Transform_FP_DeviceEvolutionInsert('[{"FPDeviceFingerprintAccountID":2,"EvolveByID":1}]');
	*/
    DECLARE CONST_MINID_FP_DEVICEEVOLUTION	INT DEFAULT 23;
    
    DECLARE lv_CurrentDate 					TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
	DECLARE lv_Max_FP_DeviceEvolutionID  	BIGINT UNSIGNED;
    
    DECLARE lv_CurrentID 					INT DEFAULT 0;
    DECLARE lv_EvolveByID					BIGINT UNSIGNED;
    DECLARE lv_EvolveID						BIGINT UNSIGNED;
    DECLARE lv_MaxID 						INT;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_DeviceEvolution;
	DROP TEMPORARY TABLE IF EXISTS Temp_DeviceEvolutionSequential;
    
	CREATE TEMPORARY TABLE Temp_DeviceEvolution(
			FPDeviceFingerprintAccountID	BIGINT UNSIGNED    	NOT NULL PRIMARY KEY
		,	EvolveByID		 				BIGINT UNSIGNED    	NOT NULL DEFAULT 0
		,	EvolveID 						BIGINT UNSIGNED 	NOT NULL DEFAULT 0
    );
    
	CREATE TEMPORARY TABLE Temp_DeviceEvolutionSequential(
			FPDeviceFingerprintAccountID	BIGINT UNSIGNED    	NOT NULL PRIMARY KEY
		,	EvolveID 						BIGINT UNSIGNED 	NOT NULL DEFAULT 0
    );
    
    
    INSERT IGNORE INTO Temp_DeviceEvolution(FPDeviceFingerprintAccountID, EvolveByID)
    SELECT	rt.FPDeviceFingerprintAccountID
		,	rt.EvolveByID
	FROM JSON_TABLE(
			ip_DeviceEvolutionJson,
			 "$[*]" COLUMNS(
						FPDeviceFingerprintAccountID	BIGINT UNSIGNED 	PATH "$.FPDeviceFingerprintAccountID"
					,	EvolveByID						BIGINT UNSIGNED 	PATH "$.EvolveByID"
				)
		   ) AS rt;

	/*==== Add Index ====*/
	ALTER TABLE Temp_DeviceEvolution
	ADD INDEX IX_Temp_DeviceEvolution_EvolveByID (EvolveByID);
	
	
    UPDATE Temp_DeviceEvolution AS tmp
	SET tmp.EvolveID = tmp.FPDeviceFingerprintAccountID
    WHERE EvolveByID = 0
		AND EvolveID = 0;
	
    UPDATE Temp_DeviceEvolution AS tmp
		INNER JOIN DCS_DataCenter.FP_DeviceFingerprintAccount AS dfa ON dfa.ID = tmp.EvolveByID
	SET tmp.EvolveID = dfa.EvolveID
    WHERE tmp.EvolveID = 0;
    
    SELECT 	MIN(FPDeviceFingerprintAccountID) AS MinID
		,	MAX(FPDeviceFingerprintAccountID) AS MaxID
    INTO lv_CurrentID, lv_MaxID
    FROM Temp_DeviceEvolution;
    
    WHILE lv_CurrentID < lv_MaxID DO
		UPDATE Temp_DeviceEvolution AS t1
			INNER JOIN Temp_DeviceEvolutionSequential AS t2 ON t1.EvolveByID = t2.FPDeviceFingerprintAccountID
		SET t1.EvolveID = t2.EvolveID
		WHERE t1.EvolveID = 0;
        
        INSERT INTO Temp_DeviceEvolutionSequential(FPDeviceFingerprintAccountID, EvolveID)
        SELECT	FPDeviceFingerprintAccountID
            ,	EvolveID
        FROM Temp_DeviceEvolution
        WHERE FPDeviceFingerprintAccountID = lv_CurrentID;
        
        SELECT MIN(FPDeviceFingerprintAccountID)
		INTO lv_CurrentID
		FROM Temp_DeviceEvolution
		WHERE FPDeviceFingerprintAccountID > lv_CurrentID;
    END WHILE;
    
	UPDATE Temp_DeviceEvolution AS t1
		INNER JOIN Temp_DeviceEvolutionSequential AS t2 ON t1.EvolveByID = t2.FPDeviceFingerprintAccountID
	SET t1.EvolveID = t2.EvolveID
	WHERE t1.EvolveID = 0;
    
    /*==== Update Main Table ====*/
    UPDATE DCS_DataCenter.FP_DeviceFingerprintAccount AS dfa
		INNER JOIN Temp_DeviceEvolution AS tmp ON tmp.FPDeviceFingerprintAccountID = dfa.ID
	SET dfa.EvolveByID = tmp.EvolveByID,
		dfa.EvolveID = tmp.EvolveID,
		dfa.EvolveTime = lv_CurrentDate;
    
    /*****UPDATE MaxTransID in SystemSetting****************************************************/
    SET lv_Max_FP_DeviceEvolutionID = (SELECT MAX(FPDeviceFingerprintAccountID) FROM Temp_DeviceEvolution);
    
    IF lv_Max_FP_DeviceEvolutionID IS NOT NULL AND lv_Max_FP_DeviceEvolutionID > 0 THEN
		UPDATE DCS_DataCenter.SystemSetting AS sys
		SET sys.VValue = CONCAT('', lv_Max_FP_DeviceEvolutionID),
		    sys.UpdatedTime = lv_CurrentDate
		WHERE ID = CONST_MINID_FP_DEVICEEVOLUTION;
    END IF;
    
END$$

DELIMITER ;