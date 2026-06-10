/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustomerLatency_Queue_Insert`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustomerLatency_Queue_Insert`(		
		IN 	ip_LatencyType 	SMALLINT
    ,	IN 	ip_Customer		JSON
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250416@Thomas.Nguyen
		Task:	 	Insert Customer into Latency Queue for Customer Latency Insert
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250416@Thomas.Nguyen: 	Created [Redmine ID: #223443]
                
		Param's Explanation (filtered by): 
			@ip_LatencyType: '2: New Customer - Missing Customer, 3: New Customer - Missing CustInfo, Reactivated Customer - Missing'
        
		Example:
			CALL CTS_DC_CustomerLatency_Queue_Insert(@ip_LatencyType:=2, @ip_Customer:='[{"CustID":1,"CustomerRepUpdateTime":"2025-04-22 01:02:03.023456"}]');
            CALL CTS_DC_CustomerLatency_Queue_Insert(@ip_LatencyType:=3, @ip_Customer:='[{"CustID":2,"CustomerRepUpdateTime":null}]');
	*/
    
	INSERT IGNORE INTO CTS_DataCenter.CTSCustomerLatencyQueue(CustID, CustomerRepUpdateTime, LatencyType)
    SELECT  js.CustID
		,	js.CustomerRepUpdateTime
		,	ip_LatencyType	
	FROM JSON_TABLE(ip_Customer,
					 "$[*]" COLUMNS(
								CustID					INT	PATH "$.CustID"
							,	CustomerRepUpdateTime	DATETIME(6)	PATH "$.CustomerRepUpdateTime"
						)
				) AS js;  
    

END$$
DELIMITER ;