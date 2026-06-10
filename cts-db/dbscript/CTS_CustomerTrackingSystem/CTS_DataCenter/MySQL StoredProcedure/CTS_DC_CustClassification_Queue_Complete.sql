/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin,ctsServiceAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustClassification_Queue_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Queue_Complete`(    	
		IN ip_QueueID      				BIGINT UNSIGNED
	,  	IN ip_LastDownlineCTSCustID     BIGINT
)
    SQL SECURITY INVOKER
BEGIN 
	/*
		Created:	20220601@Casey.Huynh	
		Task :		Renovate PA Process [Redmine ID: #172061]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20220601@Casey.Huynh: Created [Redmine ID: #172061]

		Param's Explanation: 
        
        Example: CALL CTS_DC_CustClassification_Queue_Complete(1,2);
	*/ 
    IF ip_LastDownlineCTSCustID = -1 THEN
		DELETE 
        FROM  CTS_DataCenter.CTSCustomerClassificationQueue AS que 
        WHERE que.ID = ip_QueueID; 
    END IF;
	UPDATE CTS_DataCenter.CTSCustomerClassificationQueue AS que
	SET que.LastDownlineCTSCustID = ip_LastDownlineCTSCustID
	WHERE que.ID = ip_QueueID;

END$$

DELIMITER ;

