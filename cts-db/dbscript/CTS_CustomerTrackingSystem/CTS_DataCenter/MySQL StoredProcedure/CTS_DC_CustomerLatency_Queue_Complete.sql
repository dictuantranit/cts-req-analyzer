/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustomerLatency_Queue_Complete`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustomerLatency_Queue_Complete`(
		IN 	ip_Customer		JSON
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250416@Thomas.Nguyen
		Task:	 	Clean up Customer from Latency Queue for Customer Latency Insert and move to Archive
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20241203@Thomas.Nguyen: 	Created [Redmine ID: #223443]
                
        Param's Explanation (filtered by): 

		Example:
			CALL CTS_DC_CustomerLatency_Queue_Complete (@ip_Customer:= 
            '[	{"CustID":1,"CustInfoRepUpdateTime": "2025-04-22 01:02:03.123456","SiteRepUpdateTime": "2025-04-22 01:02:03.223456","CustProductStatusRepUpdateTime": "2025-04-22 01:02:03.323456","DepCustSuperRepUpdateTime": "2025-04-22 01:02:03.423456"}
			,	{"CustID":2,"CustInfoRepUpdateTime": "2025-04-22 01:02:03.123456","SiteRepUpdateTime": "2025-04-22 01:02:03.223456","CustProductStatusRepUpdateTime": "2025-04-22 01:02:03.323456","DepCustSuperRepUpdateTime": "2025-04-22 01:02:03.423456"}
			,	{"CustID":3,"CustInfoRepUpdateTime": "2025-04-22 01:02:03.123456","SiteRepUpdateTime": "2025-04-22 01:02:03.223456","CustProductStatusRepUpdateTime": "2025-04-22 01:02:03.323456","DepCustSuperRepUpdateTime": "2025-04-22 01:02:03.423456"}
			]');
	*/

	DROP TEMPORARY TABLE IF EXISTS Temp_CustID;    
	CREATE TEMPORARY TABLE Temp_CustID( 	  
			CustID							BIGINT UNSIGNED PRIMARY KEY
		,	CustInfoRepUpdateTime			DATETIME(4)
		,	SiteRepUpdateTime				DATETIME(4)
		,	DepCustSuperRepUpdateTime		DATETIME(4)
		,	CustProductStatusRepUpdateTime	DATETIME(4)
	);

	INSERT IGNORE INTO Temp_CustID(CustID, CustInfoRepUpdateTime, SiteRepUpdateTime, DepCustSuperRepUpdateTime, CustProductStatusRepUpdateTime)
	SELECT 	js.CustID
		,	js.CustInfoRepUpdateTime
        ,	js.SiteRepUpdateTime
        ,	js.DepCustSuperRepUpdateTime
        ,	js.CustProductStatusRepUpdateTime
    FROM JSON_TABLE(ip_Customer,
					 "$[*]" COLUMNS(
								CustID							INT	PATH "$.CustID"
							,	CustInfoRepUpdateTime			DATETIME(6)	PATH "$.CustInfoRepUpdateTime"
                            ,	SiteRepUpdateTime				DATETIME(6)	PATH "$.SiteRepUpdateTime"
                            ,	DepCustSuperRepUpdateTime		DATETIME(6)	PATH "$.DepCustSuperRepUpdateTime"
                            ,	CustProductStatusRepUpdateTime	DATETIME(6)	PATH "$.CustProductStatusRepUpdateTime"
						)
				) AS js;
                
	INSERT INTO CTS_DataCenter.CTSCustomerLatencyQueue_Archive (CustID, LatencyType, QueueInsertedTime, InsertedTime, ArchivedDate
				, CustomerRepUpdateTime, CustInfoRepUpdateTime, SiteRepUpdateTime, DepCustSuperRepUpdateTime, CustProductStatusRepUpdateTime)
	SELECT	clq.CustID
		,	clq.LatencyType
		,	clq.InsertedTime AS QueueInsertedTime        
        ,	CURRENT_TIMESTAMP(3) AS InsertedTime
        ,	DATE(CURRENT_TIMESTAMP(3)) AS ArchivedDate
        ,	clq.CustomerRepUpdateTime
        ,	tmp.CustInfoRepUpdateTime
        ,	tmp.SiteRepUpdateTime
        ,	tmp.DepCustSuperRepUpdateTime
        ,	tmp.CustProductStatusRepUpdateTime
	FROM Temp_CustID AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomerLatencyQueue AS clq ON clq.CustID = tmp.CustID;

	DELETE clq
	FROM Temp_CustID AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomerLatencyQueue AS clq ON clq.CustID = tmp.CustID;

END$$
DELIMITER ;
