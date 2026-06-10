/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_FP_DeviceMappingUpdateTheSameDevice`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_FP_DeviceMappingUpdateTheSameDevice`(
		IN ip_TableName VARCHAR(50)
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
		    - 20241028@Jonathan.Doan: Fix SP SameDevice = 0 [RedmineID: #212641]
	    Param's Explanation (filtered by):
        
        Example:
			DROP TABLE IF EXISTS Temp_NewDevice;
			CREATE TEMPORARY TABLE Temp_NewDevice(
					RawTransID									BIGINT UNSIGNED NOT NULL PRIMARY KEY
				,	SameDeviceWithRawTransID					BIGINT UNSIGNED DEFAULT 0
				,	RecoverType									SMALLINT UNSIGNED DEFAULT 0
				
				,	FirstDeviceID								BIGINT UNSIGNED
				,	SecondDeviceID								BIGINT UNSIGNED
			);
            
            INSERT INTO Temp_NewDevice(RawTransID, FirstDeviceID, SecondDeviceID)
            VALUES(1, 1, 1),(2, 1, 1),(3, 2, 2),(4, 2, 3);
            
			SET sql_safe_updates = 0;
			CALL DCS_DC_Transform_FP_DeviceMappingUpdateTheSameDevice('Temp_NewDevice');
            select * from Temp_NewDevice;
	*/
    DECLARE CONST_RECOVERTYPE_FIRSTRULE		SMALLINT DEFAULT 1;
    DECLARE CONST_RECOVERTYPE_SECONDRULE	SMALLINT DEFAULT 2;
    
    DECLARE lv_CurrentID 					BIGINT UNSIGNED DEFAULT 0;
    DECLARE lv_MaxID 						BIGINT UNSIGNED;
    DECLARE lv_CurrentFirstDeviceID 		BIGINT UNSIGNED;
    DECLARE lv_CurrentSecondDeviceID 		BIGINT UNSIGNED;
    DECLARE lv_SameDeviceWithID 			BIGINT UNSIGNED;
    DECLARE lv_RecoverType		 			SMALLINT; /* 1: FirstRule, 2: SecondRule */

	DROP TEMPORARY TABLE IF EXISTS Temp_SameDevice;
	DROP TEMPORARY TABLE IF EXISTS Temp_SameDevice1;
    
	CREATE TEMPORARY TABLE Temp_SameDevice(
			ID									BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	SameDeviceWithID					BIGINT UNSIGNED
		,	RecoverType							SMALLINT UNSIGNED DEFAULT 0

		,	FirstDeviceID						BIGINT UNSIGNED
		,	SecondDeviceID						BIGINT UNSIGNED
	);
    
	SET @sql = CONCAT('INSERT INTO Temp_SameDevice(ID, FirstDeviceID, SecondDeviceID) 
						SELECT 	RawTransID AS ID
							,	FirstDeviceID
							,	SecondDeviceID
                        FROM ', ip_TableName, 
					' 	WHERE FirstDeviceID IS NOT NULL
							OR SecondDeviceID IS NOT NULL');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    ALTER TABLE Temp_SameDevice
    ADD KEY IX_Temp_SameDevice_FirstDeviceID(FirstDeviceID),
    ADD KEY IX_Temp_SameDevice_SecondDeviceID(SecondDeviceID);
    
    SELECT MAX(ID) INTO lv_MaxID FROM Temp_SameDevice;

    WHILE lv_CurrentID < lv_MaxID DO
        SELECT 	ID
			,	FirstDeviceID
            ,	SecondDeviceID
            ,	SameDeviceWithID
            ,	RecoverType
        INTO lv_CurrentID, lv_CurrentFirstDeviceID, lv_CurrentSecondDeviceID, lv_SameDeviceWithID, lv_RecoverType
        FROM Temp_SameDevice
        WHERE ID > lv_CurrentID
        ORDER BY ID ASC
        LIMIT 1;

        SELECT	MIN(SameDeviceWithID)
			,	MAX(CASE WHEN ID IS NOT NULL THEN CONST_RECOVERTYPE_FIRSTRULE ELSE 0 END) AS RecoverType
        INTO lv_SameDeviceWithID, lv_RecoverType
        FROM Temp_SameDevice
        WHERE FirstDeviceID <> 0
			AND FirstDeviceID = lv_CurrentFirstDeviceID
			AND ID < lv_CurrentID;
		
        IF lv_SameDeviceWithID IS NULL THEN
			SELECT 	MIN(SameDeviceWithID)
				,	MAX(CASE WHEN ID IS NOT NULL THEN CONST_RECOVERTYPE_SECONDRULE ELSE 0 END) AS RecoverType
			INTO lv_SameDeviceWithID, lv_RecoverType
			FROM Temp_SameDevice
			WHERE SecondDeviceID <> 0
				AND SecondDeviceID = lv_CurrentSecondDeviceID
				AND ID < lv_CurrentID;
			
			IF lv_SameDeviceWithID IS NULL THEN
				SET lv_SameDeviceWithID = lv_CurrentID;
			END IF;
        END IF;
        
        UPDATE Temp_SameDevice
        SET SameDeviceWithID = lv_SameDeviceWithID,
			RecoverType = lv_RecoverType
        WHERE ID = lv_CurrentID;
        
		SET @sql = CONCAT('UPDATE ', ip_TableName,' AS tmp
								INNER JOIN Temp_SameDevice AS tmpNd ON tmpNd.ID = tmp.RawTransID
							SET tmp.SameDeviceWithRawTransID = IFNULL(tmpNd.SameDeviceWithID, 0),
								tmp.RecoverType = IFNULL(tmpNd.RecoverType, 0)');
		PREPARE stmt FROM @sql;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
        
    END WHILE;
END$$

DELIMITER ;
