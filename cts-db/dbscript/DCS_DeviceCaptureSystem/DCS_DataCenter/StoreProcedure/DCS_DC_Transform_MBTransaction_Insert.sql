/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBTransaction_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBTransaction_Insert`(
		IN ip_FromTransID   BIGINT UNSIGNED
	,   IN ip_ToTransID	 BIGINT UNSIGNED
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20241121@Jonathan.Doan
		Task : Transform Transaction
		DB: DCS_DataCenter
		Original:

		Revisions:
			- 20241121@Jonathan.Doan: Transform to MBTransaction [Redmine ID: #213401]
			- 20250804@Lando.Vu: Add MBDeviceDetails table [Redmine ID: #233405]
			- 20250811@Jonathan.Doan: Update new rule [Redmine ID: #235457]

		Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_Transform_MBTransaction_Insert(1,200);
	*/
	
	DECLARE lv_CurrentDatetime 					DATETIME DEFAULT NOW();
	DECLARE lv_MBDeviceCodeMediaDRMJson 		LONGTEXT;
	DECLARE lv_MBDeviceCodeTaggingJson	 		LONGTEXT;
	DECLARE lv_MBAccountJson 					LONGTEXT;
	DECLARE lv_ActionResultJson 				LONGTEXT;
	DECLARE lv_MBDeviceCodeMachineJson 			LONGTEXT;
	DECLARE lv_MBOSJson 						LONGTEXT;
	DECLARE lv_MBDeviceModelJson 				LONGTEXT;
	DECLARE lv_MBUserSettingJson 				LONGTEXT;
	DECLARE lv_MBDeviceCodeMachineAccountJson   LONGTEXT;
	DECLARE lv_MBDeviceCodeMachineMediaJson	 	LONGTEXT;

	DROP TEMPORARY TABLE IF EXISTS Temp_MBRawTransaction;
	CREATE TEMPORARY TABLE IF NOT EXISTS Temp_MBRawTransaction (
			ID 									BIGINT UNSIGNED PRIMARY KEY
		,	LoginName 							VARCHAR(100)
		,	SubscriberID 						INT
		,	SubscriberName 						VARCHAR(50)
		,	TransTime 							DATETIME(4)
		,	IP 									VARCHAR(50)
		,	IPID 								DECIMAL(50)
		,	Action 								VARCHAR(100)
		,	ActionResult 						VARCHAR(100)
		,	Flagged 							SMALLINT
		,	MBDeviceCodeMediaDRM 				VARCHAR(32)
		,	MBDeviceCodeMachine 				VARCHAR(32)
		,	MBDeviceCodeTagging 				VARCHAR(32)
		,	IsEmulator 							TINYINT
		,	ModelName 							VARCHAR(32)
		,	Manufacturer 						VARCHAR(32)
		,	Brand 								VARCHAR(32)
		,	SDKVersion 							VARCHAR(32)
		,	OSName 								VARCHAR(32)
		,	CountryName							VARCHAR(32)
		,	Timezone 							VARCHAR(32)
		,	Language 							VARCHAR(32)
		,	DeviceDetails 						JSON
		, 	MBAccountID							BIGINT UNSIGNED
		,	MBDeviceCodeTaggingID				BIGINT UNSIGNED
		,	MBDeviceCodeMediaDRMID				BIGINT UNSIGNED
		,	MBDeviceCodeMachineID				BIGINT UNSIGNED
		,	MBDeviceModelID						BIGINT UNSIGNED
		,	MBOSID								BIGINT UNSIGNED
		,	MBUserSettingID						BIGINT UNSIGNED
		,	ActionResultID						INT
		,	MBDeviceCodeMachineAccountID		BIGINT UNSIGNED
		,	MBDeviceCodeMachineMediaID			BIGINT UNSIGNED
	);
		
	INSERT INTO Temp_MBRawTransaction(ID, LoginName, SubscriberName, TransTime, IP, IPID, Action, ActionResult, Flagged, MBDeviceCodeMediaDRM, MBDeviceCodeMachine, MBDeviceCodeTagging, IsEmulator, ModelName, Manufacturer, Brand, SDKVersion, OSName, CountryName, Timezone, Language, DeviceDetails)
	SELECT 	rt.ID
		,   rt.LoginName
		,   rt.SubscriberName
		,   rt.TransTime
		,   rt.IP
		,   rt.IPID
		,   rt.Action
		,   rt.ActionResult
		,   rt.Flagged
		,   rt.MBDeviceCodeMediaDRM
		,   rt.MBDeviceCodeMachine
		,   rt.MBDeviceCodeTagging
		,   rt.IsEmulator
		,   rt.ModelName
		,   rt.Manufacturer
		,   rt.Brand
		,   rt.SDKVersion
		,   rt.OSName
		,   rt.CountryName
		,   rt.Timezone
		,   rt.Language
		,   rt.DeviceDetails
	FROM DCS_DataCenter.MBRawTransaction AS rt
	WHERE ID BETWEEN ip_FromTransID AND ip_ToTransID;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN CTS_Admin.Subscriber AS sub ON tmp.SubscriberName = sub.SubscriberName
	SET tmp.SubscriberID = sub.SubscriberID;
	
	/* === Insert new MBAccount === */ 
	WITH CTE_DistinctData AS (
		SELECT	SubscriberID
			,	LoginName
			,	MIN(TransTime) AS TransTime
		FROM Temp_MBRawTransaction
		WHERE SubscriberID IS NOT NULL
			AND LoginName IS NOT NULL
		GROUP BY SubscriberID, LoginName
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'SubscriberID'	, SubscriberID
				,	'LoginName'		, LoginName
				,	'TransTime'		, TransTime
			)
		) AS json_data
	INTO lv_MBAccountJson
	FROM CTE_DistinctData;
	
	SET lv_MBAccountJson = IFNULL(lv_MBAccountJson,'[{}]');
	CALL DCS_DC_Transform_MBAccount_Insert(lv_MBAccountJson);
	
	/* === Insert new ActionResult === */ 
	WITH CTE_DistinctData AS (
		SELECT	DISTINCT
				Action
			,	ActionResult
		FROM Temp_MBRawTransaction
		WHERE Action IS NOT NULL
			AND ActionResult IS NOT NULL
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'Action'			, Action
				,	'ActionResult'		, ActionResult
			)
		) AS json_data
	INTO lv_ActionResultJson
	FROM CTE_DistinctData;
	
	SET lv_ActionResultJson = IFNULL(lv_ActionResultJson,'[{}]');
	CALL DCS_DC_Transform_ActionResult_Insert(lv_ActionResultJson);
	
	/* === Insert new MBDeviceCodeMediaDRM === */
	WITH CTE_DistinctData AS (
		SELECT	MBDeviceCodeMediaDRM
			,	MIN(TransTime) AS TransTime
		FROM Temp_MBRawTransaction
		WHERE SubscriberID IS NOT NULL
			AND LoginName IS NOT NULL
		GROUP BY MBDeviceCodeMediaDRM
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'Code'			, MBDeviceCodeMediaDRM
				,	'TransTime'		, TransTime
					
			)
		) AS json_data
	INTO lv_MBDeviceCodeMediaDRMJson
	FROM CTE_DistinctData;
	
	IF (lv_MBDeviceCodeMediaDRMJson IS NOT NULL AND lv_MBDeviceCodeMediaDRMJson <> '') THEN
		CALL DCS_DC_Transform_MBDeviceCodeMediaDRM_Insert(lv_MBDeviceCodeMediaDRMJson);
	END IF;
	
	/* === Insert new MBDeviceCodeMachine === */ -- [{"Code":"Code4", "MachineOSType":"2"},{"Code":"Code2"},{"Code":"Code3", "MachineOSType":""}]
	WITH CTE_DistinctData AS (
		SELECT	MBDeviceCodeMachine
			,	OSName
			,	MIN(TransTime) AS TransTime
		FROM Temp_MBRawTransaction
		WHERE SubscriberID IS NOT NULL
			AND LoginName IS NOT NULL
		GROUP BY MBDeviceCodeMachine, OSName
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'Code'			, MBDeviceCodeMachine
				,	'MachineOS'		, OSName
				,	'TransTime'		, TransTime
					
			)
		) AS json_data
	INTO lv_MBDeviceCodeMachineJson
	FROM CTE_DistinctData;
	
	IF lv_MBDeviceCodeMachineJson IS NOT NULL THEN
		CALL DCS_DC_Transform_MBDeviceCodeMachine_Insert(lv_MBDeviceCodeMachineJson);
	END IF;
	
	/* === Insert new MBDeviceCodeTagging === */
	WITH CTE_DistinctData AS (
		SELECT	MBDeviceCodeTagging
			,	MIN(TransTime) AS TransTime
		FROM Temp_MBRawTransaction
		WHERE SubscriberID IS NOT NULL
			AND LoginName IS NOT NULL
		GROUP BY MBDeviceCodeTagging
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'Code'			, MBDeviceCodeTagging
				,	'TransTime'		, TransTime
					
			)
		) AS json_data
	INTO lv_MBDeviceCodeTaggingJson
	FROM CTE_DistinctData;
	
	IF (lv_MBDeviceCodeTaggingJson IS NOT NULL AND lv_MBDeviceCodeTaggingJson <> '') THEN
		CALL DCS_DC_Transform_MBDeviceCodeTagging_Insert(lv_MBDeviceCodeTaggingJson);
	END IF;
	
	/* === Insert new MBDeviceModel === */ -- {"ModelName":"sdk_gphone64_x86_64", "Manufacturer":"Google", "Brand": "google"}
	WITH CTE_DistinctData AS (
		SELECT	ModelName
			,	Manufacturer
			,	Brand
			,	MIN(TransTime) AS TransTime
		FROM Temp_MBRawTransaction
		WHERE ModelName IS NOT NULL
			OR Manufacturer IS NOT NULL
			OR Brand IS NOT NULL
		GROUP BY ModelName, Manufacturer, Brand
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'ModelName'			, ModelName
				,	'Manufacturer'		, Manufacturer
				,	'Brand'				, Brand
				,	'TransTime'			, TransTime
			)
		) AS json_data
	INTO lv_MBDeviceModelJson
	FROM CTE_DistinctData;
	
	IF lv_MBDeviceModelJson IS NOT NULL THEN
		CALL DCS_DC_Transform_MBDeviceModel_Insert(lv_MBDeviceModelJson);
	END IF;
	
	/* === Insert new MBUserSetting === */ -- {"CountryName":"CountryName1", "TimeZone":"TimeZone1", "LanguageName":"LanguageName1"}
	WITH CTE_DistinctData AS (
		SELECT	CountryName
			,	TimeZone
			,	Language
			,	MIN(TransTime) AS TransTime
		FROM Temp_MBRawTransaction
		WHERE CountryName IS NOT NULL
			OR TimeZone IS NOT NULL
			OR Language IS NOT NULL
		GROUP BY CountryName, TimeZone, Language
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'CountryName'		, CountryName
				,	'TimeZone'			, TimeZone
				,	'LanguageName'		, Language
				,	'TransTime'			, TransTime
			)
		) AS json_data
	INTO lv_MBUserSettingJson
	FROM CTE_DistinctData;
	
	IF lv_MBUserSettingJson IS NOT NULL THEN
		CALL DCS_DC_Transform_MBUserSetting_Insert(lv_MBUserSettingJson);
	END IF;
	
	/* === Insert new MBOS === */ -- {"OSName":"OSName1", "Version":"1.1.3"}
	WITH CTE_DistinctData AS (
		SELECT	OSName
			,	IFNULL(SDKVersion, '') AS SDKVersion
			,	MIN(TransTime) AS TransTime
		FROM Temp_MBRawTransaction
		WHERE OSName IS NOT NULL
		GROUP BY OSName, SDKVersion
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'OSName'		, OSName
				,	'Version'		, SDKVersion
				,	'TransTime'		, TransTime
			)
		) AS json_data
	INTO lv_MBOSJson
	FROM CTE_DistinctData;
	
	IF lv_MBOSJson IS NOT NULL THEN
		CALL DCS_DC_Transform_MBOS_Insert(lv_MBOSJson);
	END IF;
	
	/* ======= UPDATE ID ========= */
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.MBAccount AS acc ON acc.SubscriberID = tmp.SubscriberID AND acc.LoginName = tmp.LoginName
	SET tmp.MBAccountID = acc.ID;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.ActionResult AS ar ON tmp.Action = ar.Action AND IFNULL(tmp.ActionResult,'') = ar.ActionResult
	SET tmp.ActionResultID = ar.ActionResultID;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceCodeMediaDRM AS drm ON drm.Code = tmp.MBDeviceCodeMediaDRM
	SET tmp.MBDeviceCodeMediaDRMID = drm.ID;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceCodeMachine AS mc ON mc.Code = tmp.MBDeviceCodeMachine
	SET tmp.MBDeviceCodeMachineID = mc.ID;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceCodeTagging AS tg ON tg.Code = tmp.MBDeviceCodeTagging
	SET tmp.MBDeviceCodeTaggingID = tg.ID;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceModel AS dm ON dm.ModelName = tmp.ModelName 
													AND dm.Manufacturer = tmp.Manufacturer
													AND dm.Brand = tmp.Brand
	SET tmp.MBDeviceModelID = dm.ID;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.MBUserSetting AS us ON us.CountryName = tmp.CountryName 
													AND us.TimeZone = tmp.TimeZone
													AND us.LanguageName = tmp.Language
	SET tmp.MBUserSettingID = us.ID;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.MBOS AS os ON os.OSName = tmp.OSName 
											AND os.Version = tmp.SDKVersion
	SET tmp.MBOSID = os.ID;
	
	/* === Insert new MBDeviceCodeMachineAccount === */
	WITH CTE_DistinctData AS (
		SELECT	MBDeviceCodeMachineID
			,	MBAccountID
			,	MIN(TransTime) AS TransTime
		FROM Temp_MBRawTransaction
		WHERE MBDeviceCodeMachineID IS NOT NULL
			AND MBAccountID IS NOT NULL
		GROUP BY MBDeviceCodeMachineID, MBAccountID
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'MBDeviceCodeMachineID'		, MBDeviceCodeMachineID
				,	'MBAccountID'				, MBAccountID
				,	'TransTime'					, TransTime
			)
		) AS json_data
	INTO lv_MBDeviceCodeMachineAccountJson
	FROM CTE_DistinctData;

	IF lv_MBDeviceCodeMachineAccountJson IS NOT NULL THEN
		CALL DCS_DC_Transform_MBDeviceCodeMachineAccount_Insert(lv_MBDeviceCodeMachineAccountJson);
	END IF;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceCodeMachineAccount AS dcma ON dcma.MBDeviceCodeMachineID = tmp.MBDeviceCodeMachineID 
															AND dcma.MBAccountID = tmp.MBAccountID
	SET tmp.MBDeviceCodeMachineAccountID = dcma.ID;
	
	/* === Insert new MBDeviceCodeMachineMedia === */
	WITH CTE_DistinctData AS (
		SELECT	MBDeviceCodeMachineID
			,	MBDeviceCodeMediaDRMID
			,	MIN(TransTime) AS TransTime
		FROM Temp_MBRawTransaction
		WHERE MBDeviceCodeMachineID IS NOT NULL
			AND MBDeviceCodeMediaDRMID IS NOT NULL
		GROUP BY MBDeviceCodeMachineID, MBDeviceCodeMediaDRMID
	)
	SELECT JSON_ARRAYAGG(
			JSON_OBJECT(
					'MBDeviceCodeMachineID'		, MBDeviceCodeMachineID
				,	'MBDeviceCodeMediaDRMID'	, MBDeviceCodeMediaDRMID
				,	'TransTime'					, TransTime
			)
		) AS json_data
	INTO lv_MBDeviceCodeMachineMediaJson
	FROM CTE_DistinctData;

	IF lv_MBDeviceCodeMachineMediaJson IS NOT NULL THEN
		CALL DCS_DC_Transform_MBDeviceCodeMachineMedia_Insert(lv_MBDeviceCodeMachineMediaJson);
	END IF;
	
	UPDATE Temp_MBRawTransaction AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceCodeMachineMedia AS dcmm ON dcmm.MBDeviceCodeMachineID = tmp.MBDeviceCodeMachineID 
															AND dcmm.MBDeviceCodeMediaDRMID = tmp.MBDeviceCodeMediaDRMID
	SET tmp.MBDeviceCodeMachineMediaID = dcmm.ID;
	

	/* ======= INSERT MBTransaction ========= */
	INSERT IGNORE INTO DCS_DataCenter.MBTransaction(MBRawTransactionID, TransTime, LoginName, SubscriberID, MBAccountID, IP, IPID, ActionResultID, Flagged, MBDeviceCodeTaggingID, MBDeviceCodeMachineAccountID, MBDeviceCodeMachineMediaID, MBDeviceModelID, MBOSID, MBUserSettingID, InsertedTime)
   	SELECT  trt.ID
		,   trt.TransTime
		,   trt.LoginName
		,   trt.SubscriberID
		,   trt.MBAccountID
		,   trt.IP
		,   trt.IPID
		,   trt.ActionResultID
		,   trt.Flagged
		,   trt.MBDeviceCodeTaggingID
		,   trt.MBDeviceCodeMachineAccountID
		,   trt.MBDeviceCodeMachineMediaID
		,   trt.MBDeviceModelID
		,   trt.MBOSID
		,   trt.MBUserSettingID
		,   lv_CurrentDatetime AS InsertedTime
	FROM Temp_MBRawTransaction AS trt;
	
	/* ======= INSERT MBProcessedTransaction ========= */
	INSERT IGNORE INTO DCS_DataCenter.MBProcessedTransaction(ID, CreatedDate, LoginName, SubscriberName, TransTime, IP, IPID, Action, ActionResult, Flagged, MBDeviceCodeMediaDRM, MBDeviceCodeMachine, MBDeviceCodeTagging, IsEmulator, ModelName, Manufacturer, Brand, SDKVersion, OSName, Country, Timezone, Language, InsertedTime, DeviceDetails)
	SELECT  ID
		,   DATE(rt.TransTime) AS CreatedDate
		,   rt.LoginName
		,   rt.SubscriberName
		,   rt.TransTime
		,   rt.IP
		,   rt.IPID
		,   rt.Action
		,   rt.ActionResult
		,   rt.Flagged
		,   rt.MBDeviceCodeMediaDRM
		,   rt.MBDeviceCodeMachine
		,   rt.MBDeviceCodeTagging
		,   rt.IsEmulator
		,   rt.ModelName
		,   rt.Manufacturer
		,   rt.Brand
		,   rt.SDKVersion
		,   rt.OSName
		,   rt.CountryName
		,   rt.Timezone
		,   rt.Language
		,   lv_CurrentDatetime AS InsertedTime
		,	rt.DeviceDetails
	FROM Temp_MBRawTransaction AS rt;
		
	DELETE rt
	FROM DCS_DataCenter.MBRawTransaction AS rt
		INNER JOIN Temp_MBRawTransaction AS tmp_rm ON rt.ID = tmp_rm.ID;
	
END$$
DELIMITER ;