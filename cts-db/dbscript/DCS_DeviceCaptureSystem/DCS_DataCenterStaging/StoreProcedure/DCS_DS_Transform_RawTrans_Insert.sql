/*<info serverAlias="CTSMain-DCS_DataCenterStaging" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DS_Transform_RawTrans_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DS_Transform_RawTrans_Insert`(
		IN ip_RawTransJson LONGTEXT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20190610@Casey.Huynh
		Task : Insert to Raw Table
		DB: DCS_DataCenterStaging
		Original:

		Revisions:
			- 20201006@CaseyHuynh: Move New Server, Move table RawTransaction from DB "DCS_RawTransaction" to "DCS_DataCenterStaging" [Redmine ID: #143011]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
			- 20211129@Casey.Huynh: Remove FingerprintMoreInfo Column [Redmine ID: #165167]
			- 20230327@Terry.Nguyen: Add InsertTime [Redmine ID: #185185]
			- 20230426@Jonathan.Doan: Add BotD [Redmine ID: #186644]
			- 20230807@Terry.Nguyen: Add Fake IP [Redmine ID: #191829]
			- 20231108@Jonathan.Doan: Integrate FPSjs [Redmine ID: #196570]
			- 20240313@Teddy.le : Add JsChallengeID  [Redmine ID: #196667]
			- 20240621@Jonathan.Doan: Change data flow v6 [Redmine ID: #206403]
			- 20241023@Lando.Vu: Integrate Mobile App [Redmine ID: #199300]
			- 20241121@Jonathan.Doan: Insert MBRawTransaction [Redmine ID: #213401]
			- 20250804@Lando.Vu: Add MBDeviceDetails table [Redmine ID: #233405]
			- 20250808@Jonathan.Doan: Separate iOS trans [Redmine ID: #235457]
			- 20250916@Casey.Huynh: AI Power Device Fingerprint AND Remove FPJs[Redmine ID: #236716]
			- 20251010@Jonathan.Doan: Add field Indicate Tagging Type & FP version[Redmine ID: #240781]
            
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DataCenterStaging.DCS_DS_Transform_RawTrans_Insert('[{"LoginName":"fadomas","SubscriberName":"Alpha","TransTime":"2025-09-28T01:41:55.1562","CreatedDate":"0001-01-01T00:00:00","DeviceCode":"016696225c26492c98dfc83cf5cf6d66","FingerprintCode":null,"UserAgent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36","IP":"10.0.0.112","FakeIP":"","IPId":167772272,"IsIPV6":false,"PluginID":0,"URL":"http://alp21.nexdev.net/","Action":"login","ActionResult":"Successfull","InvalidDevice":null,"TransStatus":0,"FlaggedCode":"Human","BotDetection":"","BotComponent":"","ChallengeCode":null,"IsIncognitoMode":null,"MBDeviceCodeMediaDRM":null,"MBDeviceCodeMachine":null,"MBDeviceCodeTagging":null,"MBIsMobileApp":false,"MBIsEmulator":false,"MBModelName":null,"MBManufacturer":null,"MBBrand":null,"MBSDKVersion":null,"MBOS":null,"MBTimezone":null,"MBLanguage":null,"MBCountry":null,"MBDeviceDetails":null,"WebRTCIPCode":"bc34dce2502f5d0f0e24fe5c3bb36fb3","FPPatternCode01":"9350094f6f271526f9f117f02326db25","FPPatternCode02":null,"ActivatorVersion":"3.0.3","FingerprintVersion":"1.0.3","TransFlow":1,"TaggingType":1001}]');
	*/
	
	DECLARE lv_FlaggedHuman	INT UNSIGNED DEFAULT 1;
	DECLARE lv_InsertionTime TIMESTAMP(4) DEFAULT CURRENT_TIMESTAMP(4);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
	DROP TEMPORARY TABLE IF EXISTS Temp_MBTransaction;
	DROP TEMPORARY TABLE IF EXISTS Temp_BotDetection;
	DROP TEMPORARY TABLE IF EXISTS Temp_BotComponent;
	
	CREATE TEMPORARY TABLE Temp_Transaction(
			ID							INT UNSIGNED AUTO_INCREMENT PRIMARY KEY
		,	LoginName					VARCHAR(100) 				NOT NULL	
		,	SubscriberName				VARCHAR(50) 				NOT NULL
		,	TransTime					TIMESTAMP(4)	 			NOT NULL
		,	DeviceCode					VARCHAR(32) 				NULL		COMMENT 'Device Inject Code: 32 characters is auto generated'
		,	FingerprintCode				VARCHAR(620)				NULL		COMMENT 'Device Fingerprint Codes, the hashcode bases on the set attributes'	
		,	UserAgent					VARCHAR(1000)				NULL
		,	IP							VARCHAR(50) 				NULL
		,	IPID						DECIMAL(50,0)				NULL
		,	PluginID					BIGINT 						NULL	
		,	URL							VARCHAR(500) 				NULL
		,	`Action`					VARCHAR(100) 				NULL
		,	ActionResult				VARCHAR(100) 				NULL
		,	InvalidDevice				VARCHAR(1000)				CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NULL
		,	TransStatus					BIT(16)						NULL
		,	FlaggedCode					VARCHAR(100)				NULL
		,	BotDetection				LONGTEXT					NULL
		,	BotDetectionValue			BIT(32)						NULL		DEFAULT 0
		,	BotComponentID				BIGINT UNSIGNED				NULL
		,	BotComponent				LONGTEXT					NULL
		,	BotComponentCode			VARCHAR(100)				NULL
		,	FakeIP						VARCHAR(100) 				NULL
		,	ChallengeCode				VARCHAR(50)					NULL
		,	IsIncognitoMode				BOOLEAN						NULL
		,	MBDeviceCodeMediaDRM		VARCHAR(32)					NULL
		,	MBDeviceCodeMachine			VARCHAR(32)					NULL
		,	MBDeviceCodeTagging			VARCHAR(32)					NULL
		,	MBIsMobileApp				BOOLEAN						NULL		DEFAULT '0'
		,	MBIsEmulator				BOOLEAN						NULL		DEFAULT '0'
		,	MBModelName					VARCHAR(32)					NULL	
		,	MBManufacturer				VARCHAR(32)					NULL	
		,	MBBrand						VARCHAR(32)					NULL
		,	MBSDKVersion				VARCHAR(32)					NULL	
		,	MBOS						VARCHAR(32)					NULL
		,	MBTimezone					VARCHAR(32)					NULL
		,	MBLanguage					VARCHAR(32)					NULL
		,	MBCountry					VARCHAR(32)					NULL
		,	MBDeviceDetails				JSON						NULL
        ,	WebRTCIPCode				VARCHAR(32)					NULL    
        ,	FPPatternCode01				VARCHAR(32)   				NULL	# FPPatternType 1
        ,	FPPatternCode02				VARCHAR(32)   				NULL 	# FPPatternType 2
        ,	FPVersion 					VARCHAR(10) 				NULL
		,	TransFlow 					TINYINT(1)					NOT NULL
		,	ActivatorVersion 			VARCHAR(10)					NULL
		,	FingerprintVersion 			VARCHAR(10)					NULL
		,	TaggingType 				SMALLINT					NULL
	);
	
	CREATE TEMPORARY TABLE Temp_MBTransaction(
			ID							INT UNSIGNED AUTO_INCREMENT PRIMARY KEY
		,	LoginName					VARCHAR(100) 				NOT NULL	
		,	SubscriberName				VARCHAR(50) 				NOT NULL
		,	TransTime					TIMESTAMP(4)	 			NOT NULL
		,	IP							VARCHAR(50) 				NULL
		,	IPID						DECIMAL(50,0)				NULL
		,	`Action`					VARCHAR(100) 				NULL
		,	ActionResult				VARCHAR(100) 				NULL
		,	FlaggedCode					VARCHAR(100)				NULL	
		,	MBDeviceCodeMediaDRM		VARCHAR(32)					NULL
		,	MBDeviceCodeMachine			VARCHAR(32)					NULL
		,	MBDeviceCodeTagging			VARCHAR(32)					NULL
		,	IsEmulator					BOOLEAN						NULL		DEFAULT '0'
		,	ModelName					VARCHAR(32)					NULL	
		,	Manufacturer				VARCHAR(32)					NULL	
		,	Brand						VARCHAR(32)					NULL
		,	SDKVersion					VARCHAR(32)					NULL	
		,	OSName						VARCHAR(32)					NULL
		,	CountryName					VARCHAR(32)					NULL
		,	Timezone					VARCHAR(32)					NULL
		,	Language					VARCHAR(32)					NULL
		,	DeviceDetails				JSON						NULL

		,   INDEX IX_Temp_MBTransaction_OSName(OSName)
	);

	CREATE TEMPORARY TABLE Temp_BotDetection(
			ID							INT UNSIGNED PRIMARY KEY
		,	BotDetectionValue			BIT(32) NULL DEFAULT 0
	);

	CREATE TEMPORARY TABLE Temp_BotComponent(
			Code						VARCHAR(100) NOT NULL		PRIMARY KEY
		,	Component					LONGTEXT 	 NOT NULL
		,	FlaggedCode					VARCHAR(100) NOT NULL
		
		,	IsNewRecord					TINYINT		 				DEFAULT 1
	);
		
	INSERT INTO Temp_Transaction(LoginName, SubscriberName, TransTime, DeviceCode, FingerprintCode, UserAgent, IP, IPID, PluginID, URL, Action, ActionResult, InvalidDevice, TransStatus, FlaggedCode, BotDetection, BotComponent, BotComponentCode, FakeIP, ChallengeCode, IsIncognitoMode, MBDeviceCodeMediaDRM, MBDeviceCodeMachine, MBDeviceCodeTagging, MBIsMobileApp, MBIsEmulator, MBModelName, MBManufacturer, MBBrand, MBSDKVersion, MBOS, MBTimezone, MBLanguage, MBCountry, MBDeviceDetails, WebRTCIPCode, FPPatternCode01, FPPatternCode02, TransFlow, ActivatorVersion, FingerprintVersion, TaggingType)
	SELECT	rt.LoginName
		,	rt.SubscriberName
		,	rt.TransTime
		,	(CASE WHEN rt.DeviceCode IS NULL THEN NULL ELSE rt.DeviceCode END) AS DeviceCode
		,	(CASE WHEN rt.FingerprintCode IS NULL OR rt.DeviceCode IS NULL	THEN NULL ELSE rt.FingerprintCode END) AS FingerprintCode
		,	LEFT((CASE WHEN rt.UserAgent IS NULL THEN NULL ELSE rt.UserAgent END),1000) AS UserAgent
		,	(CASE WHEN rt.IP IS NULL THEN NULL ELSE rt.IP END) AS IP
		,	(CASE WHEN rt.IPID = 0 THEN NULL ELSE rt.IPID END) AS IPID
		,	(CASE WHEN rt.PluginID = 0 THEN NULL ELSE rt.PluginID END) AS PluginID			
		,	(CASE WHEN rt.URL IS NULL THEN NULL ELSE rt.URL END) AS URL
		,	(CASE WHEN rt.Action IS NULL THEN NULL ELSE rt.Action END) AS Action
		,	(CASE WHEN rt.ActionResult IS NULL THEN NULL ELSE rt.ActionResult END) AS ActionResult
		,	LEFT((CASE WHEN rt.InvalidDevice IS NULL THEN NULL ELSE rt.InvalidDevice END),1000) AS InvalidDevice
		,	rt.TransStatus
		,	rt.FlaggedCode
		,	rt.BotDetection
		,	rt.BotComponent
		,	MD5(rt.BotComponent) AS BotComponentCode
		,	rt.FakeIP
		,	rt.ChallengeCode
		,	rt.IsIncognitoMode
		,	rt.MBDeviceCodeMediaDRM
		,	rt.MBDeviceCodeMachine
		,	rt.MBDeviceCodeTagging
		,	IFNULL(rt.MBIsMobileApp, '0') AS MBIsMobileApp
		,	IFNULL(rt.MBIsEmulator, '0') AS MBIsEmulator
		,	rt.MBModelName
		,	rt.MBManufacturer
		,	rt.MBBrand
		,	rt.MBSDKVersion
		,	rt.MBOS
		,	rt.MBTimezone
		,	rt.MBLanguage
		,	rt.MBCountry
		,	rt.MBDeviceDetails
        ,	rt.WebRTCIPCode
        ,	rt.FPPatternCode01
        ,	rt.FPPatternCode02
        ,	IFNULL(rt.TransFlow,0) AS TransFlow
		,	rt.ActivatorVersion
		,	rt.FingerprintVersion
		,	rt.TaggingType
	FROM	JSON_TABLE(
			ip_RawTransJson,
			 "$[*]" COLUMNS(
								LoginName					VARCHAR(100)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' PATH "$.LoginName"	   
							,	SubscriberName				VARCHAR(50) 	PATH "$.SubscriberName"   
							,	TransTime					TIMESTAMP(4) 	PATH "$.TransTime"
							,	DeviceCode					VARCHAR(32)		PATH "$.DeviceCode"
							,	FingerprintCode				VARCHAR(620)	PATH "$.FingerprintCode"
							,	UserAgent					TEXT 			PATH "$.UserAgent"
							,	IP							VARCHAR(50) 	PATH "$.IP"
							,	IPID						DECIMAL(50,0)	PATH "$.IPId"
							,	PluginID					BIGINT 			PATH "$.PluginID"
							,	URL							VARCHAR(500) 	PATH "$.URL"
							,	Action						VARCHAR(100)	PATH "$.Action"
							,	ActionResult				VARCHAR(100) 	PATH "$.ActionResult"
							,	InvalidDevice				TEXT			CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' PATH "$.InvalidDevice"
							,	TransStatus					BIT(16)			PATH "$.TransStatus"
							,	FlaggedCode					VARCHAR(100)	PATH "$.FlaggedCode"
							,	BotDetection				LONGTEXT		PATH "$.BotDetection"
							,	BotComponent				LONGTEXT		PATH "$.BotComponent"
							,	FakeIP						VARCHAR(100)	PATH "$.FakeIP"
							,	ChallengeCode				VARCHAR(50)		PATH "$.ChallengeCode"
							,	IsIncognitoMode				BOOLEAN			PATH "$.IsIncognitoMode"
							,	MBDeviceCodeMediaDRM		VARCHAR(32)		PATH "$.MBDeviceCodeMediaDRM"
							,	MBDeviceCodeMachine			VARCHAR(32)		PATH "$.MBDeviceCodeMachine"
							,	MBDeviceCodeTagging			VARCHAR(32)		PATH "$.MBDeviceCodeTagging"
							,	MBIsMobileApp				BOOLEAN			PATH "$.MBIsMobileApp"
							,	MBIsEmulator				BOOLEAN			PATH "$.MBIsEmulator"
							,	MBModelName					VARCHAR(32)		PATH "$.MBModelName"
							,	MBManufacturer				VARCHAR(32)		PATH "$.MBManufacturer"
							,	MBBrand						VARCHAR(32)		PATH "$.MBBrand"
							,	MBSDKVersion				VARCHAR(32)		PATH "$.MBSDKVersion"
							,	MBOS 						VARCHAR(32)		PATH "$.MBOS"
							,	MBTimezone					VARCHAR(32)		PATH "$.MBTimezone"
							,	MBLanguage					VARCHAR(32)		PATH "$.MBLanguage"
							,	MBCountry					VARCHAR(32)		PATH "$.MBCountry"
							,	MBDeviceDetails				JSON			PATH "$.MBDeviceDetails"
                            ,	WebRTCIPCode				VARCHAR(32)		PATH "$.WebRTCIPCode"						
							,	FPPatternCode01				VARCHAR(32)		PATH "$.FPPatternCode01"
							,	FPPatternCode02				VARCHAR(32)		PATH "$.FPPatternCode02"
                            ,	TransFlow					TINYINT(1)		PATH "$.TransFlow"
                            ,	ActivatorVersion 			VARCHAR(10)		PATH "$.ActivatorVersion"
                            ,	FingerprintVersion 			VARCHAR(10)		PATH "$.FingerprintVersion"
                            ,	TaggingType	 				SMALLINT		PATH "$.TaggingType"
				)
		   ) AS rt; 
		   
   /******* Add index ********************/
	ALTER TABLE Temp_Transaction
	ADD INDEX IX_Temp_Transaction_MBIsMobileApp (MBIsMobileApp),
	ADD INDEX IX_Temp_Transaction_BotComponentCode (BotComponentCode);
		   
	/******* Insert Temp Mobile RawTransaction ********************/
	INSERT INTO Temp_MBTransaction(LoginName, SubscriberName, TransTime, IP, IPID, Action, ActionResult, FlaggedCode, MBDeviceCodeMediaDRM, MBDeviceCodeMachine, MBDeviceCodeTagging, IsEmulator, ModelName, Manufacturer, Brand, SDKVersion, OSName, CountryName, Timezone, Language, DeviceDetails)
	SELECT	rt.LoginName
		,	rt.SubscriberName
		,	rt.TransTime
		,	(CASE WHEN rt.IP IS NULL THEN NULL ELSE rt.IP END) AS IP
		,	(CASE WHEN rt.IPID = 0 THEN NULL ELSE rt.IPID END) AS IPID
		,	(CASE WHEN rt.Action IS NULL THEN NULL ELSE rt.Action END) AS Action
		,	(CASE WHEN rt.ActionResult IS NULL THEN NULL ELSE rt.ActionResult END) AS ActionResult
		,	rt.FlaggedCode
		,	rt.MBDeviceCodeMediaDRM
		,	rt.MBDeviceCodeMachine
		,	rt.MBDeviceCodeTagging
		,	rt.MBIsEmulator 		AS IsEmulator
		,	rt.MBModelName 			AS ModelName
		,	rt.MBManufacturer 		AS Manufacturer
		,	rt.MBBrand 				AS Brand
		,	rt.MBSDKVersion 		AS SDKVersion
		,	rt.MBOS					AS OSName
		,	rt.MBCountry			AS CountryName
		,	rt.MBTimezone			AS Timezone
		,	rt.MBLanguage			AS Language
		,	rt.MBDeviceDetails		AS DeviceDetails
	FROM Temp_Transaction AS rt
	WHERE rt.MBIsMobileApp = 1;
	
	DELETE FROM Temp_Transaction AS rt
	WHERE rt.MBIsMobileApp = 1;
	
	/******* BotDetection ********************/
	INSERT INTO Temp_BotDetection(ID, BotDetectionValue)
	SELECT 	tmp.ID
		, 	SUM(bd.Value) AS Value
	FROM Temp_Transaction AS tmp
		INNER JOIN DCS_DataCenterStaging.BotDetection AS bd ON FIND_IN_SET(bd.Name, tmp.BotDetection)
	GROUP BY tmp.ID;
	
	UPDATE Temp_Transaction AS tmp
		INNER JOIN Temp_BotDetection AS tmpBD ON tmpBD.ID = tmp.ID
	SET tmp.BotDetectionValue = tmpBD.BotDetectionValue;
	
	/******* BotComponent ********************/
	INSERT IGNORE INTO Temp_BotComponent(Code, Component, FlaggedCode)
	SELECT 	BotComponentCode AS Code
		,	BotComponent AS Component
		,	FlaggedCode
	FROM Temp_Transaction;
	
	UPDATE Temp_BotComponent AS tmp
		INNER JOIN DCS_DataCenterStaging.BotComponent AS bc ON bc.Code = tmp.Code
	SET tmp.IsNewRecord = 0;
	
	INSERT IGNORE INTO DCS_DataCenterStaging.BotComponent(Code, Component, IsHuman, CreatedDate, ModifiedDate)
	SELECT 	Code
		,	Component
		,	CASE WHEN FlaggedCode = 'Human' THEN 1 ELSE 0 END AS IsHuman
		,	lv_InsertionTime AS CreatedDate
		,	DATE(lv_InsertionTime) AS ModifiedDate
	FROM Temp_BotComponent AS tmp
	WHERE IsNewRecord = 1;
	
	UPDATE Temp_Transaction AS tmp
		INNER JOIN DCS_DataCenterStaging.BotComponent AS bds ON bds.Code = tmp.BotComponentCode
	SET tmp.BotComponentID = bds.ID;
	
	/*******RawTransaction********************/
	INSERT INTO DCS_DataCenterStaging.RawTransaction(LoginName, SubscriberName, TransTime, CreatedDate, DeviceCode, FingerprintCode, UserAgent, IP, IPID, Flagged, PluginID, URL, Action, ActionResult, InvalidDevice, TransStatus, InsertTime, BotDetectionValue, BotComponentID, FakeIP, ChallengeCode, IsIncognitoMode, WebRTCIPCode, FPPatternCode01, FPPatternCode02, TransFlow, ActivatorVersion, FingerprintVersion, TaggingType)
	SELECT	rt.LoginName
		,	rt.SubscriberName
		,	rt.TransTime
		,	DATE(rt.TransTime) AS CreatedDate
		,	rt.DeviceCode
		,	rt.FingerprintCode
		,	rt.UserAgent
		,	rt.IP
		,	rt.IPID
		,	sl.ItemID AS Flagged
		,	rt.PluginID
		,	rt.URL
		,	rt.Action
		,	rt.ActionResult
		,	rt.InvalidDevice
		,	rt.TransStatus
		,	lv_InsertionTime as InsertTime
		,	rt.BotDetectionValue
		,	rt.BotComponentID
		,	rt.FakeIP
		,   rt.ChallengeCode
		,   rt.IsIncognitoMode
        ,	rt.WebRTCIPCode
        ,	rt.FPPatternCode01
        ,	rt.FPPatternCode02
        ,	rt.TransFlow
		,	rt.ActivatorVersion
		,	rt.FingerprintVersion
		,	rt.TaggingType
	FROM Temp_Transaction AS rt
		LEFT JOIN DCS_DataCenterStaging.StaticList AS sl 	ON sl.ListID = 1 /*Flagged*/   
													AND sl.ItemCode = rt.FlaggedCode;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
	
	
	/*******Mobile RawTransaction IOS********************/
	INSERT INTO DCS_DataCenterStaging.MBRawTransactionIOS(LoginName, SubscriberName, TransTime, IP, IPID, Action, ActionResult, Flagged, MBDeviceCodeMediaDRM, MBDeviceCodeMachine, MBDeviceCodeTagging, IsEmulator, ModelName, Manufacturer, Brand, SDKVersion, OSName, CountryName, Timezone, Language, DeviceDetails)
	SELECT	rt.LoginName
		,	rt.SubscriberName
		,	rt.TransTime
		,	rt.IP
		,	rt.IPID
		,	rt.Action
		,	rt.ActionResult
		,	sl.ItemID AS Flagged
		,	rt.MBDeviceCodeMediaDRM
		,	rt.MBDeviceCodeMachine
		,	rt.MBDeviceCodeTagging
		,	rt.IsEmulator
		,	rt.ModelName
		,	rt.Manufacturer
		,	rt.Brand
		,	rt.SDKVersion
		,	rt.OSName
		,	rt.CountryName
		,	rt.Timezone
		,	rt.Language
		,	rt.DeviceDetails
	FROM Temp_MBTransaction AS rt
		LEFT JOIN DCS_DataCenterStaging.StaticList AS sl 	ON sl.ListID = 1 /*Flagged*/   
													AND sl.ItemCode = rt.FlaggedCode
	WHERE rt.OSName = 'IOS';

	/*******Mobile RawTransaction********************/
	INSERT INTO DCS_DataCenterStaging.MBRawTransaction(LoginName, SubscriberName, TransTime, IP, IPID, Action, ActionResult, Flagged, MBDeviceCodeMediaDRM, MBDeviceCodeMachine, MBDeviceCodeTagging, IsEmulator, ModelName, Manufacturer, Brand, SDKVersion, OSName, CountryName, Timezone, Language, DeviceDetails)
	SELECT	rt.LoginName
		,	rt.SubscriberName
		,	rt.TransTime
		,	rt.IP
		,	rt.IPID
		,	rt.Action
		,	rt.ActionResult
		,	sl.ItemID AS Flagged
		,	rt.MBDeviceCodeMediaDRM
		,	rt.MBDeviceCodeMachine
		,	rt.MBDeviceCodeTagging
		,	rt.IsEmulator
		,	rt.ModelName
		,	rt.Manufacturer
		,	rt.Brand
		,	rt.SDKVersion
		,	rt.OSName
		,	rt.CountryName
		,	rt.Timezone
		,	rt.Language
		,	rt.DeviceDetails
	FROM Temp_MBTransaction AS rt
		LEFT JOIN DCS_DataCenterStaging.StaticList AS sl 	ON sl.ListID = 1 /*Flagged*/   
													AND sl.ItemCode = rt.FlaggedCode
	WHERE rt.OSName <> 'IOS';

	DROP TEMPORARY TABLE IF EXISTS Temp_MBTransaction;
END$$

DELIMITER ;
