/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin,ctsAPIAdmin,ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_LogInputData`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustClassification_LogInputData`(
	IN 	ip_InputData 			JSON,
    IN 	ip_FunctionID 			SMALLINT,
    
    OUT op_ErrorMessage 		VARCHAR(200)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210707@Long.Luu
		Task:		Log Classification Input Data [Redmine ID: #0000]
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20210707@Long.Luu: Created [Redmine ID: #157203] 
            
		Example:
			call CTS_DataCenter.CTS_DC_CustClassification_LogInputData ('[{"CustID": 111, "InputValue": "1"}]',1, @ErrorMessage);    
	*/ 
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    INSERT INTO CTSCustomerClassification_InputDataLog(CustID,FunctionID,JsonInputValue,CreatedDate,CreatedTime)
	SELECT 	DISTINCT tmpTable.CustID
		, 	ip_FunctionID
		, 	tmpTable.InputValue
		,	DATE(NOW())
		,	NOW()
	FROM JSON_TABLE(ip_InputData,
		 "$[*]" COLUMNS(
			  CustID 			BIGINT UNSIGNED		PATH "$.CustID"
            , InputValue 		JSON				PATH "$.InputValue"
		 )) AS tmpTable; 
         
END$$
DELIMITER ;