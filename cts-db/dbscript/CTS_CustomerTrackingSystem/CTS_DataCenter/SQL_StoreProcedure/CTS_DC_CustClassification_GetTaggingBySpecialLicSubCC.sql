/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_GetTaggingBySpecialLicSubCC`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_GetTaggingBySpecialLicSubCC`(
	IN ip_CustJson		JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250515@Thomas.Nguyen
		Task:	 	Get Tagging By Special Lic Sub Customer Classification
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250515@Thomas.Nguyen: 	Created [Redmine ID: #226847]

		Param's Explanation (filtered by): 

		Example:
			CALL CTS_DC_CustClassification_GetTaggingBySpecialLicSubCC('[{"CustID":4357127,"ScanSpecialLicSubType":0}]');
	*/ 
	DECLARE CONST_TAGGINGTYPE_SPECIALLICSUBCC                       SMALLINT DEFAULT 3;
	DECLARE CONST_TAGGINGID_SPECIALLICSUBCC                         SMALLINT DEFAULT 1;
    DECLARE CONST_PROCESSSTATUS_COMPLETED_SPECIALLICSUBCC           SMALLINT DEFAULT 2;
	DECLARE CONST_STATUSCODE_SUCCESS_EXACTLY						INT DEFAULT 200;
	DECLARE CONST_STATUSCODE_SUCCESS_VALIDRANGE						INT DEFAULT 201;

	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE 	Temp_Cust (
			CustID 						BIGINT UNSIGNED PRIMARY KEY
		,	ScanSpecialLicSubType		TINYINT DEFAULT(0)
		,	TaggingID					SMALLINT
		,	TaggingType					SMALLINT
	);   

	INSERT IGNORE INTO Temp_Cust(CustID, ScanSpecialLicSubType, TaggingID, TaggingType)
    SELECT  js.CustID
		,	js.ScanSpecialLicSubType
		,	CASE WHEN js.ScanSpecialLicSubType = 1 THEN CONST_TAGGINGID_SPECIALLICSUBCC END AS TaggingID
		,	CASE WHEN js.ScanSpecialLicSubType = 1 THEN CONST_TAGGINGTYPE_SPECIALLICSUBCC END AS TaggingType
	FROM JSON_TABLE(ip_CustJson,
					 "$[*]" COLUMNS(
								CustID					BIGINT UNSIGNED	PATH "$.CustID"
							,	ScanSpecialLicSubType	TINYINT			PATH "$.ScanSpecialLicSubType"
						)
				) AS js;

	UPDATE Temp_Cust AS tmp
		INNER JOIN CTS_DataCenter.Customer_SpecialLicSubCC AS sls ON tmp.CustID = sls.CustID
	SET		tmp.TaggingType = CONST_TAGGINGTYPE_SPECIALLICSUBCC 
		,	tmp.TaggingID = CONST_TAGGINGID_SPECIALLICSUBCC
    WHERE sls.IsDisabled = 0 AND sls.ProcessStatus = 2 AND tmp.ScanSpecialLicSubType = 0 AND sls.StatusCode IN (CONST_STATUSCODE_SUCCESS_EXACTLY, CONST_STATUSCODE_SUCCESS_VALIDRANGE);

    SELECT  tmp.CustID
        ,	tmp.TaggingID
        ,	tmp.TaggingType
    FROM Temp_Cust AS tmp;

END$$
DELIMITER ;