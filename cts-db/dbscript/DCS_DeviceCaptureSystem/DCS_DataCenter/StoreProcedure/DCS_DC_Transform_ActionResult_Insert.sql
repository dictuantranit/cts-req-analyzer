/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_ActionResult_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_ActionResult_Insert`(
	IN ip_ActionResultJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20241121@Jonathan.Doan
	    Task : Insert ActionResult
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20241121@Jonathan.Doan: Transform to MBTransaction [Redmine ID: #214026]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_Transform_ActionResult_Insert('[{"Action":"login","ActionResult":"Successfully2"},{"Action":""},{}]');
            SELECT * FROM DCS_DataCenter.ActionResult ORDER BY ActionResultID DESC;
    */
    DECLARE lv_CurrentDatetime 	DATETIME DEFAULT NOW();
    DECLARE lv_DefaultStatus	TINYINT DEFAULT 0;
    
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
		SELECT 'DCS_DC_Transform_ActionResult_Insert', NULL, lv_FullMessage, CURRENT_TIMESTAMP();
        
        RESIGNAL;
	END;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_ActionResultInsert;
	CREATE TEMPORARY TABLE Temp_ActionResultInsert(
			Action					 	VARCHAR(100) NOT NULL
		,	ActionResult	 			VARCHAR(100) NOT NULL
        
		,	IsNewRecord					TINYINT	DEFAULT 1
        ,	PRIMARY KEY (Action, ActionResult)
    );
    
    INSERT IGNORE INTO Temp_ActionResultInsert(Action, ActionResult)
    SELECT	js.Action
		,	js.ActionResult
	FROM JSON_TABLE(
			ip_ActionResultJson,
			 "$[*]" COLUMNS(
						Action				VARCHAR(100) 	PATH "$.Action"
					,	ActionResult		VARCHAR(100) 	PATH "$.ActionResult"
				)
		   ) AS js
	WHERE js.Action <> ''
		AND js.ActionResult <> '';
     
    UPDATE Temp_ActionResultInsert AS tmp
		INNER JOIN DCS_DataCenter.ActionResult AS ar ON ar.Action = tmp.Action AND ar.ActionResult = tmp.ActionResult
    SET tmp.IsNewRecord = 0;
	
	INSERT IGNORE INTO DCS_DataCenter.ActionResult(Action, ActionResult, ActionResultStatus, CreatedDate)
	SELECT	Action
		,	ActionResult
		,	lv_DefaultStatus AS ActionResultStatus
		,	lv_CurrentDatetime
	FROM Temp_ActionResultInsert
    WHERE IsNewRecord = 1;
END$$
DELIMITER ;