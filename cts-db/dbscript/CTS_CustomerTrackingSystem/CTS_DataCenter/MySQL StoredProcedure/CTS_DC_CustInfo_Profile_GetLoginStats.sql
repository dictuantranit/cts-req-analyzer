/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_Profile_GetLoginStats`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_Profile_GetLoginStats`(
		IN ip_CTSCustID BIGINT UNSIGNED
	,	IN ip_FromDate	DATE
    ,	IN ip_ToDate	DATE
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20211214@Aries.Nguyen	
		Task :		Enrich the information on customer profile
		DB:			CTS_DataCenter
		
		Revisions:
			- 20211214@Aries.Nguyen: Created [Redmine ID: #165105]
			- 20231025@Jonas.Huynh: Get Invalid Browser Info and Bot Transaction [Redmine ID: #195095]
            - 20250923@Thomas.Nguyen: Get more MB Account login info [Redmine ID: #239121]
			- 20251016@Thomas.Nguyen: Hotfix Cannot count MB App Device/IP when TransDate > From and LastAccessedDate = Today [Redmine ID: #241782]

		Param's Explanation (filtered by):
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustInfo_Profile_GetLoginStats_xtest(2570300, '2023-08-07', '2023-11-07');
	*/
	DECLARE lv_CountDesktopDevice_TillYesterday 		INT;
    DECLARE lv_CountMobileDevice_TillYesterday 			INT;
    DECLARE lv_CountDesktopDevice_YesterdayTillNow 		INT;
    DECLARE lv_CountMobileDevice_YesterdayTillNow 		INT;
    DECLARE lv_Count_Login					INT;
    DECLARE lv_Count_Login_OnTheFly			INT;
    DECLARE lv_Count_IP						INT;
    DECLARE lv_Count_Device					INT;
    DECLARE lv_Count_Bot_Trans				INT;
    DECLARE lv_Count_InvalidBrowser_Trans	INT;

    DECLARE lv_Count_MBAppLogin									INT;
	DECLARE lv_Count_MBAppLogin_OnTheFly						INT;
    DECLARE lv_Count_MBAppIP									INT;
    DECLARE lv_Count_MBAppDevice								INT;
    DECLARE lv_Count_MBAppBot_Trans								INT;
    DECLARE lv_Count_MBAppInvalidBrowser_Trans					INT;

	DECLARE lv_CustInsertedTime									DATETIME(4);
	DECLARE lv_CustInsertedDate									DATE;
    
    DECLARE lv_IsExcludeSubscriber			BIT DEFAULT(0); 	
    DECLARE lv_SubSourceID_DirectAPI		TINYINT DEFAULT(1);
	DECLARE lv_SubSourceID_OddsFeed			TINYINT DEFAULT(2);
        
    DROP TEMPORARY TABLE IF EXISTS Temp_AccountID;
	CREATE TEMPORARY TABLE Temp_AccountID(
			AccountID	BIGINT UNSIGNED PRIMARY KEY
	);	

	SELECT 	IFNULL(cus.InsertedTime, cus.CreatedDate)
	INTO 	lv_CustInsertedTime
	FROM CTS_DataCenter.CTSCustomer AS cus
	WHERE cus.CTSCustID = ip_CTSCustID;
	
	SET lv_CustInsertedDate = DATE(lv_CustInsertedTime);

    SELECT 1
    INTO lv_IsExcludeSubscriber
    FROM CTS_DataCenter.CTSCustomer AS cus
		INNER JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = cus.SubscriberID
	WHERE cus.CTSCustID = ip_CTSCustID 
		AND sub.SubscriberSourceID IN (lv_SubSourceID_DirectAPI, lv_SubSourceID_OddsFeed);
    
    IF (lv_IsExcludeSubscriber = 0)
    THEN
	    INSERT IGNORE INTO Temp_AccountID(AccountID)
		SELECT AccountID 
		FROM CTS_DataCenter.CustDCSAccount
		WHERE  CTSCustID  = ip_CTSCustID; 
    
		SELECT  IFNULL(SUM(sm.DeviceDesktop),0)
			,   IFNULL(SUM(sm.DeviceMobile),0)
			,   IFNULL(SUM(sm.TotalLogin),0)
		INTO 	lv_CountDesktopDevice_TillYesterday
			,	lv_CountMobileDevice_TillYesterday
			,	lv_Count_Login
		FROM DCS_DataCenter.SumAccountLogin AS sm
		WHERE sm.AccountID IN (SELECT tmp.AccountID FROM Temp_AccountID AS tmp )
			AND sm.TransDate BETWEEN ip_FromDate AND ip_ToDate; 
		
		SELECT  COUNT(1)
		INTO 	lv_Count_IP
		FROM DCS_DataCenter.AccountIP AS ip
		WHERE ip.AccountID IN (SELECT tmp.AccountID FROM Temp_AccountID AS tmp )
			AND ip.LastTransDate BETWEEN ip_FromDate AND ip_ToDate AND ip.IP <> ''; 
		
		SELECT  COUNT(1)
		INTO 	lv_Count_Device
		FROM DCS_DataCenter.AccountDevice AS dv
		WHERE dv.AccountID IN (SELECT tmp.AccountID FROM Temp_AccountID AS tmp )
			AND dv.LastTransDate BETWEEN ip_FromDate AND ip_ToDate AND IFNULL(dv.DeviceID, 0) > 0; 
		
		SELECT  SUM(CASE WHEN st.GroupID = 2 THEN lg.TotalTrans ELSE 0 END) AS Invalid
			,	SUM(CASE WHEN st.GroupID = 3 THEN lg.TotalTrans ELSE 0 END) AS Bot
		INTO 	lv_Count_InvalidBrowser_Trans
			,	lv_Count_Bot_Trans
		FROM DCS_DataTrace.LoginTransactionSummary AS lg
			INNER JOIN DCS_DataCenter.StaticList AS st ON st.ItemID = lg.Flagged AND st.ListID = 1
		WHERE lg.AccountID IN (SELECT tmp.AccountID FROM Temp_AccountID AS tmp )
			AND lg.TransDate BETWEEN ip_FromDate AND ip_ToDate; 
            
		/* Correct Mobile/Desktop Trans */
        DROP TEMPORARY TABLE IF EXISTS Temp_AccountLastSummedDate;
		CREATE TEMPORARY TABLE Temp_AccountLastSummedDate(
				AccountID		BIGINT UNSIGNED PRIMARY KEY
			,	LastSummedDate	DATE
		) ENGINE=InnoDB;
        
        DROP TEMPORARY TABLE IF EXISTS Temp_AccountTransUserAgent;
		CREATE TEMPORARY TABLE Temp_AccountTransUserAgent(
				TransID			BIGINT UNSIGNED PRIMARY KEY
			,	UserAgentKey	VARCHAR(32)
		) ENGINE=InnoDB;
		
		INSERT INTO Temp_AccountLastSummedDate(AccountID, LastSummedDate)
        SELECT 	tmp.AccountID, 
				IFNULL(DATE_ADD(MAX(sm.TransDate), INTERVAL 1 DAY), ip_FromDate)
		FROM Temp_AccountID AS tmp
			LEFT JOIN DCS_DataCenter.SumAccountLogin AS sm ON sm.AccountID = tmp.AccountID
		GROUP BY tmp.AccountID;
                
        INSERT IGNORE INTO Temp_AccountTransUserAgent(TransID, UserAgentKey)
		SELECT  t.TransID
			,	t.UserAgentKey
		FROM DCS_DataCenter.Transaction07 AS t
			INNER JOIN Temp_AccountLastSummedDate AS a ON t.AccountID = a.AccountID AND t.CreatedDate >= a.LastSummedDate;
		
        SELECT COUNT(1) + lv_Count_Login
        INTO lv_Count_Login_OnTheFly
        FROM Temp_AccountTransUserAgent;
        
		SELECT 	IFNULL(SUM(CASE WHEN dv.GroupName = 'Mobile' THEN 1 ELSE 0 END),0) AS DeviceMobile
			,	IFNULL(SUM(CASE WHEN dv.GroupName = 'Desktop' THEN 1 ELSE 0 END),0) AS DeviceDesktop
		INTO 	lv_CountMobileDevice_YesterdayTillNow
			,	lv_CountDesktopDevice_YesterdayTillNow
        FROM Temp_AccountTransUserAgent AS t
			LEFT JOIN DCS_DataCenter.UserAgent  AS ua ON ua.UserAgentKey  = t.UserAgentKey
			LEFT JOIN DCS_DataCenter.DeviceType AS dv ON dv.DeviceTypeID = ua.DeviceTypeID;
        /* END Correct Mobile/Desktop Trans */
        
        /* Correct Total Trans */
        SELECT  SUM(TotalTrans)
		INTO 	lv_Count_Login
		FROM DCS_DataTrace.LoginTransactionSummary
		WHERE AccountID IN (SELECT tmp.AccountID FROM Temp_AccountID AS tmp )
			AND TransDate BETWEEN ip_FromDate AND ip_ToDate;
        /* END Correct Total Trans */

		/********* Get MB Account login info from SUM table *********/
		CALL CTS_DataCenter.CTSDCS_DC_CustInfo_AccountCustMapping(ip_CTSCustID);
		
		SELECT  IFNULL(SUM(CASE WHEN lg.FlaggedGroupID = 2 THEN lg.TotalTrans ELSE 0 END),0) AS Invalid
			,	IFNULL(SUM(CASE WHEN lg.FlaggedGroupID = 3 THEN lg.TotalTrans ELSE 0 END),0) AS Bot
		INTO 	lv_Count_MBAppInvalidBrowser_Trans
			,	lv_Count_MBAppBot_Trans
		FROM Temp_CustDCSMBAccount AS tmp
			INNER JOIN DCS_DataTrace.MBLoginTransactionSummary AS lg ON lg.MBAccountID = tmp.MBAccountID
		WHERE lg.TransDate BETWEEN ip_FromDate AND ip_ToDate; 

		SELECT SUM(lg.TotalTrans)
		INTO lv_Count_MBAppLogin
		FROM Temp_CustDCSMBAccount AS tmp
			INNER JOIN DCS_DataTrace.MBLoginTransactionSummary AS lg ON lg.MBAccountID = tmp.MBAccountID
		WHERE lg.TransDate BETWEEN ip_FromDate AND ip_ToDate;

		/********* Get more MB Account login info from MBTransaction07 *********/
		SELECT COUNT(DISTINCT ts.IPID)
		INTO lv_Count_MBAppIP
		FROM Temp_CustDCSMBAccount AS tmp
			INNER JOIN DCS_DataCenter.MBTransaction07 AS ts ON ts.MBAccountID = tmp.MBAccountID
		WHERE ts.TransTime >= GREATEST(ip_FromDate, lv_CustInsertedTime) 
			AND ts.TransTime < ip_ToDate 
			AND IFNULL(ts.IPID, 0) > 0;

		SELECT	COUNT(DISTINCT ts.MBDeviceID)
		INTO	lv_Count_MBAppDevice
		FROM Temp_CustDCSMBAccount AS tmp
			INNER JOIN DCS_DataCenter.MBTransaction07 AS ts ON ts.MBAccountID = tmp.MBAccountID
		WHERE ts.TransTime >= GREATEST(ip_FromDate, lv_CustInsertedTime) 
			AND ts.TransTime < ip_ToDate 
			AND IFNULL(ts.MBDeviceID, 0) > 0;

		SELECT COUNT(ts.ID)
		INTO 	lv_Count_MBAppLogin_OnTheFly
		FROM Temp_CustDCSMBAccount AS tmp
			INNER JOIN DCS_DataCenter.MBTransaction07 AS ts ON ts.MBAccountID = tmp.MBAccountID
		WHERE ts.TransTime >= GREATEST(ip_FromDate, lv_CustInsertedTime) AND ts.TransTime < DATE_ADD(ip_ToDate, INTERVAL 1 DAY);
		
		SELECT 	IFNULL(lv_Count_Bot_Trans,0) + IFNULL(lv_Count_MBAppBot_Trans,0)				AS BotTrans
			,	ROUND((IFNULL(lv_Count_Bot_Trans,0) + IFNULL(lv_Count_MBAppBot_Trans,0))/(IFNULL(lv_Count_Login,0) + IFNULL(lv_Count_MBAppLogin,0))*100,2) AS BotTransPercentage
			,	IFNULL(lv_Count_InvalidBrowser_Trans,0) + IFNULL(lv_Count_MBAppInvalidBrowser_Trans,0) AS InvalidBrowser
			,	ROUND((IFNULL(lv_Count_InvalidBrowser_Trans,0) + IFNULL(lv_Count_MBAppInvalidBrowser_Trans,0))/(IFNULL(lv_Count_Login,0) + IFNULL(lv_Count_MBAppLogin,0))*100,2) AS InvalidBrowserPercentage
			,	lv_CountDesktopDevice_TillYesterday	+ lv_CountDesktopDevice_YesterdayTillNow	AS DesktopUsage
			,	lv_CountMobileDevice_TillYesterday + lv_CountMobileDevice_YesterdayTillNow		AS MBWebUsage
			,	IFNULL(lv_Count_MBAppLogin_OnTheFly,0)											AS MBAppUsage
			,	IFNULL(lv_Count_IP,0) + IFNULL(lv_Count_MBAppIP,0) 								AS IP
			,	IFNULL(lv_Count_Device,0) + IFNULL(lv_Count_MBAppDevice,0) 						AS Device
			,	lv_Count_Login_OnTheFly + IFNULL(lv_Count_MBAppLogin_OnTheFly,0)				AS Login;
	END IF;
END$$

DELIMITER ;