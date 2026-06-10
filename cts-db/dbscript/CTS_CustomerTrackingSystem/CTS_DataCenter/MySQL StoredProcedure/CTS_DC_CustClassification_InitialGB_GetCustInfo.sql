/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_InitialGB_GetCustInfo`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_InitialGB_GetCustInfo`(
	IN ip_CustIDs LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240422@Thomas.Nguyen
		Task :		Get cust info for initial group betting
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20240422@Thomas.Nguyen: Created [Redmine ID: #200854]
			- 	20240620@Jonas.Huynh: Renovate CC [RedmineID: #205317]
            
		Param's Explanation (filtered by):
        		
		Example:
			-	CALL CTS_DC_CustClassification_InitialGB_GetCustInfo('1,2,987385,8498955,21007469,1295,916740,2812695');
	*/
	
    DECLARE	CONST_CATEID_INITIALGB			INT;
    DECLARE	CONST_CATEGROUPID_INITIALGB		INT; 
    
    SET CONST_CATEID_INITIALGB	 			= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INITIALGB');    
    SET CONST_CATEGROUPID_INITIALGB	 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_INITIALGB');

	SELECT	cus.CTSCustID
		, 	cus.CustID
		,	cus.RoleID
		,	cus.SubscriberID
		,	CONST_CATEID_INITIALGB AS CategoryID
		,	CONST_CATEGROUPID_INITIALGB AS CategoryGroup
		,	cus.IsLicensee
	FROM JSON_TABLE(REPLACE(JSON_ARRAY(ip_CustIDs), ',', '","'), 
						'$[*]' COLUMNS (CustID BIGINT UNSIGNED PATH '$')
						) AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmp.CustID AND cus.IsInternal = 0 AND cus.IsLicensee = 1;
      
END$$

DELIMITER ;