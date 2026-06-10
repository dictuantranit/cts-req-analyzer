
DROP PROCEDURE IF EXISTS `SPU_AIML_GB_5GIP_GetDetails`;

DELIMITER $$
CREATE DEFINER=`AIMLOwner`@`%` PROCEDURE `SPU_AIML_GB_5GIP_GetDetails`(
		IN 	ip_FromCustID	BIGINT
	,	IN 	ip_ToCustID		BIGINT
)
    SQL SECURITY INVOKER
BEGIN  
	/*  
		Created:	20230420@Casey.Huynh
		Task:		GET OCRD Match of Customer
		DB:			CTS_DataCenter
        
		Revisions:
			- 20230421@Casey.Huynh: Created [Redmine ID: #185783]

		Param's Explanation (filtered by): 
        
        Example:
			CALL SPU_AIML_5GIP_GetDetails(@ip_FromCustID:=1584972, @ip_ToCustID:=49229861);
	*/   
	DECLARE lv_CustID1 BIGINT;
    DECLARE lv_CustID2 BIGINT;
    
    SET lv_CustID1 = LEAST(ip_FromCustID, ip_ToCustID);
    SET lv_CustID2 = GREATEST(ip_FromCustID, ip_ToCustID);
    
    SELECT DISTINCT cf.CustID1
		,	cf.CustID2
        ,	cf.MatchID
        ,	js.TransID
    FROM SPU_AIML.GB_5GIP_CoupleFraudInfo AS cf
		JOIN JSON_TABLE(REPLACE(JSON_ARRAY(cf.FraudTransList), ',', '","'), 
							'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
							) js
    WHERE cf.CustID1 = lv_CustID1
		AND cf.CustID2 = lv_CustID2;        
    		
END$$

DELIMITER ;
