/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Notification_GetProbation`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Notification_GetProbation`(
		IN ip_UserID INT
	,	IN ip_ReadNotificationID BIGINT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200922@Harvey.Nguyen
		Task:		Get probation customer for notification [Redmine ID: #142094]
		DB:			CTS_DataCenter
		Original:

		Revisions:
            - 20201006@Long.Luu[142414]: Get notifications by notification settings
            - 20201111@Irena.Vo[145028]: Enhance logic for display 1 scan time/day
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
            - 20210312@Aries.Nguyen: Enhance performance [Redmine ID: #151606]
            
		Param's Explanation (filtered by):
        
        Examples:
			-CALL CTS_DC_Notification_GetProbation(8,1);
	*/
	
    DECLARE lv_UserCurrentFromNotificationID 	BIGINT;
    DECLARE lv_UserCurrentToNotificationID 		BIGINT;
    DECLARE lv_MaxNotificationID 				BIGINT;
    DECLARE lv_FromScanDate						DATE;
	DECLARE lv_ToScanDate						DATE;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_UserPermissionGrantTime;
    CREATE TEMPORARY TABLE 		Temp_UserPermissionGrantTime (
			FromDate 		DATETIME
		,	ToDate 			DATETIME
        ,	PRIMARY KEY (FromDate, ToDate)
	); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_NotificationGrantTime;
    CREATE TEMPORARY TABLE 		Temp_NotificationGrantTime (
			FromDate 		DATETIME
		,	ToDate 			DATETIME
        ,	PRIMARY KEY  (FromDate, ToDate)
	);
    
    SET lv_ToScanDate = CURRENT_DATE();
	SET lv_FromScanDate = DATE(DATE_ADD(CURRENT_DATE(), INTERVAL -3 DAY));
    
    SELECT MAX(a.NotificationID)
    INTO lv_MaxNotificationID
    FROM CTS_DataCenter.ProbationAccountNotification AS a;    
    
	SELECT notiParam.FromNotificationID, notiParam.ToNotificationID
	INTO lv_UserCurrentFromNotificationID, lv_UserCurrentToNotificationID
	FROM CTS_DataCenter.CTSUserNotificationParameter AS notiParam
	WHERE notiParam.UserID = ip_UserID AND notiParam.FunctionID = 2;

    IF (ip_ReadNotificationID <> 0) THEN		
		SET 	lv_UserCurrentFromNotificationID = lv_UserCurrentToNotificationID
			,	lv_UserCurrentToNotificationID = ip_ReadNotificationID;

		UPDATE CTS_DataCenter.CTSUserNotificationParameter
		SET 	FromNotificationID = lv_UserCurrentFromNotificationID
			,	ToNotificationID = lv_UserCurrentToNotificationID
		WHERE UserID = ip_UserID AND FunctionID = 2;
	END IF;

    IF NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CTSUserNotificationParameter WHERE UserID = ip_UserID AND FunctionID = 2) THEN
		BEGIN
			INSERT INTO CTS_DataCenter.CTSUserNotificationParameter(UserID, FunctionID, FromNotificationID, ToNotificationID)
			VALUES(ip_UserID, 2,  (lv_MaxNotificationID + 1), lv_MaxNotificationID);
		END;
    END IF;
    


	INSERT IGNORE INTO Temp_UserPermissionGrantTime(FromDate, ToDate)
	SELECT  usPer.GrantedFrom
		,	IFNULL(usPer.GrantedTo, DATE_ADD(NOW(), INTERVAL 1 DAY))
	FROM CTS_DataCenter.CTSUserPermission AS usPer
	WHERE usPer.UserID = ip_UserID 
		AND usPer.FunctionID = 2
		AND usPer.GrantedFrom >= lv_FromScanDate;
	
	INSERT IGNORE INTO Temp_NotificationGrantTime(FromDate, ToDate)
	SELECT  noSe.GrantedFrom
		,	IFNULL(noSe.GrantedTo, DATE_ADD(NOW(), INTERVAL 1 DAY))
	FROM CTS_DataCenter.NotificationSettings AS noSe
	WHERE noSe.UserID = ip_UserID 
		AND noSe.FunctionID = 2
		AND noSe.GrantedFrom >= lv_FromScanDate;
    
	SELECT 	MAX(prAc.NotificationID) AS MaxNotificationID
		,	SUM(prAc.TotalScanned) AS TotalScanned
		,	SUM(prAc.TotalFailed) AS TotalFailed
        ,	SUM(prAc.TotalGeneralFailed) AS TotalGeneralFailed
        ,	1 AS NotificationType
        ,	prAc.CreatedDate
        ,	CASE WHEN MAX(prAc.NotificationID) <= lv_UserCurrentFromNotificationID THEN 1 ELSE 0 END AS IsSeen
	FROM CTS_DataCenter.ProbationAccountNotification AS prAc
    WHERE prAc.CreatedDate BETWEEN  lv_FromScanDate AND  lv_ToScanDate
		AND EXISTS (SELECT 1 FROM Temp_UserPermissionGrantTime WHERE prAc.CreatedTime BETWEEN FromDate AND ToDate)
		AND EXISTS (SELECT 1 FROM Temp_NotificationGrantTime WHERE prAc.CreatedTime BETWEEN FromDate AND ToDate)
    GROUP BY prAc.CreatedDate
    ORDER BY prAc.CreatedDate DESC;

END$$

DELIMITER ;