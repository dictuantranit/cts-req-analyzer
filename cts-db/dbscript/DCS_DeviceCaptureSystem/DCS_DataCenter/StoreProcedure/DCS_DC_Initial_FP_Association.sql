/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Initial_FP_Association`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Initial_FP_Association`(
		IN ip_BatchSize INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20240924@Jonathan.Doan
	    Task : Init Data for FP_Association
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20240924@Jonathan.Doan: Created [RedmineID: #206403]
	    Param's Explanation (filtered by):
        
        Example:
			SET sql_safe_updates = 0;
			CALL DCS_DC_Initial_FP_Association(1);
	*/
    DECLARE CONST_INITIAL_MAXASSOCIATIONID 		INT DEFAULT 1000;
    DECLARE CONST_INITIAL_LIMITASSOCIATIONID 	INT DEFAULT 1001;
    
    DECLARE lv_MaxAssociationID 				BIGINT UNSIGNED;
    DECLARE lv_LimitAssociationID 				BIGINT UNSIGNED;
    
    DECLARE lv_From_AssociationID				BIGINT UNSIGNED;
    DECLARE lv_To_AssociationID					BIGINT UNSIGNED;
    
    DECLARE lv_CurrentDate 						TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    
	SET lv_MaxAssociationID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_INITIAL_MAXASSOCIATIONID);
	SET lv_LimitAssociationID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_INITIAL_LIMITASSOCIATIONID);
    
    WHILE lv_MaxAssociationID < lv_LimitAssociationID DO
		WITH cte AS (
			SELECT AssociationID
            FROM DCS_DataCenter.Association
			WHERE AssociationID > lv_MaxAssociationID
				AND AssociationID <= lv_LimitAssociationID
			ORDER BY AssociationID ASC
			LIMIT ip_BatchSize
        )
        SELECT 	MIN(cte.AssociationID)
			,	MAX(cte.AssociationID)
		INTO lv_From_AssociationID, lv_To_AssociationID
        FROM cte;

		INSERT INTO DCS_DataCenter.FP_Association(AccountID, DeviceID, SubscriberID, CreatedTime, CreatedDate, InsertedTime, IsCTSTransformed)
        SELECT	AccountID
			,	DeviceID
			,	SubscriberID
			,	CreatedTime
			,	CreatedDate
			,	InsertTime AS InsertedTime
			,	IsCTSTransformed
		FROM DCS_DataCenter.Association
        WHERE AssociationID BETWEEN lv_From_AssociationID AND lv_To_AssociationID
		ORDER BY AssociationID ASC;
        
        SET lv_MaxAssociationID = lv_To_AssociationID;
		IF lv_MaxAssociationID IS NOT NULL AND lv_MaxAssociationID > 0 THEN
			UPDATE DCS_DataCenter.SystemSetting AS sys
			SET sys.VValue = CONCAT('', lv_MaxAssociationID),
				sys.UpdatedTime = lv_CurrentDate
			WHERE ID = CONST_INITIAL_MAXASSOCIATIONID;
		END IF;
    END WHILE;
END$$

DELIMITER ;
