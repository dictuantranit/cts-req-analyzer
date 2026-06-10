/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_UpdateCustInfoComplete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_UpdateCustInfoComplete`(
		IN ip_LastUpdateTime	DATETIME(3)
	,	IN ip_LastUpdateCustID	INT
	,	IN ip_CustInfo			JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210208@Casey.Huynh
		Task:		Update CTSCustomer Info Complete [Redmine ID: 149941]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210208@Casey.Huynh: Created [Redmine ID: 149941]
			- 20210622@Aries.Nguyen: Update coding convention  [Redmine ID: #157203]
            - 20220930@Aries.Nguyen: Renovate Association Detection [RedmineID: #178311]
			- 20221205@Victoria.Le:	 Get more data: DangerSabaSc (Saba Soccer) and DangerSabaBkb (Saba Baseketball) [Redmine ID: #181208]

		Param's Explanation (filtered by):
		
		Example: 
	*/ 
	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomer;
	CREATE TEMPORARY TABLE Temp_CTSCustomer(
			CustID			INT UNSIGNED
        ,	CustStatusID	TINYINT
		,	Danger1			TINYINT
		,	Danger2			TINYINT
		,	Danger3			TINYINT
        ,	Danger4			TINYINT
		,	Danger5			TINYINT
		,	DangerSabaSc	TINYINT
		,	DangerSabaBkb	TINYINT
  
		,	INDEX IX_Temp_CTSCustomer_CustID(CustID)
	);	
 
	INSERT INTO Temp_CTSCustomer(CustID, CustStatusID, Danger1, Danger2, Danger3, Danger4, Danger5, DangerSabaSc, DangerSabaBkb)
	SELECT	js.CustID
		,	js.CustStatusID
		,	js.Danger1		
		,	js.Danger2		
		,	js.Danger3
		,	js.Danger4		
		,	js.Danger5
		,	js.DangerSabaSc
		,	js.DangerSabaBkb
	FROM JSON_TABLE(ip_CustInfo, 
		"$[*]" COLUMNS(
				CustID			INT UNSIGNED	PATH "$.CustID"
            ,	CustStatusID	TINYINT	 		PATH "$.CustStatusID" 
			,	Danger1			TINYINT	 		PATH "$.Danger1" 
			,	Danger2			TINYINT	 		PATH "$.Danger2" 
			,	Danger3			TINYINT	 		PATH "$.Danger3"		
            ,	Danger4			TINYINT	 		PATH "$.Danger4" 
			,	Danger5			TINYINT	 		PATH "$.Danger5"
			,	DangerSabaSc	TINYINT	 		PATH "$.DangerSabaSc"
			,	DangerSabaBkb	TINYINT	 		PATH "$.DangerSabaBkb"
		)
	) AS js;	 
       
	UPDATE 		CTS_DataCenter.CTSCustomer AS ctsCust
		INNER JOIN 	Temp_CTSCustomer AS tempCust ON ctsCust.CustID = tempCust.CustID
	SET		ctsCust.CustStatusID 	= tempCust.CustStatusID
		,	ctsCust.Danger1 		= tempCust.Danger1
		,	ctsCust.Danger2 		= tempCust.Danger2
		,	ctsCust.Danger3 		= tempCust.Danger3
        ,	ctsCust.Danger4 		= tempCust.Danger4
		,	ctsCust.Danger5 		= tempCust.Danger5
		,	ctsCust.DangerSabaSc 	= tempCust.DangerSabaSc
		,	ctsCust.DangerSabaBkb 	= tempCust.DangerSabaBkb
		,	ctsCust.ModifiedTime 	= CURRENT_TIMESTAMP(4)
	WHERE	ctsCust.CustSubID = 0;
    
    #==================================================    	
	UPDATE	CTS_DataCenter.SystemParameter AS s
	SET		s.ParameterValue = ip_LastUpdateTime
	WHERE	s.ParameterID = 9 AND s.ParameterName = 'CTSCustomer_LastUpdateTimeCustInfo';
	
	UPDATE	CTS_DataCenter.SystemParameter AS s
	SET		s.ParameterValue = ip_LastUpdateCustID
	WHERE	s.ParameterID = 10 AND s.ParameterName = 'CTSCustomer_LastUpdateCustIDCustInfo';

END$$
DELIMITER ;