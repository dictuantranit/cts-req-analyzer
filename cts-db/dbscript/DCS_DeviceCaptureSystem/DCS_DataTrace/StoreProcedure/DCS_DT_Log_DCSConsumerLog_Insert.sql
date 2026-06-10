/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Log_DCSConsumerLog_Insert`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Log_DCSConsumerLog_Insert`(
    IN ip_ConsumerLogJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20240206@Jonathan.Doan
	Task : Insert data into DCSConsumer_Log
	DB: DCS_DataTrace
	Original:

	Revisions:
		-20240206@Jonathan.Doan: Created [Redmine ID: 200900]
		-20241101@Jonathan.Doan: Log more info for consumer service [Redmine ID: 212696]
		
	Param's Explanation (filtered by):

	Example:
		SET sql_safe_updates = 0;
        CALL DCS_DataTrace.DCS_DT_Log_DCSConsumerLog_Insert('[{"LogType":1,"Environment":"TEST","ScriptVersion":"v1.0.3","SessionKey":"103052c9aa5b3e97e7c4df36cbc41bfd2411fffba2c6b16ac159ec280b6d8d12:8","Tagging":"163d05c0fa0d3ec0e7c7de62cb9018a07e1cffffa0c3ed6aca02b17d0f36d31d:2","LoginName":"Test01","SubscriberName":"Alpha","TransTime":"2024-10-06 13:54:12.123","UserAgent":"Mozilla Chrome 120","URL":"http://localhost:5000"},{"LogType":2,"Environment":"TEST","ScriptVersion":"v1.0.3","LoginName":"Test02","SubscriberName":"Alpha1","TransTime":"2024-11-06 13:54:12.123","UserAgent":"Mozilla Chrome 121","URL":"http://localhost:5001"}]');
        select * from DCS_DataTrace.DCSConsumer_Log;
	*/
    
	DECLARE lv_CurrentDatetime DATETIME DEFAULT CURRENT_TIMESTAMP();
    
    INSERT INTO DCS_DataTrace.DCSConsumer_Log(LogType, Environment, ScriptVersion, SessionKey, Tagging, LoginName, SubscriberName, TransTime, UserAgent, URL, CreatedDate, InsertedTime)
	SELECT	tmp.LogType
		,	tmp.Environment
		,	tmp.ScriptVersion
		,	tmp.SessionKey
		,	tmp.Tagging
		,	tmp.LoginName
		,   tmp.SubscriberName
        ,	tmp.TransTime
		,	tmp.UserAgent
        ,	tmp.URL
        ,	DATE(lv_CurrentDatetime) AS CreatedDate
        ,	lv_CurrentDatetime AS InsertedTime
	FROM JSON_TABLE(
			ip_ConsumerLogJson,
			 "$[*]" COLUMNS(
					LogType				SMALLINT			PATH "$.LogType"
				,	Environment			VARCHAR(10)			PATH "$.Environment"
				,	ScriptVersion		VARCHAR(10)			PATH "$.ScriptVersion"
				,	SessionKey			VARCHAR(100)		PATH "$.SessionKey"
				,	Tagging				VARCHAR(100)		PATH "$.Tagging"
				,	LoginName			VARCHAR(100)		PATH "$.LoginName"
                ,   SubscriberName		VARCHAR(50)			PATH "$.SubscriberName"
				,	TransTime			TIMESTAMP(4)		PATH "$.TransTime"
                ,	UserAgent			VARCHAR(1000)		PATH "$.UserAgent"
				,	URL					VARCHAR(500) 		PATH "$.URL"
			)
		) AS tmp;
END$$
DELIMITER ;