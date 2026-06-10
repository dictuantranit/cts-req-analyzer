/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_Association_Primary_GetCustEdge`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_Primary_GetCustEdge`(
		IN	ip_CTSCustIDs 		LONGTEXT
	,   IN  ip_HasDevice		BIT
    ,   IN  ip_HasAI			BIT
    ,   IN  ip_HasIP			BIT
)
    SQL SECURITY INVOKER
BEGIN 
	/*  
		Created:	20231117@Victoria.Le
		Task:		Enhance Association Detection
		DB:			CTS_DataCenter
        
		Revisions:
			- 20231117@Victoria.Le: Initial Writing - Renovate Association Detection [Redmine ID: #192172]
		
		---------------------------------------------------------------------------------------------------
		[Before #192172]: CTS_DC_AssociationDetection_Primary_GetEdge 
			- 20220727@Aries.Nguyen: Created [Redmine ID: #175701]
            - 20221205@Aries.Nguyen: Re-arrange type options on Association Detection  [Redmine ID: #181207]

		Param's Explanation (filtered by):

        Example:
			- CALL CTS_DataCenter.CTS_DC_Association_Primary_GetCustEdge('1,2,3',1,0,0);
	*/
	
	DECLARE lv_CustJson 	JSON;
	#=============================================================================
	
	WITH CTE AS (
		SELECT 	DISTINCT
				cus.CTSCustID
			, 	cus.CustID
		FROM JSON_TABLE(CONCAT('[',ip_CTSCustIDs,']'),
								'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (CTSCustID BIGINT UNSIGNED PATH '$'))) AS tmp
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmp.CTSCustID AND cus.IsInternal = 0
    )
    SELECT JSON_ARRAYAGG(JSON_OBJECT('CTSCustID', CTSCustID ,'CustID', CustID)) AS CustJson
	INTO lv_CustJson	
    FROM CTE;
	
	CALL CTS_DataCenter.CTS_DC_Association_GetCustEdge(lv_CustJson,ip_HasDevice,ip_HasAI,ip_HasIP);
    
	SELECT 	OrigID 
		,	DestID
        ,	AssociationType
    FROM Temp_Graph;
	
END$$

DELIMITER ;