/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transform_RawUserAgent_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transform_RawUserAgent_Insert`(
	IN ip_TableName VARCHAR(50)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230809@Jonathan.Doan
		Task :		Insert into RawUserAgent
		DB:			DCS_Extra
		Original:

		Revisions:
			- 20231108@Jonathan.Doan: Created [Redmine ID: #196570]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Transform_RawUserAgent_Insert('Temp_Transaction');
    
    */
    DECLARE lv_CurrentDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_InputData;
	DROP TEMPORARY TABLE IF EXISTS Temp_RawUserAgent;
    
	CREATE TEMPORARY TABLE Temp_InputData(
			TmpID			 			BIGINT UNSIGNED	NOT NULL
		,	RawUserAgent 				VARCHAR(1000) 	NULL
		,	RawUserAgentCode 			VARCHAR(64) 	NULL
		,	RawUserAgentInfo			LONGTEXT		NULL
        
        ,	PRIMARY KEY (TmpID)
    );
    
	CREATE TEMPORARY TABLE Temp_RawUserAgent(
			TmpID			 			BIGINT UNSIGNED		NOT NULL  
		,	RawUserAgentID	 			BIGINT UNSIGNED    	NULL    
		,	RawUserAgent	 			LONGTEXT	    	NULL    
		,	RawUserAgentCode 			VARCHAR(100)    	NULL    
		,	ClientType 					VARCHAR(15) 		NULL
		,	ClientName 					VARCHAR(100) 		NULL
		,	ClientVersion 				VARCHAR(50) 		NULL
		,	OSName 						VARCHAR(100) 		NULL
		,	OSShortName 				VARCHAR(50) 		NULL
		,	OSVersion 					VARCHAR(50) 		NULL
		,	OSPlatform 					VARCHAR(15) 		NULL
		,	Device 						VARCHAR(50) 		NULL
		,	Brand 						VARCHAR(50) 		NULL
		,	Model 						VARCHAR(15) 		NULL
		,	IsNewRawUserAgent			TINYINT		 		DEFAULT 1
        
        ,	PRIMARY KEY (TmpID)
    );
    
	SET @sql = CONCAT('INSERT INTO Temp_InputData(TmpID, RawUserAgent, RawUserAgentCode, RawUserAgentInfo) 
						SELECT 	ID AS TmpID
							,	RawUserAgent
							,	MD5(RawUserAgent) AS RawUserAgentCode
                            ,	RawUserAgentInfo
                        FROM ', ip_TableName, 
					' 	WHERE RawUserAgent IS NOT NULL');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    INSERT IGNORE INTO Temp_RawUserAgent(TmpID, RawUserAgentCode, RawUserAgent, ClientType, ClientName, ClientVersion, OSName, OSShortName, OSVersion, OSPlatform, Device, Brand, Model)
    SELECT 	TmpID
		,	RawUserAgentCode
		,	RawUserAgent
		,	RawUserAgentInfo->>'$.ClientType'
		,	RawUserAgentInfo->>'$.ClientName'
		,	RawUserAgentInfo->>'$.ClientVersion'
		,	RawUserAgentInfo->>'$.OSName'
		,	RawUserAgentInfo->>'$.OSShortName'
		,	RawUserAgentInfo->>'$.OSVersion'
		,	RawUserAgentInfo->>'$.OSPlatform'
		,	RawUserAgentInfo->>'$.Device'
		,	RawUserAgentInfo->>'$.Brand'
		,	RawUserAgentInfo->>'$.Model'
    FROM Temp_InputData;
	
	ALTER TABLE Temp_RawUserAgent
	ADD INDEX IX_Temp_RawUserAgent_RawUserAgentCode (RawUserAgentCode);
	
    UPDATE Temp_RawUserAgent AS tmp
		INNER JOIN DCS_Extra.RawUserAgent AS c ON c.RawUserAgentCode = tmp.RawUserAgentCode
    SET tmp.IsNewRawUserAgent = 0;
	
    INSERT IGNORE INTO DCS_Extra.RawUserAgent (RawUserAgentCode, RawUserAgent, ClientType, ClientName, ClientVersion, OSName, OSShortName, OSVersion, OSPlatform, Device, Brand, Model, CreatedDate)
	SELECT	DISTINCT
			tmp.RawUserAgentCode
		,	tmp.RawUserAgent
		,	tmp.ClientType
		,	tmp.ClientName
		,	tmp.ClientVersion
		,	tmp.OSName
		,	tmp.OSShortName
		,	tmp.OSVersion
		,	tmp.OSPlatform
		,	tmp.Device
		,	tmp.Brand
		,	tmp.Model
        ,	lv_CurrentDate AS CreatedDate
	FROM Temp_RawUserAgent AS tmp
    WHERE IsNewRawUserAgent = 1;
    
    UPDATE Temp_RawUserAgent AS tmp
		INNER JOIN DCS_Extra.RawUserAgent AS ua ON ua.RawUserAgentCode = tmp.RawUserAgentCode
	SET tmp.RawUserAgentID = ua.ID;
    
	SET @sql = CONCAT('UPDATE ', ip_TableName,' AS tmp
						INNER JOIN Temp_RawUserAgent AS ua ON ua.TmpID = tmp.ID
                        SET tmp.RawUserAgentID = ua.RawUserAgentID');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;
