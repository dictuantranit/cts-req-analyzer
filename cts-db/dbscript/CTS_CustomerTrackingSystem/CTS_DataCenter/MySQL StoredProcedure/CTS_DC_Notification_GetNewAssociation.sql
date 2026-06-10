/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Notification_GetNewAssociation`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Notification_GetNewAssociation`(
		IN 	ip_UserID 			INT UNSIGNED
    ,	IN 	ip_MaxNewAssID 		BIGINT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200706@Long.Luu
		Task:		Insert Associated Account Monitor [Redmine ID: #134652]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20200706@Long.Luu: Created [Redmine ID: #134652]
			- 20200818@Long.Luu: Get notifications based on permission granted time range [Redmine ID: #138575]
            - 20201006@Long.Luu: Get notifications by notification settings [Redmine ID: #142414]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: #148723]
			- 20210312@Aries.Nguyen: Enhance performance [Redmine ID: #151606]
         
		Param's Explanation (filtered by):
        
			call CTS_DC_Notification_GetNewAssociation(8,1);
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
        ,	INDEX IX_Temp_UserPermissionGrantTime_FromDate_ToDate(FromDate, ToDate)
	); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_NotificationGrantTime;
    CREATE TEMPORARY TABLE 		Temp_NotificationGrantTime (
			FromDate 		DATETIME
		,	ToDate 			DATETIME
        ,	INDEX IX_Temp_NotificationGrantTime_FromDate_ToDate(FromDate, ToDate)
	);
    
    SET lv_ToScanDate = CURRENT_DATE();
	SET lv_FromScanDate = DATE(DATE_ADD(CURRENT_DATE(), INTERVAL -3 DAY));
    
    SELECT MAX(a.AccountNewAssID)
    INTO lv_MaxNotificationID
    FROM CTS_DataCenter.AssociatedAccountNotification AS a;    

	SELECT u.FromNotificationID, u.ToNotificationID
	INTO lv_UserCurrentFromNotificationID, lv_UserCurrentToNotificationID
	FROM CTS_DataCenter.CTSUserNotificationParameter AS u
	WHERE u.UserID = ip_UserID AND u.FunctionID = 1;
            
    IF (ip_MaxNewAssID <> 0) THEN		
		SET 	lv_UserCurrentFromNotificationID = lv_UserCurrentToNotificationID
			,	lv_UserCurrentToNotificationID = ip_MaxNewAssID;
		UPDATE CTS_DataCenter.CTSUserNotificationParameter
		SET 	FromNotificationID = lv_UserCurrentToNotificationID
			,	ToNotificationID = lv_MaxNotificationID
		WHERE UserID = ip_UserID AND FunctionID = 1;        
	END IF;
    
    IF NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CTSUserNotificationParameter WHERE UserID = ip_UserID AND FunctionID = 1) THEN    
		BEGIN
			INSERT INTO CTS_DataCenter.CTSUserNotificationParameter(UserID, FunctionID, FromNotificationID, ToNotificationID)
			VALUES(ip_UserID, 1, (lv_MaxNotificationID + 1), lv_MaxNotificationID);
		END;
    END IF;
    
	INSERT INTO Temp_UserPermissionGrantTime(FromDate, ToDate)
	SELECT  usPer.GrantedFrom
		,	IFNULL(usPer.GrantedTo, DATE_ADD(NOW(), INTERVAL 1 DAY))
	FROM CTS_DataCenter.CTSUserPermission AS usPer
	WHERE usPer.UserID = ip_UserID 
		AND usPer.FunctionID = 1
		AND usPer.GrantedFrom >= lv_FromScanDate;

	INSERT INTO Temp_NotificationGrantTime(FromDate, ToDate)
	SELECT  noSe.GrantedFrom
		,	IFNULL(noSe.GrantedTo, DATE_ADD(NOW(), INTERVAL 1 DAY))
	FROM CTS_DataCenter.NotificationSettings AS noSe
	WHERE noSe.UserID = ip_UserID 
		AND noSe.FunctionID = 1
		AND noSe.GrantedFrom >= lv_FromScanDate ;


	# Get available notification
    SELECT 	a.CTSCustID
        ,	a.UserName
        ,	a.NewAssCount AS NewAssocitionCount
        ,	a.CreatedTime AS CreatedDate
        ,	a.AccountNewAssID AS MaxNewAssociationID
        ,	CASE WHEN a.AccountNewAssID <= lv_UserCurrentFromNotificationID THEN 1 ELSE 0 END AS IsSeen
        , 	a.AccountNewAssID
        ,	lv_UserCurrentFromNotificationID
    FROM CTS_DataCenter.AssociatedAccountNotification AS a
	WHERE a.CreatedDate BETWEEN  lv_FromScanDate AND lv_ToScanDate 
		AND EXISTS (SELECT 1 FROM Temp_UserPermissionGrantTime WHERE a.CreatedTime BETWEEN FromDate AND ToDate)
		AND EXISTS (SELECT 1 FROM Temp_NotificationGrantTime WHERE a.CreatedTime BETWEEN FromDate AND ToDate)
    ORDER BY CreatedDate DESC;

END$$

DELIMITER ;