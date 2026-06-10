/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_SpecialLicSubCC_Response_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_SpecialLicSubCC_Response_Complete`(
			IN ip_ResponseInfo	JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250514@Casey.Huynh
		Task:	 	SpecialLicSubCC Scan Get
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250514@Casey.Huynh: 	Created [Redmine ID: #226847]

		Param's Explanation (filtered by): 

		Example:
			CALL CTS_DC_SpecialLicSubCC_Response_Complete(
            @ip_ResponseInfo:='[	{"ID":"1","ResponseStatus":"0","ResponseTime":"2025-05-15 01:01:01.0001","ResponseHttpCode":"400"}
								,	{"ID":"7","ResponseStatus":"1","ResponseTime":"2025-05-15 01:01:01.0005","ResponseHttpCode":"400"}
                                ,	{"ID":"8","ResponseStatus":"1","ResponseTime":"2025-05-15 01:01:01.0005","ResponseHttpCode":"0"}
								]');
	*/
	DECLARE CONST_PROCESSSTATUS_RESPONESE_FAIL			TINYINT DEFAULT 3;
    DECLARE CONST_PROCESSSTATUS_RESPONESE_SUCCESS		TINYINT DEFAULT 4;
    
    DECLARE CONST_STATICLIST_STATUSCODE		TINYINT DEFAULT 26;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ResponseInfo;
	CREATE TEMPORARY TABLE Temp_ResponseInfo(
			ID					BIGINT UNSIGNED 
		,	ResponseStatus		TINYINT
        ,	ResponseTime		DATETIME(4)	
        ,	ResponseHttpCode	SMALLINT
        
        ,	PRIMARY KEY Temp_ResponseInfo_ID(ID)
	);	
 
	INSERT INTO Temp_ResponseInfo(ID, ResponseStatus, ResponseTime, ResponseHttpCode)
	SELECT	js.ID
		,	js.ResponseStatus
		,	js.ResponseTime  
        ,	js.ResponseHttpCode
	FROM JSON_TABLE(ip_ResponseInfo, 
		"$[*]" COLUMNS(
				ID					BIGINT UNSIGNED	PATH "$.ID"
			,	ResponseStatus		TINYINT	 		PATH "$.ResponseStatus" #0: response fail, 1:Response success
            ,	ResponseTime		DATETIME(4)	 	PATH "$.ResponseTime" 	
            ,	ResponseHttpCode	SMALLINT		PATH "$.ResponseHttpCode"	
		)
	) AS js;	 
    
    UPDATE CTS_DataCenter.Customer_SpecialLicSubCC AS cus
		INNER JOIN Temp_ResponseInfo AS tmp ON cus.ID = tmp.ID
	SET 	cus.ProcessStatus = (CASE WHEN tmp.ResponseStatus = 0 THEN CONST_PROCESSSTATUS_RESPONESE_FAIL
									ELSE CONST_PROCESSSTATUS_RESPONESE_SUCCESS
								END)  
		,	cus.ResponseTime = tmp.ResponseTime
        ,	cus.ResponseHttpCode = tmp.ResponseHttpCode
	;

END$$
DELIMITER ;
