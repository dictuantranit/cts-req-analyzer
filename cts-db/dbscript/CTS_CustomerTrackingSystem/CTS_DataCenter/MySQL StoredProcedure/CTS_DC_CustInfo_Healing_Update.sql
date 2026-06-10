/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustInfo_Healing_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustInfo_Healing_Update`(
		IN ip_CustInfo JSON
    ,	IN ip_LastCustID BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210818@Casey.Huynh
		Task:		Initial CustStatus[Redmine ID: 152259]
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20210115@Casey.Huynh: Created [Redmine ID: 152259]
            
		Param's Explanation (filtered by):

		Example: CALL CTS_DC_CustInfo_Healing_Update ('[{"CustID": 1493, "CustStatusID": 1}, {"CustID": 1289, "CustStatusID": 3}]', 1289);
	*/  
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomer;
	CREATE TEMPORARY TABLE Temp_CTSCustomer(
			CustID			INT UNSIGNED
        ,	CustStatusID	TINYINT
		,	INDEX IX_Temp_CTSCustomer_CustID(CustID)
	);	
 
	INSERT INTO Temp_CTSCustomer(CustID, CustStatusID)
	SELECT	js.CustID
		,	js.CustStatusID
	FROM JSON_TABLE(ip_CustInfo, 
		"$[*]" COLUMNS(
				CustID			INT UNSIGNED	PATH "$.CustID"
            ,	CustStatusID	TINYINT	 		PATH "$.CustStatusID" 			
		)
	) AS js;	
       
	UPDATE 		CTS_DataCenter.CTSCustomer AS ctsCust
		INNER JOIN 	Temp_CTSCustomer AS tempCust ON ctsCust.CustID = tempCust.CustID AND ctsCust.CustSubID = 0
	SET		ctsCust.CustStatusID = tempCust.CustStatusID
		,	ctsCust.ModifiedTime = CURRENT_TIMESTAMP(4)
	WHERE	ctsCust.CustStatusID <> tempCust.CustStatusID;
    
    #==================================================    	
	UPDATE	CTS_DataCenter.SystemParameter AS s
	SET		s.ParameterValue = ip_LastCustID
	WHERE	s.ParameterID = 28;
    
END$$
DELIMITER ;