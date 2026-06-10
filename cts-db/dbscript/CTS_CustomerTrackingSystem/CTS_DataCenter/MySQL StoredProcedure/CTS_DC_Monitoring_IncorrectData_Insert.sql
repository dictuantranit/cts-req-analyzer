/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Monitoring_IncorrectData_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Monitoring_IncorrectData_Insert`(
		IN 	ip_IncorrectData	JSON,
        IN  ip_IssueTypeID		SMALLINT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240102@Jonas.Huynh
		Task:		Enhance Monitoring Job [Redmine ID: #197999]
		DB:			CTS_DataCenter
		Original:

		Revisions:
            - 20240102@Jonas.Huynh: Creator SP [Redmine ID: #197999]
		Param's Explanation (filtered by):
			- ip_IssueTypeID :
				1. 
		Example:
			- CALL CTS_DataCenter.CTS_DC_Monitoring_IncorrectData_Insert ('[{"CustID":82355839,"TrackingInfo":"","Value":2}]', 500);

	*/
    
    DECLARE lv_CurrentDateTime		DATETIME DEFAULT CURRENT_TIME();
        
	DROP TEMPORARY TABLE IF EXISTS Temp_IncorrectData;    
	CREATE TEMPORARY TABLE Temp_IncorrectData(
		CustID 			INT UNSIGNED,
		TrackingInfo 	VARCHAR(500) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NULL,
        `Value`			BIGINT
	);

    INSERT INTO Temp_IncorrectData(CustID, TrackingInfo, `Value`)
	SELECT		CustID	
			,	TrackingInfo
            ,	`Value`
	FROM JSON_TABLE(ip_IncorrectData,
		 "$[*]" COLUMNS(
				CustID			INT	UNSIGNED	PATH "$.CustID" 
            ,	TrackingInfo	VARCHAR(500)	PATH "$.TrackingInfo"
            ,	`Value`			BIGINT 			PATH "$.Value"	
			)
	) AS js;
    
    INSERT INTO CTS_DataCenter.JobMonitoring_IncorrectData(IssueTypeID, TrackingInfo, `Value`, CustID, CreatedTime)
    SELECT 		ip_IssueTypeID	
			,	TrackingInfo
            ,	`Value`
            ,	CustID
            ,	lv_CurrentDateTime
    FROM Temp_IncorrectData;

END$$
DELIMITER ;