/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `Adhoc_DCS_DT_Initial_LoginTransactionSummaryByDevice_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `Adhoc_DCS_DT_Initial_LoginTransactionSummaryByDevice_Insert`(
		IN ip_BatchSize INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20240924@Jonathan.Doan
	    Task : Init Data for LoginTransactionSummaryByDevice
	    DB: DCS_DataTrace
	    Original:

	    Revisions:
		    - 20240924@Jonathan.Doan: Created [RedmineID: #206403]
	    Param's Explanation (filtered by):
        
        Example:
			SET sql_safe_updates = 0;
			CALL DCS_DataTrace.Adhoc_DCS_DT_Initial_LoginTransactionSummaryByDevice_Insert(1);
	*/
    DECLARE CONST_COOKDATA_BYDEVICE_LISTSUBID 	INT DEFAULT 7;
    DECLARE CONST_INITIAL_MAXTRANSID 			INT DEFAULT 100;
    DECLARE CONST_INITIAL_LIMITTRANSID 			INT DEFAULT 101;
		
    DECLARE lv_ListSubID						VARCHAR(500);
    DECLARE lv_MaxTransID 						BIGINT UNSIGNED;
    DECLARE lv_LimitTransID 					BIGINT UNSIGNED;
	
    DECLARE lv_FromTransID						BIGINT UNSIGNED;
    DECLARE lv_ToTransID						BIGINT UNSIGNED;
	
    DECLARE lv_CurrentDate 						TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    
    SET lv_ListSubID = (SELECT VValue FROM DCS_DataTrace.SystemSetting WHERE ID = CONST_COOKDATA_BYDEVICE_LISTSUBID);
	SET lv_MaxTransID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataTrace.SystemSetting WHERE ID = CONST_INITIAL_MAXTRANSID);
	SET lv_LimitTransID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataTrace.SystemSetting WHERE ID = CONST_INITIAL_LIMITTRANSID);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_SubscriberID;
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans07;
	DROP TEMPORARY TABLE IF EXISTS Temp_TotalTransByDevice;
    
	CREATE TEMPORARY TABLE Temp_SubscriberID(
			SubscriberID		INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY
	);
    
	CREATE TEMPORARY TABLE Temp_Trans07(
			TransID				BIGINT UNSIGNED NOT NULL PRIMARY KEY
		, 	TransDate			DATE NOT NULL
		, 	SubscriberID		INT UNSIGNED
		, 	AccountID			BIGINT UNSIGNED
		, 	DeviceID			BIGINT UNSIGNED
	);
    
	CREATE TEMPORARY TABLE Temp_TotalTransByDevice(
			ID					INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY 
		, 	TransDate			DATE NOT NULL
		, 	SubscriberID		INT UNSIGNED
		, 	AccountID			BIGINT UNSIGNED
		, 	DeviceID			BIGINT UNSIGNED
		, 	TotalTrans			INT UNSIGNED DEFAULT 0
		, 	IsUpdate			BIT DEFAULT 0
	);
    
    
    SET @sql = CONCAT("INSERT IGNORE INTO Temp_SubscriberID (SubscriberID) VALUES ('", REPLACE(lv_ListSubID, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    WHILE lv_LimitTransID < lv_MaxTransID DO
		WITH cte AS (
			SELECT trans.TransID
			FROM DCS_DataCenter.Transaction07 AS trans
				INNER JOIN Temp_SubscriberID AS tmpSub ON tmpSub.SubscriberID = trans.SubscriberID
			WHERE trans.TransID > lv_LimitTransID
				AND trans.TransID <= lv_MaxTransID
			ORDER BY trans.TransID ASC
			LIMIT ip_BatchSize
        )
        SELECT 	MIN(cte.TransID)
			,	MAX(cte.TransID)
		INTO lv_FromTransID, lv_ToTransID
        FROM cte;
        
        DELETE FROM Temp_TotalTransByDevice;
        INSERT INTO Temp_TotalTransByDevice(TransDate, SubscriberID, AccountID, DeviceID, TotalTrans)
		SELECT 	trans.CreatedDate AS _TransDate
			,	trans.SubscriberID
			,	IFNULL(trans.AccountID,0) AS _AccountID
			,	IFNULL(trans.DeviceID,0) AS _DeviceID
			,	COUNT(1) AS TotalTrans
		FROM DCS_DataCenter.Transaction07 AS trans
			INNER JOIN Temp_SubscriberID AS tmpSub ON tmpSub.SubscriberID = trans.SubscriberID
        WHERE trans.TransID BETWEEN lv_FromTransID AND lv_ToTransID
		GROUP BY _TransDate, trans.SubscriberID, _AccountID, _DeviceID;

		UPDATE DCS_DataTrace.LoginTransactionSummaryByDevice AS trans
			INNER JOIN Temp_TotalTransByDevice AS tmp 	ON 	trans.TransDate 	= tmp.TransDate 
														AND trans.SubscriberID 	= tmp.SubscriberID
														AND trans.AccountID 	= tmp.AccountID
														AND trans.DeviceID 		= tmp.DeviceID
		SET 	trans.TotalTrans 	= trans.TotalTrans + tmp.TotalTrans
			,	trans.ModifiedTime 	= lv_CurrentDate
			,	tmp.IsUpdate 		= 1;
        
		INSERT INTO DCS_DataTrace.LoginTransactionSummaryByDevice(TransDate, SubscriberID, AccountID, DeviceID, TotalTrans)
		SELECT 	tmp.TransDate
			,	tmp.SubscriberID
			,	tmp.AccountID
			,	tmp.DeviceID
			,	tmp.TotalTrans
		FROM Temp_TotalTransByDevice AS tmp
		WHERE tmp.IsUpdate = 0;
        
        SET lv_LimitTransID = lv_ToTransID;
		IF lv_LimitTransID IS NOT NULL AND lv_LimitTransID > 0 THEN
			UPDATE DCS_DataTrace.SystemSetting AS sys
			SET sys.VValue = CONCAT('', lv_LimitTransID),
				sys.UpdatedTime = lv_CurrentDate
			WHERE ID = CONST_INITIAL_LIMITTRANSID;
		END IF;

    END WHILE;
END$$

DELIMITER ;
