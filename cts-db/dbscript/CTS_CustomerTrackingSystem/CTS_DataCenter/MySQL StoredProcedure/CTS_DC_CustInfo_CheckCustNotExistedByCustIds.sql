DELIMITER $$
USE CTS_DataCenter $$
DROP PROCEDURE IF EXISTS CTS_DC_CustInfo_CheckCustNotExistedByCustIds $$

CREATE DEFINER=`fps`@`%` PROCEDURE `CTS_DC_CustInfo_CheckCustNotExistedByCustIds`(
	  IN ip_CustIDList VARCHAR(2000)
    , IN ip_FromDate DATETIME
    , IN ip_ToDate DATETIME)
BEGIN
	/*
		Created:	20201002@Harvey.Nguyen
		Task :		Check customer if they are existed in CTSCustomer
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20200820@Long.Luu: Created [Redmine ID: 139701]
		
		Param's Explanation (filtered by):
        
        call CTS_DC_CustInfo_CheckCustNotExistedByCustIds("72,1261,1262,1264","2020-09-28 00:00:00.0000","2020-09-28 00:00:00.0000");
	*/
    
    DROP TABLE IF EXISTS TempCustomer;
    CREATE TEMPORARY TABLE TempCustomer(
			CustID 	INT PRIMARY KEY
	);
    
	SET @sql = CONCAT("INSERT INTO TempCustomer (CustID) VALUES ('", REPLACE(ip_CustIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    
    SELECT tcust.CustID
	FROM TempCustomer tcust
		LEFT JOIN CTS_DataCenter.CTSCustomer cust ON tcust.CustID = cust.CustID AND cust.CustSubID = 0
		LEFT JOIN CTS_DataCenter.CustDCSAccount cusAcc ON cusAcc.SubscriberID = cust.SubscriberID AND cusAcc.CTSCustID = cust.CTSCustID
		LEFT JOIN DCS_DataCenter.Transaction07 tran ON  tran.SubscriberID = cusAcc.SubscriberID
			AND tran.AccountID = cusAcc.AccountID 
			AND tran.CreatedDate BETWEEN ip_FromDate AND ip_ToDate
    WHERE tran.AccountID IS NULL AND cust.SubscriberID IN (2,6,112,116,121,122,130,138,142,165,166,168,169,189,220,221,2338,2339,2364,2372,13659);
        
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    
    -- DROP TABLE TempCustomer;
    
END$$
DELIMITER ;