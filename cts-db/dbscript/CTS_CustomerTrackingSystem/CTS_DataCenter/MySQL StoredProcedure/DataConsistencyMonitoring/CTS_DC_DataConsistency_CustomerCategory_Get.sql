/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_DataConsistency_CustomerCategory_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_DataConsistency_CustomerCategory_Get`(
	OUT	op_Status			VARCHAR(20)
)
    SQL SECURITY INVOKER
spc:BEGIN 
	/*
		Created:	20241018@Victoria.Le
		Task :		Identify customers who have incorrect category settings.
		DB:			CTS_DataCenter

		Revisions:
			- 20241018@Victoria.Le: 	Initial Writing [RedmineID: #212321]
                
        Param's Explanation:
        Example:
			- CALL CTS_DataCenter.CTS_DC_DataConsistency_CustomerCategory_Get(@op_Status);
	*/ 
	
	DECLARE lv_TrackingDate		DATE;
	DECLARE lv_Status			VARCHAR(20);
	
	SELECT LastExecTime,Status
	INTO lv_TrackingDate,lv_Status
	FROM CTS_DataCenter.SystemEventStatus
	WHERE EventName = 'EV_CTS_DC_DataConsistency_CustomerCategory';
	
	IF lv_TrackingDate = CURDATE() AND lv_Status = 'Stop' THEN
		SET op_Status = lv_Status;
		
		SELECT dr.RuleMessage,GROUP_CONCAT(drl.LogInfo) AS LogInfo
		FROM CTS_DataCenter.DataConsistencyMonitoring_Log AS drl
			INNER JOIN CTS_DataCenter.DataConsistencyMonitoring AS dr ON dr.RuleID = drl.RuleID
		WHERE drl.CreatedDate = lv_TrackingDate
		GROUP BY dr.RuleMessage;

	END IF;

END$$

DELIMITER ;