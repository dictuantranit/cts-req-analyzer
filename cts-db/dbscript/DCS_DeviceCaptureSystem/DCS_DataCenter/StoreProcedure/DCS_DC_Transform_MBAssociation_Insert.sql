/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBAssociation_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBAssociation_Insert`(
	IN ip_AssociationJson LONGTEXT
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
			CALL DCS_DC_Transform_MBAssociation_Insert('[{"MBDeviceID": 105, "MBAccountID": 3, "SubscriberID": 2, "TransTime": "2025-04-25"}, {"MBDeviceID": 106, "MBAccountID": 3, "SubscriberID": 2, "TransTime": "2025-04-25 12:05:06"}]');
			select * from MBAssociation;
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
		SELECT 'DCS_DC_Transform_MBAssociation_Insert', NULL, lv_FullMessage, CURRENT_TIMESTAMP();
        
        RESIGNAL;
	END;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MBAssociationInsert;
	CREATE TEMPORARY TABLE Temp_MBAssociationInsert(
			ID					INT UNSIGNED		NOT NULL AUTO_INCREMENT PRIMARY KEY
        ,	MBAccountID			BIGINT UNSIGNED		NOT NULL
        ,	MBDeviceID			BIGINT UNSIGNED		NOT NULL
        ,	SubscriberID		INT
		,	TransTime			DATETIME(4)
		,	IsNewRecord			TINYINT		 		DEFAULT 1
    );
    
    INSERT INTO Temp_MBAssociationInsert(MBAccountID, MBDeviceID, SubscriberID, TransTime)
	SELECT 	tmp.MBAccountID
		,	tmp.MBDeviceID
		,	MIN(tmp.SubscriberID) AS SubscriberID
		,	MIN(tmp.TransTime) AS TransTime
    FROM JSON_TABLE(
			ip_AssociationJson,
			 "$[*]" COLUMNS(
							MBAccountID			BIGINT UNSIGNED	PATH "$.MBAccountID"
						,	MBDeviceID			BIGINT UNSIGNED PATH "$.MBDeviceID"
						,	SubscriberID		INT 			PATH "$.SubscriberID"
						,	TransTime			DATETIME(4) 	PATH "$.TransTime"
					)
		) AS tmp
	WHERE tmp.MBAccountID > 0
		AND tmp.MBDeviceID > 0
	GROUP BY tmp.MBAccountID, tmp.MBDeviceID;
    
    UPDATE Temp_MBAssociationInsert AS tmp
		INNER JOIN DCS_DataCenter.MBAssociation AS ass ON ass.MBAccountID = tmp.MBAccountID
														AND ass.MBDeviceID = tmp.MBDeviceID
    SET tmp.IsNewRecord = 0;
    
	INSERT INTO DCS_DataCenter.MBAssociation(MBAccountID, MBDeviceID, SubscriberID, InsertedTime, CreatedDate, CreatedTime, LastAccessedDate)
	SELECT	MBAccountID
		,	MBDeviceID
		,	SubscriberID
		,	lv_CurrentDatetime AS InsertedTime
		,	DATE(TransTime) AS CreatedDate
		,	TransTime AS CreatedTime
		,	DATE(TransTime) AS LastAccessedDate
	FROM Temp_MBAssociationInsert
    WHERE IsNewRecord = 1;
END$$

DELIMITER ;