/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Log_FPSJavascriptException_Insert`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Log_FPSJavascriptException_Insert`(
    IN ip_ExceptionJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20240220@Jonathan.Doan
		Task: Insert FPSScriptException [Redmine ID: 200900]
		DB: DCS_DataTrace
		Original:

		Revisions:
			-20240220@Jonathan.Doan: Created [Redmine ID: 200900]
			
		Param's Explanation (filtered by):

		Example:
			SET sql_safe_updates = 0;
			CALL DCS_DataTrace.DCS_DT_Log_FPSJavascriptException_Insert('[{"ScriptVersion":"1.0.0","FunctionName":"Test SP","Exception":"Test Message","UserAgent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","ApiUrl":"https://spu-fps-api.nexdev.net/","HostName":"https://alphafps.nexdev.net/","SessionKey":"59899592ef0940e8a37fc7dd0c9da484","DeviceCode":"838704a342794ee2b43e07867e83a1bd","NewCookie":"59899592ef0940e8a37fc7dd0c9da484","RealIP":"127.0.0.1","FakeIP":null}]');
	*/
    
	DECLARE lv_CurrentDatetime DATETIME DEFAULT CURRENT_TIMESTAMP();

    INSERT IGNORE INTO DCS_DataTrace.FPSJavascriptException(ScriptVersion, FunctionName, Exception, UserAgent, ApiUrl, HostName, SessionKey, DeviceCode, NewCookie, RealIP, FakeIP, CreatedDate, InsertedTime)
	SELECT	tmp.ScriptVersion
		,	tmp.FunctionName
        ,	tmp.Exception
        ,	tmp.UserAgent
        ,	tmp.ApiUrl
        ,	tmp.HostName
        ,	tmp.SessionKey
        ,	tmp.DeviceCode
        ,	tmp.NewCookie
        ,	tmp.RealIP
        ,	tmp.FakeIP
        ,	DATE(lv_CurrentDatetime) AS CreatedDate
        ,	lv_CurrentDatetime AS InsertedTime
	FROM JSON_TABLE(
			ip_ExceptionJson,
			 "$[*]" COLUMNS(
					ScriptVersion		VARCHAR(20)			PATH "$.ScriptVersion"
				,	FunctionName		VARCHAR(100)		PATH "$.FunctionName"
				,	Exception			VARCHAR(1000)		PATH "$.Exception"
                ,   UserAgent			VARCHAR(500)		PATH "$.UserAgent"
                ,   ApiUrl				VARCHAR(250)		PATH "$.ApiUrl"
                ,   HostName			VARCHAR(250)		PATH "$.HostName"
                ,   SessionKey			VARCHAR(200)		PATH "$.SessionKey"
                ,   DeviceCode			VARCHAR(100)		PATH "$.DeviceCode"
                ,   NewCookie			VARCHAR(100)		PATH "$.NewCookie"
                ,   RealIP				VARCHAR(50)			PATH "$.RealIP"
                ,   FakeIP				VARCHAR(50)			PATH "$.FakeIP"
			)
		) AS tmp;

END$$
DELIMITER ;