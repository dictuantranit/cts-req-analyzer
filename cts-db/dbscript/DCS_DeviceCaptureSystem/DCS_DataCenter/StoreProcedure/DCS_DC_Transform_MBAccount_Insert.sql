/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBAccount_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBAccount_Insert`(
	IN ip_AccountJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20241121@Jonathan.Doan
	    Task : Insert MBAccount
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20241121@Jonathan.Doan: Transform to MBTransaction [Redmine ID: #213401]
		    - 20250425@Jonathan.Doan: Add field CreatedDate, CreatedTime [Redmine ID: #221973]
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_DC_Transform_MBAccount_Insert('[{"SubscriberID":2,"LoginName":"qatest002","TransTime":"2024-11-21 05:06:07"}]');
			CALL DCS_DC_Transform_MBAccount_Insert('[{"SubscriberID":2,"LoginName":"qatest002","TransTime":"2024-11-21 05:06:07"},{"SubscriberID":null},{"LoginName":"qatest003"}]');
            SELECT * FROM DCS_DataCenter.MBAccount ORDER BY ID DESC;
    */
    DECLARE lv_CurrentDatetime DATETIME DEFAULT NOW();
    
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
		SELECT 'DCS_DC_Transform_MBAccount_Insert', NULL, lv_FullMessage, CURRENT_TIMESTAMP();
        
        RESIGNAL;
	END;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AccountInsert;
	CREATE TEMPORARY TABLE Temp_AccountInsert(
			SubscriberID		INT 			NOT NULL
		,	LoginName		 	VARCHAR(100) 	NOT NULL
		,	TransTime			DATETIME(4)
		,	IsNewRecord			TINYINT			DEFAULT 1
        ,	PRIMARY KEY (SubscriberID, LoginName)
    );
    
    INSERT IGNORE INTO Temp_AccountInsert(SubscriberID, LoginName, TransTime)
    SELECT	js.SubscriberID
		,	js.LoginName
		,	js.TransTime
	FROM JSON_TABLE(
			ip_AccountJson,
			 "$[*]" COLUMNS(
						SubscriberID		INT			 	PATH "$.SubscriberID"
					,	LoginName			VARCHAR(100) 	PATH "$.LoginName"
					,	TransTime			DATETIME(4) 	PATH "$.TransTime"
				)
		   ) AS js
	WHERE js.SubscriberID > 0
		AND js.LoginName <> '';
	 
    UPDATE Temp_AccountInsert AS tmp
		INNER JOIN DCS_DataCenter.MBAccount AS acc ON acc.SubscriberID = tmp.SubscriberID AND acc.LoginName = tmp.LoginName
    SET tmp.IsNewRecord = 0;
	
	INSERT INTO DCS_DataCenter.MBAccount(SubscriberID, LoginName, LastLoginTime, InsertedTime, CreatedDate, CreatedTime)
	SELECT	SubscriberID
		,	LoginName
		,	TransTime
		,	lv_CurrentDatetime AS InsertedTime
		,	DATE(TransTime) AS CreatedDate
		,	TransTime AS CreatedTime
	FROM Temp_AccountInsert
    WHERE IsNewRecord = 1;
END$$
DELIMITER ;