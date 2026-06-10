/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_Association_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_Association_Insert`(
		IN ip_AssociationJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20231128@Jonathan.Doan
		Task : Insert into DCS_DataCenter.Association
		DB: DCS_DataCenter
		Original:

		Revisions:
			- 20231128@Jonathan.Doan: Created [Redmine ID: #196570]
			- 20240806@Jonathan.Doan: Change data flow v6 [Redmine ID: #206403]
            - 20250909@Jonathan.Doan: Remove FP code [Redmine ID: #236716]
            
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Transform_Association_Insert('[{"DeviceID": 4, "AccountID": 1, "CreatedDate": "2023-11-17 00:00:00.000000", "CreatedTime": "2023-11-17 10:33:46.527500", "SubscriberID": 2}]');
			CALL DCS_DC_Transform_Association_Insert('[{"DeviceID": 6, "AccountID": 300016, "CreatedDate": "2023-11-17 00:00:00.000000", "CreatedTime": "2023-11-17 10:33:46.527500", "SubscriberID": 2}]');
        select * from Association;
*/
    DECLARE lv_CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociationInsert;
        
	CREATE TEMPORARY TABLE Temp_AssociationInsert(
			ID								INT UNSIGNED		NOT NULL AUTO_INCREMENT PRIMARY KEY
        ,	AccountID						BIGINT UNSIGNED		NOT NULL
        ,	DeviceID						BIGINT UNSIGNED		DEFAULT 0
        ,	SubscriberID					BIGINT UNSIGNED		
        ,	CreatedTime						TIMESTAMP(4)		
        ,	CreatedDate						DATETIME			
		,	IsNewRecordAssociation			TINYINT		 		DEFAULT 1
    );
    
    INSERT INTO Temp_AssociationInsert(AccountID, DeviceID, SubscriberID, CreatedTime, CreatedDate)
	SELECT 	tmp.AccountID
		,	IFNULL(tmp.DeviceID, 0) AS DeviceID
		,	MIN(tmp.SubscriberID) AS SubscriberID
		,	MIN(tmp.CreatedTime) AS CreatedTime
		,	MIN(tmp.CreatedDate) AS CreatedDate
    FROM JSON_TABLE(
			ip_AssociationJson,
			 "$[*]" COLUMNS(
							AccountID			BIGINT UNSIGNED	PATH "$.AccountID"
						,	DeviceID			BIGINT UNSIGNED PATH "$.DeviceID"
						,	SubscriberID		INT 			PATH "$.SubscriberID"
						,	CreatedTime			TIMESTAMP(4) 	PATH "$.CreatedTime"
						,	CreatedDate			DATETIME	 	PATH "$.CreatedDate"
					)
		) AS tmp
	WHERE tmp.AccountID IS NOT NULL
	GROUP BY tmp.AccountID, tmp.DeviceID;
    
    /* === Add index === */
	ALTER TABLE Temp_AssociationInsert
	ADD INDEX IX_Temp_AssociationInsert_AccountID_DeviceID (AccountID, DeviceID);
    
    UPDATE Temp_AssociationInsert AS tmp
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.AccountID = tmp.AccountID
													AND ass.DeviceID = tmp.DeviceID
    SET tmp.IsNewRecordAssociation = 0;
    
	INSERT IGNORE INTO DCS_DataCenter.Association(AccountID, DeviceID, SubscriberID, CreatedTime, CreatedDate, InsertTime)
	SELECT	AccountID
		,	DeviceID
		,	SubscriberID
		,	CreatedTime
		,	CreatedDate
		,	lv_CreatedDate AS InsertTime
	FROM Temp_AssociationInsert
    WHERE IsNewRecordAssociation = 1
		AND DeviceID > 0;
END$$

DELIMITER ;
