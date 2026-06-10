/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBDevice_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBDevice_Insert`(
    IN ip_MBTransactionInfoJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20241205@Jonathan.Doan
	    Task : Transform Device to Transaction07
	    DB: DCS_DataCenter
	    Original:
		 
	    Revisions:
		    - 20241205@Jonathan.Doan: Created [RedmineID: #213401]
		    - 20250425@Jonathan.Doan: Add field CreatedDate, CreatedTime [Redmine ID: #221973]
	    Param's Explanation (filtered by):
        
        Example:
			SET sql_safe_updates = 0;
			CALL DCS_DataCenter.DCS_DC_Transform_MBDevice_Insert('[{"TransID":1,"MBRawTransactionID":1,"SameDeviceID":0,"BatchID":1},{"TransID":3,"MBRawTransactionID":3,"SameDeviceID":0,"BatchID":1}]');
	*/
    
    DECLARE lv_AssociationJson 	LONGTEXT;
    DECLARE lv_CurrentDatetime 	DATETIME DEFAULT NOW();
    
    
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
		SELECT 'DCS_DC_Transform_MBDevice_Insert', NULL, lv_FullMessage, CURRENT_TIMESTAMP();
        
        RESIGNAL;
	END;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_DeviceMappingInfo;
	CREATE TEMPORARY TABLE Temp_DeviceMappingInfo(
			TransID						BIGINT UNSIGNED NOT NULL PRIMARY KEY 
		,	MBRawTransactionID			BIGINT UNSIGNED
		,	MBAccountID					BIGINT UNSIGNED
		,	SubscriberID				INT
		,	TransTime					DATETIME(4)
		,	IP 							VARCHAR(50)
		,	IPID 						DECIMAL(50,0)
		,	ActionResultID 				INT
		,	Flagged 					SMALLINT
		,	MBDeviceModelID 			BIGINT UNSIGNED
		,	MBOSID			 			BIGINT UNSIGNED
		,	MBUserSettingID	 			BIGINT UNSIGNED
		,	SameDeviceID				BIGINT UNSIGNED
		,	RecoverType					SMALLINT
		,	MBDeviceMappingID			BIGINT UNSIGNED
		,	MBDeviceID					BIGINT UNSIGNED
	);
        
	#========GET INPUT DATA===========================        
    INSERT INTO Temp_DeviceMappingInfo(TransID, SameDeviceID, RecoverType, MBRawTransactionID, MBAccountID, SubscriberID, TransTime, IP, IPID, ActionResultID, Flagged, MBDeviceModelID, MBOSID, MBUserSettingID)
	SELECT 	tmp.TransID
		,	tmp.SameDeviceID
		,	tmp.RecoverType
		,	trans.MBRawTransactionID
		,	trans.MBAccountID
		,	trans.SubscriberID
        ,	trans.TransTime
		,	trans.IP
		,	trans.IPID
		,	trans.ActionResultID
		,	trans.Flagged
		,	trans.MBDeviceModelID
		,	trans.MBOSID
		,	trans.MBUserSettingID
    FROM JSON_TABLE(
			ip_MBTransactionInfoJson,
			 "$[*]" COLUMNS(
							TransID			BIGINT UNSIGNED		PATH "$.TransID"
						,	SameDeviceID	BIGINT UNSIGNED 	PATH "$.SameDeviceID"
						,	RecoverType		SMALLINT		 	PATH "$.RecoverType"
					)
		) AS tmp
		INNER JOIN DCS_DataCenter.MBTransaction AS trans ON trans.ID = tmp.TransID;
    
	CALL DCS_DC_Transform_MBDeviceMapping_Insert('Temp_DeviceMappingInfo');
    
    /* === Insert new Association === */
    WITH CTE_DistinctData AS (
		SELECT	DISTINCT
				MBAccountID
			,	MBDeviceID
			,	TransTime
			,	SubscriberID
		FROM Temp_DeviceMappingInfo
		WHERE MBAccountID > 0
			AND MBDeviceID > 0
    )
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'MBAccountID'	, MBAccountID
				,	'MBDeviceID'	, MBDeviceID
				,	'TransTime'		, TransTime
				,	'SubscriberID'	, SubscriberID
			)
		) AS json_data
	INTO lv_AssociationJson
	FROM CTE_DistinctData;
    
    IF lv_AssociationJson IS NOT NULL THEN
		CALL DCS_DC_Transform_MBAssociation_Insert(lv_AssociationJson);
    END IF;
    
	INSERT IGNORE INTO DCS_DataCenter.MBTransaction07(CreatedDate, MBRawTransactionID, TransTime, SubscriberID, MBAccountID, IP, IPID, ActionResultID, Flagged, MBDeviceModelID, MBOSID, MBUserSettingID, MBDeviceMappingID, MBDeviceID, DeviceStatus, InsertedTime)
	SELECT	DATE(TransTime) AS CreatedDate
		,	MBRawTransactionID
        ,	TransTime
        ,	SubscriberID
        , 	MBAccountID
        ,	IP
        ,	IPID
        ,	ActionResultID
        ,	Flagged
        ,	MBDeviceModelID
        ,	MBOSID
        ,	MBUserSettingID
        ,	IFNULL(MBDeviceMappingID,0) AS MBDeviceMappingID
        ,	IFNULL(MBDeviceID,0) AS MBDeviceID
        ,	IFNULL(RecoverType,-1) AS DeviceStatus
        ,	lv_CurrentDatetime AS InsertedTime
	FROM Temp_DeviceMappingInfo;
    
	DELETE trans
	FROM DCS_DataCenter.MBTransaction AS trans
		INNER JOIN Temp_DeviceMappingInfo AS tmp ON tmp.TransID = trans.ID;
    
END$$

DELIMITER ;