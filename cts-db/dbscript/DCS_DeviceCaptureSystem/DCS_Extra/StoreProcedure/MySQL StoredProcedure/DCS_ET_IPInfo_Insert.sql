/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_IPInfo_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_IPInfo_Insert`(
	IN ip_InputJs JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230809@Jonathan.Doan
		Task :		Insert IPInfo
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230809@Jonathan.Doan: Created [Redmine ID: 192402]
			
		Param's Explanation (filtered by):
			
		Example:
			SET sql_safe_updates = 0;
			CALL DCS_ET_IPInfo_Insert('[{"IPInfoCode":123,"Country":"Việt Nam","CountryCode":"VN","City":"City1","Region":"Region1","ISP":"ISP1"}
				,{"IPInfoCode":235,"Country":"Việt Nam2","CountryCode":"VN2","City":"City2","Region":"Region2","ISP":"ISP2"}]');
            SELECT * FROM DCS_Extra.IPInfo;
    
    */
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Input;
    
    CREATE TEMPORARY TABLE Temp_Input(
			IPInfoCode 		BIGINT NOT NULL PRIMARY KEY
		,	CountryCode	 	VARCHAR(45)
		,	Country		 	VARCHAR(128)
		,	City		 	VARCHAR(128)
		,	Region		 	VARCHAR(128)
		,	ISP		 		VARCHAR(128)
    );
    
	INSERT IGNORE INTO Temp_Input(IPInfoCode, CountryCode, Country, City, Region, ISP)
	SELECT	tmp.IPInfoCode
		,	tmp.CountryCode
		,	tmp.Country
		,	tmp.City
		,	tmp.Region
		,	tmp.ISP
	FROM	JSON_TABLE(
			ip_InputJs,
			 "$[*]" COLUMNS(
					IPInfoCode		BIGINT 			PATH "$.IPInfoCode",
					CountryCode		VARCHAR(45)		PATH "$.CountryCode",
					Country			VARCHAR(128)	PATH "$.Country",
					City			VARCHAR(128)	PATH "$.City",
					Region			VARCHAR(128)	PATH "$.Region",
					ISP				VARCHAR(128)	PATH "$.ISP"
				)
		   ) AS tmp;
           
	DELETE tmp
    FROM Temp_Input AS tmp
		INNER JOIN DCS_Extra.IPInfo AS c ON c.IPInfoCode = tmp.IPInfoCode;

	INSERT IGNORE INTO DCS_Extra.IPInfo(IPInfoCode, CountryCode, Country, City, Region, ISP)
	SELECT 	IPInfoCode
		,	CountryCode
		,	Country
		,	City
		,	Region
		,	ISP
	FROM Temp_Input;
END$$

DELIMITER ;
