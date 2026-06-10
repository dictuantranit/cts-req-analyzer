/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transaction_GetHistory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transaction_GetHistory`(
		IN	ip_DateRange	INT
    ,	IN	ip_CTSCustId 	BIGINT    
    ,	IN	ip_Skip			INT
    ,	IN	ip_Take			INT
    ,	OUT	op_TotalItem	INT
    )
    SQL SECURITY INVOKER
proc_label: BEGIN
	/*
		Created:	20200311@Terry
		Task:		Get history transaction by date [Redmine ID: 130074]
		DB:			DCS_DataCenter
		Original:

		Revisions:
		- 20200518@lex.khuat: 		Update robot description from Green to Human [Redmine ID: #133934]
		- 20210121@John.Ngo: 		Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
		- 20210629@Casey.Huynh: 	Enhance SP and Return Flagged Value (Web will show type of robot) [Redmine ID: 157085]
		- 20230406@Casey.Huynh: 	Show trans cross subscriber [Redmine ID: 186086]
		- 20230512@Jonas.Huynh: 	BOTD transactions [Redmine ID: 185792]
		- 20230512@Victoria.Le:		Add option "Last 5 weeks" for ip_DateRange [Redmine ID: 187979]
		- 20250805@Long.Luu:		Cast IPID in case of data is too long [Redmine ID: 0000]
		- 20250923@Thomas.Nguyen:	Get more MB App transaction info [Redmine ID: #239121]

		Param's Explanation (filtered by):
			- ip_DateRange
				= 1: 	Last 24 hours
				= 14: 	Last 14 days
				= 35:	Last 5 weeks      

		Example:
			CALL DCS_DC_Transaction_GetHistory_xtest(35, 1003285680, 0, 500, @outParam4); SELECT @outParam4;
	*/ 
	DECLARE lv_FromRow INT;
    DECLARE lv_FromDate DATETIME;
    DECLARE lv_ToDate DATETIME;
    DECLARE lv_TotalRow INT DEFAULT 0;

    DROP TEMPORARY TABLE IF EXISTS Temp_Account;      
    CREATE TEMPORARY TABLE Temp_Account
	(
			AccountID	 	BIGINT(20)      
    );	
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
    CREATE TEMPORARY TABLE Temp_Transaction(	
			TransID			BIGINT UNSIGNED
		,	TransTime		DATETIME(4)    
		,	FirstDeviceCode	VARCHAR(64)
		,	IP				VARCHAR(50)
		,	IPID			DECIMAL(50,0)
		,	Flagged			VARCHAR(200)
		,	Action			VARCHAR(100)
		,	ActionResult	VARCHAR(100)
		,	OS				VARCHAR(100)
		,	Browser			VARCHAR(100)
		,	URLDetails		VARCHAR(250)
    );
	
    INSERT INTO Temp_Account 
	SELECT 	cusAcc.AccountID 
	FROM	CTS_DataCenter.CustDCSAccount cusAcc 
	WHERE 	cusAcc.CTSCustID = ip_CTSCustId;
		
	SET lv_ToDate 	= 	CURRENT_DATE();
	SET lv_FromDate = 	CASE 
							WHEN ip_DateRange > 0 THEN DATE_ADD(lv_ToDate, INTERVAL - ip_DateRange DAY)
							ELSE lv_ToDate
						END;                
	
	INSERT INTO Temp_Transaction(TransID, TransTime, FirstDeviceCode, IP, IPID, Flagged, Action, ActionResult, OS, Browser, URLDetails)
	SELECT	trs.TransID
		,	trs.TransTime
		,	trs.FirstDeviceCode
		,	trs.IP
		,	CAST(trs.IPID AS CHAR) AS IPID
		,	s.ItemName
		,	ar.Action
		,	ar.ActionResult
		,	uag.OS
		,	uag.Browser
		,	ur.URLDetails
	FROM	DCS_DataCenter.Transaction07 trs 
		LEFT JOIN DCS_DataCenter.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
		LEFT JOIN DCS_DataCenter.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
		LEFT JOIN DCS_DataCenter.URL AS ur ON trs.URLID = ur.URLID
		LEFT JOIN DCS_DataCenter.StaticList AS s ON s.ListID = 1 AND s.ItemID = trs.Flagged AND s.Status = 1
	WHERE trs.AccountID IN (SELECT AccountID FROM Temp_Account)
		AND trs.CreatedDate BETWEEN lv_FromDate AND lv_ToDate;
    
	/********* Get MB App transaction info *********/
	CALL DCS_DataCenter.CTSDCS_DC_CustInfo_AccountCustMapping(ip_CTSCustID);
	
	INSERT INTO Temp_Transaction(TransID, TransTime, FirstDeviceCode, IP, IPID, Flagged, Action, ActionResult, OS, Browser, URLDetails)
    SELECT	trs.MBRawTransactionID AS TransID
		,	trs.TransTime
		,	CAST(trs.MBDeviceID AS CHAR) AS FirstDeviceCode
		,	trs.IP
		,	CAST(trs.IPID AS CHAR) AS IPID
		,	s.ItemName AS Flagged
		,	ar.Action
		,	ar.ActionResult
		,	mb.OSName AS OS
		,	NULL AS Browser
		,	NULL AS URLDetails
	FROM	DCS_DataCenter.MBTransaction07 AS trs
		INNER JOIN Temp_CustDCSMBAccount AS cb ON cb.MBAccountID = trs.MBAccountID
		LEFT JOIN DCS_DataCenter.MBOS AS mb ON mb.ID = trs.MBOSID
		LEFT JOIN DCS_DataCenter.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
		LEFT JOIN DCS_DataCenter.StaticList AS s ON s.ListID = 1 AND s.ItemID = trs.Flagged AND s.Status = 1
	WHERE trs.CreatedDate BETWEEN lv_FromDate AND lv_ToDate;

	SELECT	TransID
		,	TransTime
		,	FirstDeviceCode
		,	IP
		,	IPID
		,	Flagged
		,	Action
		,	ActionResult
		,	OS
		,	Browser
		,	URLDetails 
	FROM Temp_Transaction
	ORDER BY TransTime DESC
	LIMIT ip_Skip, ip_Take;

    SELECT COUNT(1) INTO lv_TotalRow 
	FROM Temp_Transaction;

    SET op_TotalItem = lv_TotalRow;
    
END$$

DELIMITER ;
