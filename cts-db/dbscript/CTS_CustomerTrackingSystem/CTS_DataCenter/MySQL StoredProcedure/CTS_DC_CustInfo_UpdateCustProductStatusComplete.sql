/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_UpdateCustProductStatusComplete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_UpdateCustProductStatusComplete`(
		IN ip_LastUpdateTime	DATETIME(3)
	,	IN ip_LastUpdateCustID	INT
	,	IN ip_CustProductStatus	JSON
)
 SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210423@Casey.Huynh
		Task:		CTSCustomer (Credit Cust Status) by CustProductStatus_History [Redmine ID: #152259]
		DB:			CTS_DataCenter
		Original:
		Revisions:
			-	20210208@Casey.Huynh: Created [Redmine ID: 149941]
		Param's Explanation (filtered by):
		Example: 
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
	FROM JSON_TABLE(ip_CustProductStatus, 
		"$[*]" COLUMNS(
				CustID			INT UNSIGNED	PATH "$.CustID"
            ,	CustStatusID	TINYINT	 		PATH "$.CustStatusID" 			
		)
	) AS js;	
       
	UPDATE 		CTS_DataCenter.CTSCustomer AS ctsCust
		INNER JOIN 	Temp_CTSCustomer AS tempCust ON ctsCust.CustID = tempCust.CustID
	SET		ctsCust.CustStatusID = tempCust.CustStatusID
		,	ctsCust.ModifiedTime = CURRENT_TIMESTAMP(4)
	WHERE	ctsCust.CustSubID = 0;
    
    #==================================================    	
	UPDATE	CTS_DataCenter.SystemParameter AS s
	SET		s.ParameterValue = ip_LastUpdateTime
	WHERE	s.ParameterID = 18;
	
	UPDATE	CTS_DataCenter.SystemParameter AS s
	SET		s.ParameterValue = ip_LastUpdateCustID
	WHERE	s.ParameterID = 19;
END$$
DELIMITER ;