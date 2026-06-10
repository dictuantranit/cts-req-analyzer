/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustomerLatency_Queue_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustomerLatency_Queue_Get`(
	IN	ip_BatchSize	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250416@Thomas.Nguyen
		Task:	 	Get Customer from Latency Queue for Customer Latency Insert
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250416@Thomas.Nguyen: 	Created [Redmine ID: #223443]

		Param's Explanation (filtered by): 

		Example:
			CALL CTS_DC_CustomerLatency_Queue_Get (1000);
	*/ 
   
	SELECT	clq.CustID
		,	clq.LatencyType
	FROM CTS_DataCenter.CTSCustomerLatencyQueue AS clq
	ORDER BY clq.CustID ASC
	LIMIT ip_BatchSize;

END$$
DELIMITER ;