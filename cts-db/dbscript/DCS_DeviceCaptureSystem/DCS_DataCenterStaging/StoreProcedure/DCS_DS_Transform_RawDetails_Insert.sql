/*<info serverAlias="CTSMain-DCS_DataCenterStaging" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DS_Transform_RawDetails_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DS_Transform_RawDetails_Insert`(
		IN ip_DetailsType	TINYINT
	,	IN ip_Details 		LONGTEXT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20250822@Casey.Huynh
		Task : Insert to Raw Details Table 
		DB: FPS_RawTrans
		Original:

		Revisions:
            - 20250826@Casey.Huynh: Created [Redmine ID: #236716]

		Param's Explanation (filtered by):
			ip_DetailsType:
				1: Insert WebRTCIP
		Example:
			CALL DCS_DS_Transform_RawDetails_Insert(@ip_DetailsType:=1,'[{"FPGroupCode":"A1B2C3D4E5F6G7H8I9J0KLMNOPQRSTU","FPGroupDetails":"hard_details1","CreatedDate":"2025-09-04"}]');
	*/

    DECLARE CONST_WEBRTCIP 	INT DEFAULT 1;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Details;
    CREATE TEMPORARY TABLE Temp_Details(
			Code 			VARCHAR(32) PRIMARY KEY   
		,	Details			LONGTEXT NOT NULL 
        ,	CreatedDate		DATE
    );    
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ExistingDetails;
    CREATE TEMPORARY TABLE Temp_ExistingDetails(
			ID				BIGINT UNSIGNED PRIMARY KEY
		,	Code			VARCHAR(32) 
        ,	NewUsedDate 	DATE
        
        ,	INDEX IX_Temp_ExistingDetails_FPGroupCode(Code)
    );
		
	INSERT INTO Temp_Details(Code, Details, CreatedDate)
	SELECT	rt.Code
		,	rt.Details
        ,	rt.CreatedDate
	FROM	JSON_TABLE(
			ip_Details,
			 "$[*]" COLUMNS(
								Code			VARCHAR(32) 	PATH "$.Code"   
							,	Details			LONGTEXT		PATH "$.Details"
                            ,	CreatedDate		DATE			PATH "$.CreatedDate"
				)
		   ) AS rt; 	
    
    IF ip_DetailsType = CONST_WEBRTCIP THEN #Insert WebRTCIP
		#======GET EXISTING CODE============
        INSERT INTO Temp_ExistingDetails(ID, Code, NewUsedDate)
        SELECT 	fp.WebRTCIPID
			,	fp.WebRTCIPCode
            ,	tmpDt.CreatedDate AS NewUsedDate
        FROM Temp_Details AS tmpDt
			INNER JOIN DCS_DataCenterStaging.WebRTCIP AS fp ON fp.WebRTCIPCode = tmpDt.Code;
		
        #======REMOVE EXISTING CODE============
        DELETE tmpDt
        FROM Temp_Details AS tmpDt
			INNER JOIN Temp_ExistingDetails AS tmpEx ON tmpEx.Code = tmpDt.Code;
            
		#======UPDATE LastUsedDate============
        UPDATE  DCS_DataCenterStaging.WebRTCIP AS fp
			INNER JOIN Temp_ExistingDetails AS tmpEx ON tmpEx.ID = fp.WebRTCIPID
		SET fp.LastUsedDate = tmpEx.NewUsedDate
        WHERE fp.LastUsedDate < tmpEx.NewUsedDate;
		
        #======INSERT NEW Details=============================
        INSERT IGNORE INTO DCS_DataCenterStaging.WebRTCIP(WebRTCIPCode, WebRTCIPDetails, CreatedDate,	LastUsedDate)
        SELECT	tmpDt.Code
			,	tmpDt.Details
            ,	tmpDt.CreatedDate
            ,	tmpDt.CreatedDate AS NewUsedDate
        FROM Temp_Details AS tmpDt;
    END IF;
 
	DROP TEMPORARY TABLE IF EXISTS Temp_Details;
    DROP TEMPORARY TABLE IF EXISTS Temp_ExistingDetails;
END$$

DELIMITER ;

