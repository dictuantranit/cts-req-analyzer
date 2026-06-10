/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_AssociationDetection_Primary_GetEdge`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociationDetection_Primary_GetEdge`(
		IN	ip_CTSCustIDs 		LONGTEXT
	,   IN  ip_HasDevice		BIT
    ,   IN  ip_HasAI			BIT
    ,   IN  ip_HasIP			BIT
)
    SQL SECURITY INVOKER
sp:BEGIN 
	/*  
		Created:	20220727@Aries.Nguyen
		Task:		[CTS] Enhance Association Detection
		DB:			CTS_DataCenter
        
		Revisions:
			- 20220727@Aries.Nguyen: Created [Redmine ID: #175701]
            - 20221205@Aries.Nguyen: Re-arrange type options on Association Detection  [Redmine ID: #181207]

		Param's Explanation (filtered by):

        Example:
			- CALL CTS_DataCenter.CTS_DC_AssociationDetection_Primary_GetEdge('1,2,3',1,1,1);
	*/
    DECLARE lv_CTSCustIDs 	JSON;
    
    WITH CTE AS (
		SELECT 	DISTINCT
				cus.CTSCustID
			, 	cus.CustID
		FROM JSON_TABLE(CONCAT('[',ip_CTSCustIDs,']'),'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (CTSCustID BIGINT UNSIGNED PATH '$'))) AS tmp
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmp.CTSCustID AND cus.IsInternal = 0
    )
    SELECT JSON_ARRAYAGG(JSON_OBJECT('CTSCustID', CTSCustID ,'CustID', CustID)) AS CustJson
	INTO lv_CTSCustIDs	
    FROM CTE;
    
    CALL CTS_DataCenter.CTS_DC_AssociationDetection_GetEdge(lv_CTSCustIDs,ip_HasDevice,ip_HasAI,ip_HasIP);
    
	SELECT 	OrigID 
		,	DestID
        ,	AssociationType
    FROM Temp_Graph;
    
END$$

DELIMITER ;
