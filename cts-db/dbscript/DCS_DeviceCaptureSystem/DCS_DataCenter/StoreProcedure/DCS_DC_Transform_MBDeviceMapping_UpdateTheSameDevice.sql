/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBDeviceMapping_UpdateTheSameDevice`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBDeviceMapping_UpdateTheSameDevice`(
		IN ip_TableName VARCHAR(50)
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20241202@Lando.Vu
	    Task : Transform Transaction
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 202401202@Lando.Vu: Transform to MBTransaction [Redmine ID: #213401]
            
	    Param's Explanation (filtered by):
        
        Example:
			DROP TABLE IF EXISTS Temp_NewDevice;
			CREATE TEMPORARY TABLE Temp_NewDevice(
					ID								BIGINT UNSIGNED NOT NULL PRIMARY KEY
				,	SameDeviceID					BIGINT UNSIGNED DEFAULT 0
				,	RecoverType						SMALLINT UNSIGNED DEFAULT 0
				
				,	FirstDeviceID					BIGINT UNSIGNED
				,	SecondDeviceID					BIGINT UNSIGNED
				,	ThirdDeviceID					BIGINT UNSIGNED
			);
            
            INSERT INTO Temp_NewDevice(ID, FirstDeviceID, SecondDeviceID, ThirdDeviceID)
            VALUES(1, 1, 1, 1), (2, 1, 1, 2), (3, 2, 2, 3), (4, 2, 3, 4), (5, 3, 4, 4);
            
			SET sql_safe_updates = 0;
			CALL DCS_DC_Transform_MBDeviceMapping_UpdateTheSameDevice('Temp_NewDevice');
            select * from Temp_NewDevice;
	*/
    DECLARE CONST_RECOVERTYPE_FIRSTRULE		SMALLINT DEFAULT 1;
    DECLARE CONST_RECOVERTYPE_SECONDRULE	SMALLINT DEFAULT 2;
    DECLARE CONST_RECOVERTYPE_THIRDRULE		SMALLINT DEFAULT 3;
    
    DECLARE lv_CurrentID 					BIGINT UNSIGNED DEFAULT 0;
    DECLARE lv_MaxID 						BIGINT UNSIGNED;
    DECLARE lv_CurrentFirstDeviceID 		BIGINT UNSIGNED;
    DECLARE lv_CurrentSecondDeviceID 		BIGINT UNSIGNED;
    DECLARE lv_CurrentThirdDeviceID 		BIGINT UNSIGNED;
    DECLARE lv_SameDeviceID 				BIGINT UNSIGNED;
    DECLARE lv_RecoverType		 			SMALLINT; /* 1: FirstRule, 2: SecondRule, 2: ThirdRule */

	
    /********************** Error handler ***********************************/
	DECLARE lv_SQLState CHAR(5);
	DECLARE lv_ErrorCode INT;
	DECLARE lv_ErrorMessage TEXT;
	DECLARE lv_FullMessage TEXT;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
	BEGIN
		GET DIAGNOSTICS CONDITION 1
			lv_SQLState = RETURNED_SQLSTATE,
			lv_ErrorCode = MYSQL_ERRNO,
			lv_ErrorMessage = MESSAGE_TEXT;

		SET lv_FullMessage = CONCAT('SQL:', lv_SQLState, ', code:', lv_ErrorCode, ', Msg:', lv_ErrorMessage);
        
		INSERT INTO CTS_Log.FPSLog(SpName, JsonString, OtherText, InsertTime)
		SELECT 'DCS_DC_Transform_MBDeviceMapping_UpdateTheSameDevice', NULL, lv_FullMessage, CURRENT_TIMESTAMP();
        
        RESIGNAL;
	END;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_SameMBDevice;
    
	CREATE TEMPORARY TABLE Temp_SameMBDevice(
			ID						BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	SameDeviceID			BIGINT UNSIGNED
		,	RecoverType				SMALLINT DEFAULT 0
		,	FirstDeviceID			BIGINT UNSIGNED
		,	SecondDeviceID			BIGINT UNSIGNED
		,	ThirdDeviceID			BIGINT UNSIGNED
	);
    
	SET @sql = CONCAT('INSERT INTO Temp_SameMBDevice(ID, FirstDeviceID, SecondDeviceID, ThirdDeviceID) 
						SELECT 	ID
							,	FirstDeviceID
							,	SecondDeviceID
							,	ThirdDeviceID
                        FROM ', ip_TableName, 
					' 	WHERE FirstDeviceID > 0
							OR SecondDeviceID > 0
							OR ThirdDeviceID > 0
                            ');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    ALTER TABLE Temp_SameMBDevice
    ADD KEY IX_Temp_SameMBDevice_FirstDeviceID(FirstDeviceID),
    ADD KEY IX_Temp_SameMBDevice_SecondDeviceID(SecondDeviceID),
    ADD KEY IX_Temp_SameMBDevice_ThirdDeviceID(ThirdDeviceID);
    
    SELECT MAX(ID) INTO lv_MaxID FROM Temp_SameMBDevice;

    WHILE lv_CurrentID < lv_MaxID DO
        SELECT 	ID
			,	FirstDeviceID
            ,	SecondDeviceID
            ,	ThirdDeviceID
            ,	SameDeviceID
            ,	RecoverType
        INTO lv_CurrentID, lv_CurrentFirstDeviceID, lv_CurrentSecondDeviceID, lv_CurrentThirdDeviceID, lv_SameDeviceID, lv_RecoverType
        FROM Temp_SameMBDevice
        WHERE ID > lv_CurrentID
        ORDER BY ID ASC
        LIMIT 1;

        SELECT	MIN(SameDeviceID)
			,	MAX(CASE WHEN ID IS NOT NULL THEN CONST_RECOVERTYPE_FIRSTRULE ELSE 0 END) AS RecoverType
        INTO lv_SameDeviceID, lv_RecoverType
        FROM Temp_SameMBDevice
        WHERE FirstDeviceID <> 0
			AND FirstDeviceID = lv_CurrentFirstDeviceID
			AND ID < lv_CurrentID;
		
        IF lv_SameDeviceID IS NULL THEN
			SELECT 	MIN(SameDeviceID)
				,	MAX(CASE WHEN ID IS NOT NULL THEN CONST_RECOVERTYPE_SECONDRULE ELSE 0 END) AS RecoverType
			INTO lv_SameDeviceID, lv_RecoverType
			FROM Temp_SameMBDevice
			WHERE SecondDeviceID <> 0
				AND SecondDeviceID = lv_CurrentSecondDeviceID
				AND ID < lv_CurrentID;

			IF lv_SameDeviceID IS NULL THEN
				SELECT 	MIN(SameDeviceID)
					,	MAX(CASE WHEN ID IS NOT NULL THEN CONST_RECOVERTYPE_THIRDRULE ELSE 0 END) AS RecoverType
				INTO lv_SameDeviceID, lv_RecoverType
				FROM Temp_SameMBDevice
				WHERE ThirdDeviceID <> 0
					AND ThirdDeviceID = lv_CurrentThirdDeviceID
					AND ID < lv_CurrentID;
				
				IF lv_SameDeviceID IS NULL THEN
					SET lv_SameDeviceID = lv_CurrentID;
				END IF;
			END IF;
        END IF;
        
        UPDATE Temp_SameMBDevice
        SET SameDeviceID = lv_SameDeviceID,
			RecoverType = lv_RecoverType
        WHERE ID = lv_CurrentID;
    END WHILE;
        
	SET @sql = CONCAT('UPDATE ', ip_TableName,' AS tmp
							INNER JOIN Temp_SameMBDevice AS tmpNd ON tmpNd.ID = tmp.ID
						SET tmp.SameDeviceID = IFNULL(tmpNd.SameDeviceID, 0),
							tmp.RecoverType = IFNULL(tmpNd.RecoverType, 0)');
	PREPARE stmt FROM @sql;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;