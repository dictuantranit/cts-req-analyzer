/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBDeviceModel_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBDeviceModel_Insert`(
	IN ip_MBDeviceModelJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20241121@Jonathan.Doan
	    Task : Insert MBDeviceModel
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20241121@Jonathan.Doan: Transform to MBTransaction [Redmine ID: #213401]
		    - 20250425@Jonathan.Doan: Add field CreatedDate, CreatedTime [Redmine ID: #221973]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_Transform_MBDeviceModel_Insert('[{"ModelName":"ModelName3","Manufacturer":"Manufacturer1","Brand":"Brand1"},{}]');
            SELECT * FROM DCS_DataCenter.MBDeviceModel ORDER BY ID DESC;
    */
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
		SELECT 'DCS_DC_Transform_MBDeviceModel_Insert', NULL, lv_FullMessage, CURRENT_TIMESTAMP();
        
        RESIGNAL;
	END;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MBDeviceModelInsert;
	CREATE TEMPORARY TABLE Temp_MBDeviceModelInsert(
			ModelName			VARCHAR(32) NOT NULL
		,	Manufacturer		VARCHAR(32) NOT NULL
		,	Brand				VARCHAR(32) NOT NULL
		,	TransTime			DATETIME(4)
		,	IsNewRecord			TINYINT		DEFAULT 1
        ,	PRIMARY KEY (ModelName, Manufacturer, Brand)
    );
    
    INSERT IGNORE INTO Temp_MBDeviceModelInsert(ModelName, Manufacturer, Brand, TransTime)
    SELECT	js.ModelName
		,	js.Manufacturer
		,	js.Brand
		,	js.TransTime
	FROM JSON_TABLE(
			ip_MBDeviceModelJson,
			 "$[*]" COLUMNS(
						ModelName			VARCHAR(32) 	PATH "$.ModelName"
					,	Manufacturer		VARCHAR(32) 	PATH "$.Manufacturer"
					,	Brand				VARCHAR(32) 	PATH "$.Brand"
					,	TransTime			DATETIME(4)		PATH "$.TransTime"
				)
		   ) AS js
	WHERE js.ModelName <> ''
		OR js.Manufacturer <> ''
		OR js.Brand <> '';
	 
    UPDATE Temp_MBDeviceModelInsert AS tmp
		INNER JOIN DCS_DataCenter.MBDeviceModel AS dm ON dm.ModelName = tmp.ModelName 
													AND dm.Manufacturer = tmp.Manufacturer
													AND dm.Brand = tmp.Brand
    SET tmp.IsNewRecord = 0;
	
	INSERT INTO DCS_DataCenter.MBDeviceModel(ModelName, Manufacturer, Brand, InsertedTime, LastAccessedDate, CreatedDate)
	SELECT	ModelName
		,	Manufacturer
		,	Brand
		,	lv_CurrentDatetime AS InsertedTime
		,	DATE(TransTime) AS LastAccessedDate
		,	DATE(TransTime) AS CreatedDate
	FROM Temp_MBDeviceModelInsert
    WHERE IsNewRecord = 1;
END$$
DELIMITER ;