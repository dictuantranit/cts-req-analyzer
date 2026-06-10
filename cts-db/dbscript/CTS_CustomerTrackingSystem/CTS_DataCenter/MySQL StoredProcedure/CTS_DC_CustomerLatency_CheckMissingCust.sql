/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustomerLatency_CheckMissingCust`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustomerLatency_CheckMissingCust`(
		IN ip_CustomerList 	JSON
	,	IN ip_LastCTSCustID	BIGINT
    ,	IN ip_QueryTypeID	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20201213@Harvey
		Task:		Monitor Insert Customer [Redmine ID: 116528]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20211213@Harvey: Initial
			- 20230228@Jonas.Huynh: Update SP [Redmine ID: 183278]
            - 20240223@Jonas.Huynh: Customer Info Monitoring  [Redmine ID: 198000]
            - 20241213@Jonas.Huynh: Missing Customer [Redmine ID: 214157]
            - 20250416@Thomas.Nguyen: Rename SP from CTS_DC_Monitoring_MissingCustomer_Check [Redmine ID: #223443]

		Param's Explanation (filtered by):
			- ip_QueryTypeID: 1-Customer Missing, 2-Incorrect CustInfo
            
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustomerLatency_CheckMissingCust (
            '[{"CustID":82355840,"CustSubID":0}]', NULL, 1);

	*/
    DECLARE lv_MaxCTSCustID		BIGINT;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomer;    
	CREATE TEMPORARY TABLE Temp_CTSCustomer(
			CustID			INT	UNSIGNED 
		,	CustSubID 		INT	UNSIGNED
        ,	PRIMARY KEY (CustID, CustSubID)
	);
	
    INSERT INTO Temp_CTSCustomer(CustID, CustSubID)
	SELECT	 	CustID	
			,	CustSubID
	FROM JSON_TABLE(ip_CustomerList,
		 "$[*]" COLUMNS(
				CustID		INT	UNSIGNED	PATH "$.CustID" 
			,	CustSubID	INT	UNSIGNED 	PATH "$.CustSubID"
			)
	) AS js; 
    
    IF ip_QueryTypeID = 2 THEN
        SET lv_MaxCTSCustID = (SELECT MAX(CTSCustID) FROM CTS_DataCenter.CTSCustomer);

		SELECT DISTINCT CustID
		FROM CTS_DataCenter.CTSCustomer AS c
			LEFT JOIN CTS_DataCenter.MappingSubscriberSite AS m ON m.SiteID = c.SiteID
		WHERE c.CTSCustID > ip_LastCTSCustID 
			AND c.CTSCustID <= lv_MaxCTSCustID
			AND c.CurrencyID NOT IN (20,27,28)
			AND (c.IsLicensee IS NULL
				OR c.SiteID = 0
				OR (c.SubscriberID IS NULL AND m.SubscriberID IS NOT NULL)
				OR c.Site IS NULL 
				OR c.UserName IS NULL);
			
        SELECT lv_MaxCTSCustID;
	ELSE		
		SELECT 	tcust.CustID
			,	tcust.CustSubID
		FROM Temp_CTSCustomer AS tcust
			LEFT JOIN CTS_DataCenter.CTSCustomer AS cust ON tcust.CustID = cust.CustID AND tcust.CustSubID = cust.CustSubID
		WHERE cust.CustID IS NULL;
    END IF;

END$$
DELIMITER ;