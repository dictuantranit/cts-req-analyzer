/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Summary_LogTrail_Insert`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Summary_LogTrail_Insert`(
    IN ip_LogTrailJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20232610@Teddy.le
	Task : Insert data into DailyLogTrailSummary
	DB: DCS_DataTrace
	Original:

	Revisions:
		-20232610@Teddy.le: Created [Redmine ID: 195968]
		
	Param's Explanation (filtered by):

	Example:
		SET sql_safe_updates = 0;
        CALL DCS_DataTrace.DCS_DT_Summary_LogTrail_Insert('[{"EventDate":"2023-10-26","SubscriberID":101,"SystemName":"new fps","Source":"https://spu-fps-api.nexdev.net","Destination":"spu-fps-portal-api.nexdev.net","Method":"/api/transaction","Total":10}]');
	*/
    
	DECLARE lv_CurrentDatetime DATETIME DEFAULT CURRENT_TIMESTAMP();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_InputLogTrail;

	CREATE TEMPORARY TABLE Temp_InputLogTrail(
			ID 							BIGINT UNSIGNED NOT NULL AUTO_INCREMENT
		, 	EventDate					DATE NOT NULL
		, 	SubscriberID				INT UNSIGNED DEFAULT 0
		,	EventCode 					VARCHAR(100) NULL DEFAULT ''
        , 	SystemName					VARCHAR(45) DEFAULT ''
		, 	Source						VARCHAR(100) DEFAULT ''
        ,   Destination					VARCHAR(100) DEFAULT ''
		, 	Method						VARCHAR(100) DEFAULT ''
        , 	Total						INT UNSIGNED DEFAULT 0
        , 	CreatedTime					DATETIME DEFAULT NULL
        , 	ModifiedTime				DATETIME DEFAULT NULL
		, 	IsUpdate					BOOL DEFAULT 0
        ,   PRIMARY KEY (`ID`)
		,	KEY `UX_DailyLogTrailSummary_EventCode` (`EventCode`)
	);
	
    INSERT INTO Temp_InputLogTrail(EventDate, SubscriberID, EventCode, SystemName, Source, Destination, Method, Total)
	SELECT	tmp.EventDate
		,	tmp.SubscriberID
		,   MD5(CONCAT(EventDate, SubscriberID, SystemName, Source, Destination, Method)) AS EventCode
        ,	tmp.SystemName
		,	tmp.Source
        ,	tmp.Destination
		,	tmp.Method
        ,	tmp.Total
	FROM JSON_TABLE(
			ip_LogTrailJson,
			 "$[*]" COLUMNS(
					EventDate					DATE				PATH "$.EventDate"
				,	SubscriberID				INT UNSIGNED		PATH "$.SubscriberID"
                ,   SystemName					VARCHAR(45)			PATH "$.SystemName"
				,	Source						VARCHAR(100)		PATH "$.Source"
                ,	Destination					VARCHAR(100)		PATH "$.Destination"
				,	Method						VARCHAR(100) 		PATH "$.Method"
				,	Total						INT UNSIGNED		PATH "$.Total"
			)
		) AS tmp;
	
    UPDATE DCS_DataTrace.DailyLogTrailSummary AS dl
		INNER JOIN Temp_InputLogTrail AS tmp ON dl.EventCode = tmp.EventCode
	SET dl.Total 			= dl.Total + tmp.Total,
		dl.ModifiedTime 	= lv_CurrentDatetime,
		tmp.IsUpdate 		= 1;
    
    INSERT INTO DCS_DataTrace.DailyLogTrailSummary(EventDate, SubscriberID, EventCode, SystemName, Source, Destination, Method, Total, CreatedTime, ModifiedTime)
    SELECT 	tmp.EventDate
        ,	tmp.SubscriberID
		,   tmp.EventCode
        ,	tmp.SystemName
		,	tmp.Source
        ,   tmp.Destination
		,	tmp.Method
        ,	tmp.Total
        ,	lv_CurrentDatetime AS CreatedTime
        ,	lv_CurrentDatetime AS ModifiedTime
	FROM Temp_InputLogTrail AS tmp
    WHERE tmp.IsUpdate = 0;
END$$
DELIMITER ;