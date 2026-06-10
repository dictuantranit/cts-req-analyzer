/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_Queue_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustClassification_Queue_Insert`(    	
     	IN ip_CTSCustID			BIGINT UNSIGNED
    ,	IN ip_CustID			BIGINT UNSIGNED
    ,	IN ip_SubscriberID		INT
	,	IN ip_CategoryID		INT
    , 	IN ip_Remark 			VARCHAR(300)
	,	IN ip_CreatedBy 		INT
    ,	IN ip_RoleID			TINYINT
    ,	IN ip_ActionType		TINYINT 
)
    SQL SECURITY INVOKER 
BEGIN
	/*
		Created:	20220418@Casey.Huynh	
		Task :		Insert CustClassificationDownline
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20220418@Casey.Huynh: Add and Remove VVIP for Downline [Redmine ID: #159013]
			- 20240628@Thomas.Nguyen: Renovate CC phase 2 - Change datatype for ip_CategoryID to INT [Redmine ID: #205317]

		Param's Explanation:
			ip_ActionType: 1-Insert, 2-Remove
        
        Example: 
			CALL CTS_DC_CustClassification_Queue_Insert(2998,179747,2,110,'Test Insert',78,3,1);
	*/ 

	INSERT INTO CTS_DataCenter.CTSCustomerClassificationQueue(CTSCustID, CustID, RoleID, SubscriberID, CreatedBy, Remark, CategoryID, LastDownlineCTSCustID, ActionType, InsertTime)
    SELECT ip_CTSCustID, ip_CustID, ip_RoleID, ip_SubscriberID, ip_CreatedBy, ip_Remark, ip_CategoryID, 0 AS LastDownlineCTSCustID, ip_ActionType, CURRENT_TIMESTAMP(3);

END$$
DELIMITER ;