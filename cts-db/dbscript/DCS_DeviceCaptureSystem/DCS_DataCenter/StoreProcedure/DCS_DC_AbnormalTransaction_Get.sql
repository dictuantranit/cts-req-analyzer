/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_AbnormalTransaction_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_AbnormalTransaction_Get`(
		IN ip_Size INT
        
	,	OUT op_MinID BIGINT UNSIGNED
	,	OUT op_MaxID BIGINT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20230316@Jonathan.Doan
	Task : Support return new device login for Alpha
	DB: DCS_DataCenter
	Original:

	Revisions:
		- 20230316@Jonathan.Doan: Get Data [Redmine ID: 185185]
		- 20230623@Jonathan.Doan: Add Field ID AUTO_INCREMENT  [Redmine ID: #190217]
		
	Param's Explanation (filtered by):

	Example:
		- CALL DCS_DataCenter.DCS_DC_Abnormal_Transasction_Get(10, @minID, @maxID); SELECT @minID, @maxID
	*/
    DECLARE lv_MaxID_VGroup VARCHAR(128) DEFAULT 'DCS_AbnormalTransaction';
    DECLARE lv_MaxID_VName VARCHAR(128) DEFAULT 'MaxID_Pushed';
    
    DECLARE lv_MaxID BIGINT UNSIGNED;
    
    SET lv_MaxID = IFNULL((SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE VGroup = lv_MaxID_VGroup AND VName = lv_MaxID_VName), 0);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_NewAccountDevice;
    DROP TEMPORARY TABLE IF EXISTS Temp_NewAccountDevice_Validated;
    DROP TEMPORARY TABLE IF EXISTS Temp_Account_Count_Device_History;
    DROP TEMPORARY TABLE IF EXISTS Temp_Account_MinID;
    
    CREATE TEMPORARY TABLE Temp_NewAccountDevice(
			ID				BIGINT UNSIGNED PRIMARY KEY
        ,	AccountID 		BIGINT UNSIGNED
        
        ,	INDEX 	IX_Temp_NewAccountDevice_AccountID(AccountID)
    );
    
    CREATE TEMPORARY TABLE Temp_NewAccountDevice_Validated(
			ID			 	BIGINT UNSIGNED PRIMARY KEY
        ,	AccountID 		BIGINT UNSIGNED
    );
    
    CREATE TEMPORARY TABLE Temp_Account_Count_Device_History(
			AccountID 		BIGINT UNSIGNED PRIMARY KEY
    );
    
    CREATE TEMPORARY TABLE Temp_Account_MinID(
			MinID 			BIGINT UNSIGNED PRIMARY KEY
        ,	AccountID 		BIGINT UNSIGNED
    );
    
    INSERT IGNORE INTO Temp_NewAccountDevice(ID, AccountID)
    SELECT 	ID
		,	AccountID
	FROM DCS_DataCenter.NewAccountDevice PARTITION(p10000000)
	WHERE ID > lv_MaxID
		AND status = 0
    ORDER BY ID ASC
    LIMIT ip_Size;
    
    SELECT	IFNULL(MIN(ID),0)
		,	IFNULL(MAX(ID),0)
    INTO 	op_MinID
		,	op_MaxID
	FROM Temp_NewAccountDevice;
    
    INSERT INTO Temp_Account_Count_Device_History(AccountID)
    WITH cte_AccountID AS (
		SELECT DISTINCT AccountID
        FROM Temp_NewAccountDevice
    )
    SELECT 	nad.AccountID
    FROM cte_AccountID AS cte
		INNER JOIN DCS_DataCenter.NewAccountDevice PARTITION(p10000000) AS nad ON nad.AccountID = cte.AccountID
	WHERE nad.ID < op_MinID
	GROUP BY nad.AccountID;
    
    INSERT INTO Temp_NewAccountDevice_Validated(ID, AccountID)
    SELECT 	tmp.ID
		,	tmp.AccountID
	FROM Temp_Account_Count_Device_History AS tmpH
		INNER JOIN Temp_NewAccountDevice AS tmp ON tmp.AccountID = tmpH.AccountID;
        
	DELETE tmp
    FROM Temp_NewAccountDevice AS tmp
		INNER JOIN Temp_NewAccountDevice_Validated AS tmpV ON tmpV.ID = tmp.ID;
        
    /*****Check inside BATCH ONLY****************************************************/
    INSERT INTO Temp_Account_MinID(MinID, AccountID)
    SELECT 	MIN(tmp.ID) as MinID
		,	tmp.AccountID
	FROM Temp_NewAccountDevice AS tmp
	GROUP BY tmp.AccountID;
    
    INSERT INTO Temp_NewAccountDevice_Validated(ID, AccountID)
    SELECT 	tmp.ID
		,	tmp.AccountID
    FROM Temp_NewAccountDevice AS tmp
		LEFT JOIN Temp_Account_MinID AS tmpAM ON tmpAM.MinID = tmp.ID
	WHERE tmpAM.MinID IS NULL;
        
    /*****Return DATA****************************************************/
    SELECT 	nad.ID
		,	nad.LoginName
		,	nad.TransTime
		,	nad.IP
		,	ua.UserAgent
		,	ua.OS
		,	ua.Browser
		,	dt.DeviceTypeName
	FROM Temp_NewAccountDevice_Validated AS tmp
		INNER JOIN DCS_DataCenter.NewAccountDevice PARTITION(p10000000) AS nad ON nad.ID = tmp.ID
		LEFT JOIN DCS_DataCenter.UserAgent AS ua ON ua.UserAgentKey = nad.UserAgentKey
		LEFT JOIN DCS_DataCenter.DeviceType AS dt ON dt.DeviceTypeID = ua.DeviceTypeID;
END$$
DELIMITER ;