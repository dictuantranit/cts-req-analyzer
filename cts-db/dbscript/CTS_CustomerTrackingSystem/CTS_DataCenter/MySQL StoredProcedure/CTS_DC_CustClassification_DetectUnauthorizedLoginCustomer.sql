/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_DetectUnauthorizedLoginCustomer`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_DetectUnauthorizedLoginCustomer`(
		IN ip_ListCustJson  JSON
    ,   IN ip_ProcessedDate DATE
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20231226@Thomas.Nguyen
		Task :		Customer Classification - New CC 305/3005 System Detect Unauthorized Login
		DB:			CTS_DataCenter
		Original: 
		Revisions: 
			- 20231226@Thomas.Nguyen: Created [Redmine ID: #197710] 
            - 20240626@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode CategoryID and unused column [Redmine ID: #205317]
            - 20241105@Thomas.Nguyen: Hotfit - Can't reclassified CC305/3005 after unmarking PA [Redmine ID: #213302]

        Param's Explanation: 

		Example:
			-CALL CTS_DataCenter.CTS_DC_CustClassification_DetectUnauthorizedLoginCustomer

	*/
    DECLARE	CONST_CATEID_UNAUTHORIZEDLOGIN 			INT;

    DECLARE lv_FromDate                             DATE;
    DECLARE lv_SubSourceID_DirectAPI                TINYINT DEFAULT 1;
    DECLARE lv_SubSourceID_OddsFeed                 TINYINT DEFAULT 2;
    DECLARE lv_Percentage_Threshold                 DECIMAL(6,2) DEFAULT 50;
    
    SET CONST_CATEID_UNAUTHORIZEDLOGIN 		        = CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_UNAUTHORIZEDLOGIN');
    SET lv_FromDate = DATE_ADD(ip_ProcessedDate, INTERVAL -90 DAY);

    DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
	CREATE TEMPORARY TABLE 		Temp_Customer (
		 	CustID			BIGINT UNSIGNED		
        ,   CTSCustID 		BIGINT UNSIGNED
        ,   FirstBetDate    DATETIME(3)
        ,   SubscriberID	INT
        ,   RoleID          TINYINT
        ,   IsLicensee      BIT(1)
        ,   PRIMARY KEY PK_Temp_Customer(CTSCustID)
        ,   INDEX IX_Temp_Customer_CustID(CustID)
	);

    DROP TEMPORARY TABLE IF EXISTS Temp_CustAccountID;
    CREATE TEMPORARY TABLE Temp_CustAccountID(
            AccountID	BIGINT UNSIGNED PRIMARY KEY 
        ,	CTSCustID	BIGINT UNSIGNED 
        ,	INDEX		IX_Temp_CustAccountID_CTSCustID(CTSCustID)
    );

    DROP TEMPORARY TABLE IF EXISTS Temp_CustLogTransInfo;
	CREATE TEMPORARY TABLE 		Temp_CustLogTransInfo (
			CTSCustID 						    BIGINT UNSIGNED PRIMARY KEY
		,	CountLogin						    INT DEFAULT 0
        ,	CountBotTrans					    INT DEFAULT 0
        ,	CountInvalidBrowserTrans		    INT DEFAULT 0
        ,   BotTransPercentage                  DECIMAL(6,2)
        ,   InvalidBrowserInfoTransPercentage   DECIMAL(6,2)
	);

    DROP TEMPORARY TABLE IF EXISTS Temp_CustUnauthorizedLogin;
	CREATE TEMPORARY TABLE 		Temp_CustUnauthorizedLogin (
			CTSCustID 						    BIGINT UNSIGNED PRIMARY KEY
        ,   CustID			                    BIGINT UNSIGNED
        ,   FirstBetDate                        DATETIME(3)
        ,   SubscriberID                        INT
        ,   RoleID                              TINYINT
        ,   IsLicensee                          BIT(1)  
        ,	CountBotTrans					    INT DEFAULT 0
        ,	CountInvalidBrowserTrans		    INT DEFAULT 0
        ,   BotTransPercentage                  DECIMAL(6,2)
        ,   InvalidBrowserInfoTransPercentage   DECIMAL(6,2)
        ,   SourceCreatedDate                   DATETIME
	);

    DROP TEMPORARY TABLE IF EXISTS Temp_CustAccLogTransInfo;
    CREATE TEMPORARY TABLE 		Temp_CustAccLogTransInfo (
            AccountID						BIGINT UNSIGNED PRIMARY KEY
        ,	CTSCustID 						BIGINT UNSIGNED
        ,	CountLogin						INT DEFAULT 0
        ,	CountBotTrans					INT DEFAULT 0
        ,	CountInvalidBrowserTrans		INT DEFAULT 0
        ,	INDEX		IX_Temp_CustAccLogTransInfo_CTSCustID(CTSCustID)
    );

    DROP TEMPORARY TABLE IF EXISTS Temp_LoginTransactionSummary;
    CREATE TEMPORARY TABLE Temp_LoginTransactionSummary(
                AccountID	BIGINT UNSIGNED
            ,	TotalTrans	INT UNSIGNED
            ,	Flagged		SMALLINT
            ,	INDEX		IX_Temp_LoginTransactionSummary_AccountID(AccountID)        
    );

    INSERT IGNORE INTO Temp_Customer(CustID, CTSCustID, FirstBetDate, SubscriberID, RoleID, IsLicensee)
    SELECT  tmp.CustID
        ,   cus.CTSCustID
        ,   tmp.FirstBetDate
        ,   cus.SubscriberID
        ,   cus.RoleID
        ,   cus.IsLicensee
    FROM JSON_TABLE(ip_ListCustJson,
                        "$[*]" COLUMNS (CustID          BIGINT        UNSIGNED PATH "$.CustID"
                                    ,   FirstBetDate    DATETIME(3)            PATH "$.FirstBetDate"                                           
                                )) AS tmp
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmp.CustID AND IsInternal = 0
        LEFT JOIN CTS_DataCenter.CustomerLoginInfoDetection AS cld ON cld.CustID = tmp.CustID AND cld.IsDisabled = 0
    WHERE cld.CustID IS NULL;

    INSERT IGNORE INTO Temp_CustAccountID(CTSCustID, AccountID)
    SELECT  tmp.CTSCustID, acc.AccountID
    FROM Temp_Customer AS tmp
        INNER JOIN CTS_DataCenter.CustDCSAccount AS acc ON acc.CTSCustID = tmp.CTSCustID
        LEFT JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = tmp.SubscriberID AND sub.SubscriberSourceID IN (lv_SubSourceID_DirectAPI, lv_SubSourceID_OddsFeed)
    WHERE sub.SubscriberSourceID IS NULL;

    INSERT IGNORE INTO Temp_LoginTransactionSummary(AccountID, TotalTrans, Flagged)
    SELECT  tmp.AccountID, ls.TotalTrans, ls.Flagged
    FROM Temp_CustAccountID AS tmp
        INNER JOIN DCS_DataTrace.LoginTransactionSummary AS ls ON ls.AccountID = tmp.AccountID AND ls.TransDate BETWEEN lv_FromDate AND ip_ProcessedDate;

    INSERT IGNORE INTO Temp_CustAccLogTransInfo(CTSCustID, AccountID)
    SELECT  tmp.CTSCustID, tmp.AccountID
    FROM Temp_CustAccountID AS tmp;
 
    UPDATE Temp_CustAccLogTransInfo AS tmp
    SET tmp.CountLogin = IFNULL((SELECT SUM(sm.TotalLogin)
                                FROM DCS_DataCenter.SumAccountLogin AS sm
                                WHERE sm.AccountID = tmp.AccountID AND sm.TransDate BETWEEN lv_FromDate AND ip_ProcessedDate
                                GROUP BY sm.AccountID),0);

    UPDATE Temp_CustAccLogTransInfo AS tmp
    SET tmp.CountLogin = IFNULL((SELECT SUM(ls.TotalTrans) 
                                FROM Temp_LoginTransactionSummary AS ls
                                WHERE ls.AccountID = tmp.AccountID
                                GROUP BY ls.AccountID),tmp.CountLogin);
    
    WITH CTEAccountInfo AS (
        SELECT  ls.AccountID
            ,   SUM(CASE WHEN st.GroupID = 2 THEN ls.TotalTrans ELSE 0 END) AS CountInvalidBrowserTrans
            ,   SUM(CASE WHEN st.GroupID = 3 THEN ls.TotalTrans ELSE 0 END) AS CountBotTrans
        FROM Temp_LoginTransactionSummary AS ls
            INNER JOIN DCS_DataCenter.StaticList AS st ON st.ItemID = ls.Flagged AND st.ListID = 1
            INNER JOIN Temp_CustAccountID AS tmp ON tmp.AccountID = ls.AccountID
        GROUP BY ls.AccountID
    )
    UPDATE Temp_CustAccLogTransInfo AS tmp
        INNER JOIN CTEAccountInfo AS tc ON tc.AccountID = tmp.AccountID
    SET     tmp.CountBotTrans = tc.CountBotTrans
        ,   tmp.CountInvalidBrowserTrans = tc.CountInvalidBrowserTrans
    WHERE tc.CountBotTrans <> 0 OR tc.CountInvalidBrowserTrans <> 0;
    
    INSERT IGNORE INTO Temp_CustLogTransInfo(CTSCustID, CountLogin, CountBotTrans, CountInvalidBrowserTrans, BotTransPercentage, InvalidBrowserInfoTransPercentage)
    WITH CTECustInfo AS (
        SELECT  ct.CTSCustID AS CTSCustID
            ,   SUM(IFNULL(CountLogin,0)) AS CountLogin
            ,   SUM(IFNULL(CountBotTrans,0)) AS CountBotTrans
            ,   SUM(IFNULL(CountInvalidBrowserTrans,0)) AS CountInvalidBrowserTrans
        FROM Temp_CustAccLogTransInfo AS ct
        GROUP BY ct.CTSCustID
    )
    SELECT  cte.CTSCustID, cte.CountLogin, cte.CountBotTrans, cte.CountInvalidBrowserTrans
        ,   ROUND((cte.CountBotTrans/cte.CountLogin)*100,2) AS BotTransPercentage
        ,   ROUND((cte.CountInvalidBrowserTrans/cte.CountLogin)*100,2) AS InvalidBrowserInfoTransPercentage
    FROM CTECustInfo AS cte;

    INSERT IGNORE INTO Temp_CustUnauthorizedLogin(CTSCustID, CustID, FirstBetDate, SubscriberID, RoleID, IsLicensee, CountBotTrans, CountInvalidBrowserTrans, BotTransPercentage, InvalidBrowserInfoTransPercentage, SourceCreatedDate)
    SELECT ct.CTSCustID, cus.CustID, cus.FirstBetDate, cus.SubscriberID, cus.RoleID, cus.IsLicensee, ct.CountBotTrans, ct.CountInvalidBrowserTrans, ct.BotTransPercentage, ct.InvalidBrowserInfoTransPercentage, ip_ProcessedDate
    FROM Temp_CustLogTransInfo AS ct
        INNER JOIN Temp_Customer AS cus ON cus.CTSCustID = ct.CTSCustID
    WHERE ct.BotTransPercentage > lv_Percentage_Threshold OR ct.InvalidBrowserInfoTransPercentage > lv_Percentage_Threshold;
    
    INSERT IGNORE INTO CTS_DataCenter.CustomerLoginInfoDetection(CTSCustID, CustID, FirstBetDate, Bot, InvalidBrowser, BotTransPercentage, InvalidBrowserInfoTransPercentage, SourceCreatedDate) 
    SELECT ct.CTSCustID, ct.CustID, ct.FirstBetDate, ct.CountBotTrans, ct.CountInvalidBrowserTrans, ct.BotTransPercentage, ct.InvalidBrowserInfoTransPercentage, ct.SourceCreatedDate
    FROM Temp_CustUnauthorizedLogin AS ct;
    
    /*Return data*/
    SELECT  CTSCustID
        ,   CustID
        ,   SubscriberID
        ,   RoleID
        ,   IsLicensee
        ,   CONST_CATEID_UNAUTHORIZEDLOGIN AS CategoryID
    FROM Temp_CustUnauthorizedLogin AS ct;

END$$
DELIMITER ;