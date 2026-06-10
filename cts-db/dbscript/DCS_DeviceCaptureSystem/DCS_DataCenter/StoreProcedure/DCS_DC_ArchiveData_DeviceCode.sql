/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_DeviceCode`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_DeviceCode`()
    SQL SECURITY INVOKER
sp:BEGIN
	/*
		Created:	20210330@Casey.Huynh
		Task:		Archive Unused DeviceCode
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20210330@Casey.Huynh: Created [Redmine ID: #152454]
            - 20211126@Aries.Nguyen: Enhance performance [Redmine ID: #165165]
		Param's Explanation (filtered by):
	*/ 
	
    DECLARE	lv_DeviceCodeID_Last		BIGINT UNSIGNED; 
    DECLARE	lv_DeviceCodeID_Next		BIGINT UNSIGNED; 
    DECLARE	lv_BatchSize				INT;
	DECLARE	lv_DateValid				DATE;
   
    DROP TEMPORARY TABLE IF EXISTS Temp_DeviceCode;
    CREATE TEMPORARY TABLE Temp_DeviceCode(
			DeviceCodeID  	BIGINT UNSIGNED PRIMARY KEY
        ,   HasPre			INT
        ,   HasNext			INT
    );

    SELECT 	VValue
    INTO	lv_DeviceCodeID_Last
    FROM	DCS_DataCenter.SystemSetting AS ss
    WHERE	ID = 8; 
    
    SELECT 	VValue
    INTO	lv_BatchSize
    FROM	DCS_DataCenter.SystemSetting AS ss
    WHERE	ID = 9;     
	
    SELECT MAX(DeviceCodeID), MIN(InsertTime)
    INTO lv_DeviceCodeID_Next, lv_DateValid
    FROM (SELECT DeviceCodeID
            ,	 InsertTime
		  FROM DCS_DataCenter.DeviceCode
		  WHERE DeviceCodeID > lv_DeviceCodeID_Last
		  ORDER BY DeviceCodeID ASC
		  LIMIT lv_BatchSize) AS tbl;
	
    IF(lv_DeviceCodeID_Next IS NULL) THEN
        SET lv_DeviceCodeID_Next = lv_DeviceCodeID_Last;
    END IF;

    IF(lv_DateValid >= DATE(NOW())) THEN
		LEAVE sp;
    END IF;
    
    
	INSERT  INTO Temp_DeviceCode(DeviceCodeID, HasPre, HasNext)
	SELECT 	cod.DeviceCodeID
		,	(SELECT 1 
			 FROM DCS_DataCenter.DeviceCode AS cod_pre
			 WHERE cod_pre.DeviceID = cod.DeviceID 
				AND cod_pre.DeviceCodeID < cod.DeviceCodeID
			LIMIT 1) AS HasPre
            
		,	(SELECT 1 
			 FROM DCS_DataCenter.DeviceCode AS cod_next
			 WHERE cod_next.DeviceID = cod.DeviceID 
				AND cod_next.DeviceCodeID > cod.DeviceCodeID
			 LIMIT 1) AS HasNext
	FROM DCS_DataCenter.DeviceCode AS cod
	WHERE cod.DeviceCodeID BETWEEN lv_DeviceCodeID_Last AND lv_DeviceCodeID_Next;
	
    DELETE tmp
    FROM Temp_DeviceCode AS tmp
    WHERE tmp.HasPre IS NULL
		OR tmp.HasNext IS NULL;
    
    DELETE cod
    FROM DCS_DataCenter.DeviceCode AS cod
    WHERE EXISTS (SELECT 1 FROM Temp_DeviceCode AS tmp WHERE tmp.DeviceCodeID = cod.DeviceCodeID);
    
    UPDATE DCS_DataCenter.SystemSetting AS ss
    SET 	VValue = lv_DeviceCodeID_Next
		,	UpdatedTime = NOW()
    WHERE	ID = 8; 
END$$

DELIMITER ;