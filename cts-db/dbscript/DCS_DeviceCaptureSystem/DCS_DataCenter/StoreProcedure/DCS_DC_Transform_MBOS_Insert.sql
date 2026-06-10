/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBOS_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBOS_Insert`(
	IN ip_MBOSJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20241121@Jonathan.Doan
	    Task : Insert MBOS
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20241121@Jonathan.Doan: Transform to MBTransaction [Redmine ID: #213401]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_Transform_MBOS_Insert('[{"OSName":"OSName1","Version":"1.1.3"},{"OSName":"OSName2","Version":"1.1.3"},{"OSName":"OSName2"},{"Version":"1.1.5"},{}]');
            SELECT * FROM DCS_DataCenter.MBOS ORDER BY ID DESC;
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
		SELECT 'DCS_DC_Transform_MBOS_Insert', NULL, lv_FullMessage, CURRENT_TIMESTAMP();
        
        RESIGNAL;
	END;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MBOSInsert;
	CREATE TEMPORARY TABLE Temp_MBOSInsert(
			OSName			VARCHAR(32) NOT NULL
		,	Version			VARCHAR(32) NOT NULL
		,	TransTime		DATETIME(4)
		,	IsNewRecord		TINYINT		DEFAULT 1
        ,	PRIMARY KEY (OSName, Version)
    );
    
    INSERT IGNORE INTO Temp_MBOSInsert(OSName, Version, TransTime)
    SELECT	js.OSName
		,	js.Version
		,	js.TransTime
	FROM JSON_TABLE(
			ip_MBOSJson,
			 "$[*]" COLUMNS(
						OSName			VARCHAR(32) 	PATH "$.OSName"
					,	Version			VARCHAR(32) 	PATH "$.Version"
					,	TransTime		DATETIME(4)		PATH "$.TransTime"
				)
		   ) AS js
	WHERE js.OSName <> '';
	 
    UPDATE Temp_MBOSInsert AS tmp
		INNER JOIN DCS_DataCenter.MBOS AS os ON os.OSName = tmp.OSName 
											AND os.Version = tmp.Version
    SET tmp.IsNewRecord = 0;
	
	INSERT INTO DCS_DataCenter.MBOS(OSName, Version, InsertedTime, LastAccessedDate, CreatedDate)
	SELECT	OSName
		,	Version
		,	lv_CurrentDatetime AS InsertedTime
		,	DATE(TransTime) AS LastAccessedDate
		,	DATE(TransTime) AS CreatedDate
	FROM Temp_MBOSInsert
    WHERE IsNewRecord = 1;
END$$
DELIMITER ;