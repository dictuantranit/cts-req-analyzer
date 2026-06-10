/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_AbnormalTransaction_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_AbnormalTransaction_Update`(
	IN ip_TransJson LONGTEXT,
    IN ip_MinID BIGINT UNSIGNED,
    IN ip_MaxID BIGINT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20230321@Jonathan.Doan
	Task : Support return new device login for Alpha
	DB: DCS_DataCenter
	Original:

	Revisions:
		- 20230321@Jonathan.Doan: Update status for Completed Data [Redmine ID: 185185]
		- 20231026@Jonathan.Doan: Add Ignore when insert into Temp_InputTrans [Redmine ID: 196078]
		
	Param's Explanation (filtered by):

	Example:
		- CALL DCS_DataCenter.DCS_DC_AbnormalTransaction_Update('[{"ID":3,"Status":1}]', 1, 10);
	*/
    DECLARE lv_MaxID_VGroup VARCHAR(128) DEFAULT 'DCS_AbnormalTransaction';
    DECLARE lv_MaxID_VName VARCHAR(128) DEFAULT 'MaxID_Pushed';
    
    DECLARE lv_CurrentDatetime DATETIME DEFAULT CURRENT_TIMESTAMP();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_InputTrans;
	#======GET DATA FROM RAW TRANSACTION===========================
	CREATE TEMPORARY TABLE Temp_InputTrans(
			ID	BIGINT	UNSIGNED PRIMARY KEY
		, 	Status			TINYINT
	);

    IF ip_TransJson <> '' THEN
		INSERT IGNORE INTO Temp_InputTrans(
				ID
			,	Status
		)
		SELECT	tmp.ID
			,	tmp.Status
		FROM JSON_TABLE(
				ip_TransJson,
				 "$[*]" COLUMNS(
						ID				BIGINT UNSIGNED	PATH "$.ID"
					,	Status			TINYINT			PATH "$.Status"
				)
			) AS tmp;
		
		UPDATE Temp_InputTrans AS tmp
			INNER JOIN DCS_DataCenter.NewAccountDevice AS trans ON tmp.ID = trans.ID
		SET trans.Status = tmp.Status
        ,	trans.ModifiedDate = lv_CurrentDatetime;
    END IF;
    
    /*****UPDATE status for Trans not send****************************************************/
    UPDATE DCS_DataCenter.NewAccountDevice AS trans
		LEFT JOIN Temp_InputTrans AS tmp ON tmp.ID = trans.ID
	SET trans.ModifiedDate = lv_CurrentDatetime
	WHERE trans.ID BETWEEN ip_MinID AND ip_MaxID
		AND tmp.ID IS NULL;
        
    /*****UPDATE MaxTransID in SystemSetting****************************************************/
    IF ip_MaxID IS NOT NULL AND ip_MaxID > 0 THEN
		UPDATE DCS_DataCenter.SystemSetting AS sys
		SET 	sys.VValue 	= CONCAT('', ip_MaxID)
		   ,	sys.UpdatedTime = lv_CurrentDatetime
		WHERE VGroup = lv_MaxID_VGroup 
			AND VName = lv_MaxID_VName;
    END IF;
END$$
DELIMITER ;
