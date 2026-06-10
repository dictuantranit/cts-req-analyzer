/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_MonitorTransaction_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_MonitorTransaction_Insert`(
		IN ip_RptDate 	DATE,
		IN ip_TransJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20230615@Jonathan.Doan
	    Task : Store data Monitor Transaction
	    DB: DCS_DataCenter
	    Original:

	    Revisions:		    
			-	20230615@Jonathan.Doan: Created [Redmine ID: 189732]
            
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DC_MonitorTransaction_Insert('[]');
    */    
     DECLARE lv_CurrentDate DATETIME DEFAULT CURRENT_TIMESTAMP();
    
     DROP TEMPORARY TABLE IF EXISTS Temp_InputTrans;
     CREATE TEMPORARY TABLE Temp_InputTrans(
        	CustID			INT UNSIGNED PRIMARY KEY
        ,   UserName		VARCHAR(50) NULL
        ,   LoginName		VARCHAR(50) NULL
        ,   SubscriberID	INT UNSIGNED NULL
        ,   CTSSiteID		INT UNSIGNED NULL
        ,   CTSSite			VARCHAR(50) NULL
        ,   MainSite		VARCHAR(50) NULL
        ,   CreatedDate		DATETIME NULL
        ,   FirstLoginDate	DATETIME NULL
        ,   LastLoginDate	DATETIME NULL
        ,   LastTicketDate	DATETIME NULL
     );

    INSERT INTO Temp_InputTrans(CustID, UserName, MainSite)
	SELECT	tmp.CustID
		,	tmp.Username AS UserName
		,	tmp.SiteName AS MainSite
    FROM JSON_TABLE(
			ip_TransJson,
			 "$[*]" COLUMNS(
							CustID				INT UNSIGNED	PATH "$.CustID"
						,	Username			VARCHAR(50)		PATH "$.Username"
						,	SiteName			VARCHAR(50)		PATH "$.SiteName"
					)
		) AS tmp;
        
	DELETE tmp
    FROM Temp_InputTrans AS tmp
		INNER JOIN DCS_DataCenter.MonitorTransaction AS mt ON mt.CustID = tmp.CustID
	WHERE mt.LastScanDate = ip_RptDate;
    
    DELETE tmp
    FROM Temp_InputTrans AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmp.CustID
		INNER JOIN CTS_DataCenter.CustDCSAccount AS cda ON cda.CTSCustID = cus.CTSCustID
		INNER JOIN DCS_DataCenter.Transaction07 AS trans ON trans.AccountID = cda.AccountID
    WHERE trans.CreatedDate = ip_RptDate;
        
    UPDATE Temp_InputTrans AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cts ON cts.CustID = tmp.CustID
		LEFT JOIN CTS_DataCenter.CustDCSAccount AS dcs ON dcs.CTSCustID = cts.CTSCustID
		LEFT JOIN DCS_DataCenter.Account AS acc ON acc.AccountID = dcs.AccountID
		LEFT JOIN CTS_Archive.CTSCustomerAssociationStatus AS cas ON cas.CTSCustID = cts.CTSCustID
	SET 	tmp.LoginName = cts.RegisterName
		,	tmp.SubscriberID = cts.SubscriberID
		,	tmp.CTSSiteID = cts.SiteID
		,	tmp.CTSSite = cts.Site
		,	tmp.CreatedDate = cts.CreatedDate
		,	tmp.FirstLoginDate = acc.CreatedDate
		,	tmp.LastLoginDate = acc.LastLoginTime
		,	tmp.LastTicketDate = cas.LastTicketDate;
    
	INSERT INTO DCS_DataCenter.MonitorTransaction(CustID, UserName, LoginName, SubscriberID, CTSSiteID, CTSSite, MainSite, CreatedDate, FirstLoginDate, LastLoginDate, LastTicketDate, FirstScanDate, LastScanDate, ScanCounter)
    SELECT	tmp.CustID
		,	tmp.UserName
		,	tmp.LoginName
		,	tmp.SubscriberID
		,	tmp.CTSSiteID
		,	tmp.CTSSite
		,	tmp.MainSite
		,	tmp.CreatedDate
		,	tmp.FirstLoginDate
		,	tmp.LastLoginDate
		,	tmp.LastTicketDate
		,	ip_RptDate AS FirstScanDate
		,	ip_RptDate AS LastScanDate
		,	1 AS ScanCounter
    FROM Temp_InputTrans AS tmp
    ON DUPLICATE KEY UPDATE LastLoginDate = tmp.LastLoginDate
						,	LastTicketDate = tmp.LastTicketDate
						,	LastScanDate = ip_RptDate
						,	ScanCounter = ScanCounter + 1;
    
END$$
DELIMITER ;
