/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_FP_FingerPrintInsert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_FP_FingerPrintInsert`(
	IN ip_FingerPrintJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20240729@Jonathan.Doan
	    Task : Change Data Flow Ver. 6
		DB: DCS_DataCenter
		Original:

		Revisions:
			- 20240730@Jonathan.Doan: Created [Redmine ID: #206403]

		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Transform_FP_FingerPrintInsert('[{"FPFingerPrintCode":"123","FPFingerPrintAttribute":{"Name":"ABC"},"FPFingerPrintExtraCode":"123","FingerPrintExtraAttribute":{"Name":"Extra"},"FPFingerPrintOldCode":"123"}]');

	*/
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Input;
	DROP TEMPORARY TABLE IF EXISTS Temp_InputFingerPrint;
	DROP TEMPORARY TABLE IF EXISTS Temp_InputFingerPrintExtra;
	DROP TEMPORARY TABLE IF EXISTS Temp_InputFingerPrintOld;
        
	CREATE TEMPORARY TABLE Temp_Input(
			ID							INT UNSIGNED AUTO_INCREMENT		PRIMARY KEY
        ,	FingerPrintCode				VARCHAR(32) 					NOT NULL
        ,	FingerPrintAttribute		JSON
        ,	FingerPrintExtraCode		VARCHAR(32) 					NOT NULL
        ,	FingerPrintExtraAttribute	JSON
        ,	FingerPrintOldCode			VARCHAR(32) 					NOT NULL
    );
        
	CREATE TEMPORARY TABLE Temp_InputFingerPrint(
        	FingerPrintCode				VARCHAR(32) NOT NULL			PRIMARY KEY
        ,	FingerPrintAttribute		JSON
        
		,	IsNewRecord					TINYINT		 					DEFAULT 1
    );
        
	CREATE TEMPORARY TABLE Temp_InputFingerPrintExtra(
        	FingerPrintExtraCode		VARCHAR(32) NOT NULL			PRIMARY KEY
        ,	FingerPrintExtraAttribute	JSON
        
		,	IsNewRecord					TINYINT		 					DEFAULT 1
    );
        
	CREATE TEMPORARY TABLE Temp_InputFingerPrintOld(
        	FingerPrintOldCode			VARCHAR(32) NOT NULL			PRIMARY KEY
        
		,	IsNewRecord					TINYINT		 					DEFAULT 1
    );
    
    INSERT IGNORE INTO Temp_Input(FingerPrintCode, FingerPrintAttribute, FingerPrintExtraCode, FingerPrintExtraAttribute, FingerPrintOldCode)
    SELECT	input.FingerPrintCode
		,	input.FingerPrintAttribute
		,	input.FingerPrintExtraCode
		,	input.FingerPrintExtraAttribute
		,	input.FingerPrintOldCode
	FROM JSON_TABLE(
			ip_FingerPrintJson,
			 "$[*]" COLUMNS(
						FingerPrintCode					VARCHAR(32) 	PATH "$.FPFingerPrintCode"
					,	FingerPrintAttribute			JSON 			PATH "$.FPFingerPrintAttribute"
					,	FingerPrintExtraCode			VARCHAR(32) 	PATH "$.FPFingerPrintExtraCode"
					,	FingerPrintExtraAttribute		JSON 			PATH "$.FPFingerPrintExtraAttribute"
					,	FingerPrintOldCode				VARCHAR(32) 	PATH "$.FPFingerPrintOldCode"
				)
		   ) AS input;
	
    INSERT IGNORE INTO Temp_InputFingerPrint(FingerPrintCode, FingerPrintAttribute)
    SELECT 	FingerPrintCode
		,	FingerPrintAttribute
    FROM Temp_Input
    WHERE IFNULL(FingerPrintCode, '') <> '';

    INSERT IGNORE INTO Temp_InputFingerPrintExtra(FingerPrintExtraCode, FingerPrintExtraAttribute)
    SELECT 	FingerPrintExtraCode
		,	FingerPrintExtraAttribute
    FROM Temp_Input
    WHERE IFNULL(FingerPrintExtraCode, '') <> '';

    INSERT IGNORE INTO Temp_InputFingerPrintOld(FingerPrintOldCode)
    SELECT 	FingerPrintOldCode
    FROM Temp_Input
    WHERE IFNULL(FingerPrintOldCode, '') <> '';
    
    /* ==== Insert Fingerprint ==== */
    UPDATE Temp_InputFingerPrint AS tmp
		INNER JOIN DCS_DataCenter.FP_FingerPrint AS fp ON fp.Code = tmp.FingerPrintCode
    SET tmp.IsNewRecord = 0;
    
	INSERT IGNORE INTO DCS_DataCenter.FP_FingerPrint(Code, Attribute)
	SELECT	FingerPrintCode
		,	FingerPrintAttribute
	FROM Temp_InputFingerPrint
    WHERE IsNewRecord = 1;
    
    /* ==== Insert FingerprintExtra ==== */
    UPDATE Temp_InputFingerPrintExtra AS tmp
		INNER JOIN DCS_DataCenter.FP_FingerPrintExtra AS fpe ON fpe.Code = tmp.FingerPrintExtraCode
    SET tmp.IsNewRecord = 0;
    
	INSERT IGNORE INTO DCS_DataCenter.FP_FingerPrintExtra(Code, Attribute)
	SELECT	FingerPrintExtraCode
		,	FingerPrintExtraAttribute
	FROM Temp_InputFingerPrintExtra
    WHERE IsNewRecord = 1;
    
    /* ==== Insert FingerprintOld ==== */
    UPDATE Temp_InputFingerPrintOld AS tmp
		INNER JOIN DCS_DataCenter.FP_FingerPrintOld AS fpo ON fpo.Code = tmp.FingerPrintOldCode
    SET tmp.IsNewRecord = 0;
    
	INSERT IGNORE INTO DCS_DataCenter.FP_FingerPrintOld(Code)
	SELECT	FingerPrintOldCode
	FROM Temp_InputFingerPrintOld
    WHERE IsNewRecord = 1;
END$$

DELIMITER ;