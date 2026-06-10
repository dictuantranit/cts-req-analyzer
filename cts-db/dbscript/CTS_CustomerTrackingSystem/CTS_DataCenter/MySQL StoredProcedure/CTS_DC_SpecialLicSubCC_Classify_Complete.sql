/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_SpecialLicSubCC_Classify_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_SpecialLicSubCC_Classify_Complete`(
	IN ip_CustInfo JSON
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
			CALL CTS_DC_SpecialLicSubCC_Classify_Complete(@ip_CustInfo:=
						'[	{"CustID":"100020250","CategoryID":"2500"}
						,	{"CustID":"26803005","CategoryID":"2503"}
                        ,	{"CustID":"16647323","CategoryID":"NULL"}]');

	*/
    DECLARE CONST_PROCESSSTATUS_INPROGRESS			TINYINT DEFAULT 1;
    DECLARE CONST_PROCESSSTATUS_COMPLETE			TINYINT DEFAULT 2;
    DECLARE CONST_SPECIALCC_CATEGORYID				INT DEFAULT 10300;
	DECLARE CONST_STATUSCODE_SUCCESS_EXACTLY		INT DEFAULT 200;
	DECLARE CONST_STATUSCODE_SUCCESS_VALIDRANGE		INT DEFAULT 201;
	DECLARE CONST_STATUSCODE_UNSUCCESS	 			INT DEFAULT 401;  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			CustID			BIGINT UNSIGNED PRIMARY KEY
        ,	CategoryID		INT UNSIGNED
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CategoryMapping;
    CREATE TEMPORARY TABLE Temp_CategoryMapping(
			NormalCategoryID		INT UNSIGNED PRIMARY KEY
        ,	NormalCustomerClass		INT UNSIGNED
		,	LicCategoryID			INT UNSIGNED
        ,	LicCustomerClass		INT UNSIGNED
    );
    
    INSERT INTO Temp_CategoryMapping(NormalCategoryID, NormalCustomerClass, LicCategoryID, LicCustomerClass)
    VALUES(40100,200,40106,2500)
		, (40400,203,40406,2503)
        , (40500,204,40506,2504)
        , (40600,205,40606,2505);

    INSERT IGNORE INTO Temp_Cust(CustID, CategoryID)
	SELECT	info.CustID
		, 	info.CategoryID
	FROM JSON_TABLE(ip_CustInfo,
		 "$[*]" COLUMNS(
				CustID			BIGINT UNSIGNED	PATH "$.CustID" 
			, 	CategoryID		INT UNSIGNED	PATH "$.CategoryID"  )
	) AS info;
	
   
    UPDATE CTS_DataCenter.Customer_SpecialLicSubCC AS slc
		INNER JOIN Temp_Cust AS tmpCus ON tmpCus.CustID = slc.CustID
        INNER JOIN Temp_CategoryMapping AS tmpMap ON tmpMap.NormalCategoryID = tmpCus.CategoryID
        INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON cls.CustID = tmpCus.CustID AND cls.CategoryID = tmpMap.LicCategoryID 
        INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = cls.CategoryID
	SET 	slc.ProcessStatus = CONST_PROCESSSTATUS_COMPLETE
		,	slc.LatestCustomerClass = cat.CustomerClass
		,	slc.StatusCode = (CASE WHEN slc.APICustomerClass = tmpMap.NormalCustomerClass AND cat.CustomerClass = tmpMap.LicCustomerClass THEN CONST_STATUSCODE_SUCCESS_EXACTLY
									ELSE CONST_STATUSCODE_SUCCESS_VALIDRANGE END)
	WHERE slc.ProcessStatus = CONST_PROCESSSTATUS_INPROGRESS;	

	UPDATE CTS_DataCenter.Customer_SpecialLicSubCC AS slc
		INNER JOIN Temp_Cust AS tmpCus ON slc.CustID = tmpCus.CustID
        LEFT JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON cls.CustID = tmpCus.CustID
        LEFT JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = cls.CategoryID
	SET 	slc.ProcessStatus = CONST_PROCESSSTATUS_COMPLETE
		,	slc.LatestCustomerClass = (CASE WHEN cat.CategoryID = CONST_SPECIALCC_CATEGORYID THEN (SELECT CustomerClass FROM CTS_DataCenter.SpecialCustomerClass AS sps WHERE sps.CustID = tmpCus.CustID LIMIT 1)
											ELSE cat.CustomerClass END)
		,	slc.StatusCode = CONST_STATUSCODE_UNSUCCESS
    WHERE slc.ProcessStatus = CONST_PROCESSSTATUS_INPROGRESS;
        
END$$
DELIMITER ;
