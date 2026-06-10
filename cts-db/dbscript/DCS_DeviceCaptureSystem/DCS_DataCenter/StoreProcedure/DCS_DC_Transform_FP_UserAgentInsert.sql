/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_FP_UserAgentInsert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_FP_UserAgentInsert`(
	IN ip_UserAgentJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20240729@Jonathan.Doan
	    Task : Change Data Flow Ver. 6
		DB: DCS_DataCenter
		Original:

		Revisions:
			- 20240730@Jonathan.Doan: Created [Redmine ID: #206403]

		Param's Explanation (filtered by):
			
		Example:
			SET sql_safe_updates = 0;
			CALL DCS_DC_Transform_FP_UserAgentInsert('[{"FPUserAgentCode":"f1f6b29a6cc1f79a0fea05b885aa33d0","UserAgent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36","ClientType":"browser","ClientName":"Chrome","ClientVersion":"126.0.0.0","OSName":"Windows","OSShortName":"WIN","OSVersion":"10","OSPlatform":"x64","Device":"desktop","Brand":"","Model":""}]');

	*/
	
	DROP TEMPORARY TABLE IF EXISTS Temp_UserAgent;
	DROP TEMPORARY TABLE IF EXISTS Temp_Browser;
	DROP TEMPORARY TABLE IF EXISTS Temp_OS;
	DROP TEMPORARY TABLE IF EXISTS Temp_DeviceType;
    
	CREATE TEMPORARY TABLE Temp_UserAgent(
			Code			 			VARCHAR(100)    			NOT NULL
		,	UserAgent		 			VARCHAR(1000)    			NOT NULL
		,	BrowserID					BIGINT UNSIGNED					
		,	BrowserCode					VARCHAR(32)						
		,	ClientType 					VARCHAR(15) 					
		,	ClientName 					VARCHAR(100) 					
		,	ClientVersion 				VARCHAR(50) 					
		,	OSID						BIGINT UNSIGNED					
		,	OSCode						VARCHAR(32)						
		,	OSName 						VARCHAR(100) 					
		,	OSShortName 				VARCHAR(50) 					
		,	OSVersion 					VARCHAR(50) 					
		,	OSPlatform 					VARCHAR(15) 					
		,	DeviceTypeID				BIGINT UNSIGNED
		,	DeviceTypeCode				VARCHAR(32)
		,	Device 						VARCHAR(50) 					
		,	Brand 						VARCHAR(50) 					
		,	Model 						VARCHAR(15) 					
		,	IsNewRecord					TINYINT		 				DEFAULT 1
        
        ,	PRIMARY KEY (Code)
    );
    
	CREATE TEMPORARY TABLE Temp_Browser(
			BrowserCode				VARCHAR(100) NOT NULL PRIMARY KEY
		,	BrowserType				VARCHAR(15)
		,	BrowserName				VARCHAR(100)
		,	BrowserVersion			VARCHAR(50)
		,	IsNewRecord				TINYINT	DEFAULT 1
	);
    
	CREATE TEMPORARY TABLE Temp_OS(
			OSCode					VARCHAR(100) NOT NULL PRIMARY KEY
		,	OSName					VARCHAR(100)
		,	OSShortName				VARCHAR(50)
		,	OSVersion				VARCHAR(50)
		,	IsNewRecord				TINYINT	DEFAULT 1
	);
    
	CREATE TEMPORARY TABLE Temp_DeviceType(
			DeviceTypeCode			VARCHAR(100) NOT NULL PRIMARY KEY
		,	DeviceType				VARCHAR(50)
		,	Brand					VARCHAR(50)
		,	Model					VARCHAR(15)
		,	IsNewRecord				TINYINT	DEFAULT 1
	);
    
    INSERT IGNORE INTO Temp_UserAgent(Code, UserAgent, BrowserCode, ClientType, ClientName, ClientVersion, OSCode, OSName, OSShortName, OSVersion, OSPlatform, DeviceTypeCode, Device, Brand, Model)
    SELECT	js.FP_UserAgentCode AS Code
		,	js.UserAgent
		,	MD5(CONCAT(IFNULL(js.ClientType, ''), IFNULL(js.ClientName, ''), IFNULL(js.ClientVersion, ''))) AS BrowserCode
		,	js.ClientType
		,	js.ClientName
		,	js.ClientVersion
		,	MD5(CONCAT(IFNULL(js.OSName, ''), IFNULL(js.OSShortName, ''), IFNULL(js.OSVersion, ''))) AS OSCode
		,	js.OSName
		,	js.OSShortName
		,	js.OSVersion
		,	js.OSPlatform
		,	MD5(CONCAT(IFNULL(js.Device, ''), IFNULL(js.Brand, ''), IFNULL(js.Model, ''))) AS DeviceTypeCode
		,	js.Device
		,	js.Brand
		,	js.Model
	FROM JSON_TABLE(
			ip_UserAgentJson,
			 "$[*]" COLUMNS(
						FP_UserAgentCode	VARCHAR(32) 	PATH "$.FPUserAgentCode"
					,	UserAgent			VARCHAR(1000) 	PATH "$.UserAgent"
					,	ClientType			VARCHAR(15) 	PATH "$.ClientType"
					,	ClientName			VARCHAR(100) 	PATH "$.ClientName"
					,	ClientVersion		VARCHAR(50) 	PATH "$.ClientVersion"
					,	OSName				VARCHAR(100) 	PATH "$.OSName"
					,	OSShortName			VARCHAR(50) 	PATH "$.OSShortName"
					,	OSVersion			VARCHAR(50) 	PATH "$.OSVersion"
					,	OSPlatform			VARCHAR(15) 	PATH "$.OSPlatform"
					,	Device				VARCHAR(50) 	PATH "$.Device"
					,	Brand				VARCHAR(50) 	PATH "$.Brand"
					,	Model				VARCHAR(15) 	PATH "$.Model"
				)
		   ) AS js;
	
	ALTER TABLE Temp_UserAgent
	ADD INDEX IX_Temp_UserAgent_Code (Code);
    
    /***== Insert Browser ==***/
    INSERT IGNORE INTO Temp_Browser(BrowserCode, BrowserType, BrowserName, BrowserVersion)
    SELECT	BrowserCode
		,	ClientType
		,	ClientName
		,	ClientVersion
    FROM Temp_UserAgent;
	 
    UPDATE Temp_Browser AS tmp
		INNER JOIN DCS_DataCenter.FP_Browser AS b ON b.BrowserCode = tmp.BrowserCode
    SET tmp.IsNewRecord = 0;
	
	INSERT IGNORE INTO DCS_DataCenter.FP_Browser(BrowserCode, BrowserType, BrowserName, BrowserVersion)
	SELECT	BrowserCode
		,	BrowserType
		,	BrowserName
		,	BrowserVersion
	FROM Temp_Browser
    WHERE IsNewRecord = 1;
    
	UPDATE Temp_UserAgent AS tmp
		INNER JOIN DCS_DataCenter.FP_Browser AS b ON b.BrowserCode = tmp.BrowserCode
	SET tmp.BrowserID = b.ID;
    
    /***== Insert OS ==***/
    INSERT IGNORE INTO Temp_OS(OSCode, OSName, OSShortName, OSVersion)
    SELECT	OSCode
		,	OSName
		,	OSShortName
		,	OSVersion
    FROM Temp_UserAgent;
	 
    UPDATE Temp_OS AS tmp
		INNER JOIN DCS_DataCenter.FP_OS AS os ON os.OSCode = tmp.OSCode
    SET tmp.IsNewRecord = 0;
	
	INSERT IGNORE INTO DCS_DataCenter.FP_OS(OSCode, OSName, OSShortName, OSVersion)
	SELECT	OSCode
		,	OSName
		,	OSShortName
		,	OSVersion
	FROM Temp_OS
    WHERE IsNewRecord = 1;
    
	UPDATE Temp_UserAgent AS tmp
		INNER JOIN DCS_DataCenter.FP_OS AS os ON os.OSCode = tmp.OSCode
	SET tmp.OSID = os.ID;
    
    
    /***== Insert DeviceType ==***/
    INSERT IGNORE INTO Temp_DeviceType(DeviceTypeCode, DeviceType, Brand, Model)
    SELECT	DeviceTypeCode
		,	Device
		,	Brand
		,	Model
    FROM Temp_UserAgent;
	 
    UPDATE Temp_DeviceType AS tmp
		INNER JOIN DCS_DataCenter.FP_DeviceType AS dt ON dt.DeviceTypeCode = tmp.DeviceTypeCode
    SET tmp.IsNewRecord = 0;
	
	INSERT IGNORE INTO DCS_DataCenter.FP_DeviceType(DeviceTypeCode, DeviceType, Brand, Model)
	SELECT	DeviceTypeCode
		,	DeviceType
		,	Brand
		,	Model
	FROM Temp_DeviceType
    WHERE IsNewRecord = 1;
    
	UPDATE Temp_UserAgent AS tmp
		INNER JOIN DCS_DataCenter.FP_DeviceType AS dt ON dt.DeviceTypeCode = tmp.DeviceTypeCode
	SET tmp.DeviceTypeID = dt.ID;
	
    /***== Insert FP_UserAgent ==***/
    UPDATE Temp_UserAgent AS tmp
		INNER JOIN DCS_DataCenter.FP_UserAgent AS c ON c.Code = tmp.Code
    SET tmp.IsNewRecord = 0;
	
    INSERT IGNORE INTO DCS_DataCenter.FP_UserAgent(Code, UserAgent, BrowserID, OSID, DeviceTypeID)
    SELECT 	Code
		,	UserAgent
		,	BrowserID
		,	OSID
		,	DeviceTypeID
    FROM Temp_UserAgent
    WHERE IsNewRecord = 1;
END$$

DELIMITER ;