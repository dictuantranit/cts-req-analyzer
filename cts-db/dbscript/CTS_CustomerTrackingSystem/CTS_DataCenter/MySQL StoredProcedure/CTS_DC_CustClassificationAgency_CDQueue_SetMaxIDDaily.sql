/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_CDQueue_SetMaxIDDaily`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_CDQueue_SetMaxIDDaily`(		
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250725@Winfred.Pham
		Task:	 	Add Max ID from Queue to SystemParameter
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250725@Winfred.Pham: 	Created [Redmine ID: #219679]
                
		Param's Explanation: 
        
		Example:
			CALL CTS_DC_CustClassificationAgency_CDQueue_SetMaxIDDaily();
	*/
    DECLARE lv_LastQueueID	BIGINT UNSIGNED DEFAULT 0;
	DECLARE lv_NewQueueID	BIGINT UNSIGNED DEFAULT 0;

    SELECT sys.ParameterValue
    INTO lv_LastQueueID
    FROM CTS_DataCenter.SystemParameter AS sys
    WHERE ParameterID = 192;  

    SELECT MAX(dq.ID)
    INTO lv_NewQueueID
    FROM CTS_DataCenter.CustomerConsiderableDangerQueue AS dq
    WHERE dq.ID > lv_LastQueueID;  
	
	UPDATE  CTS_DataCenter.SystemParameter 
	SET ParameterValue = lv_NewQueueID
	WHERE ParameterID = 192 AND lv_NewQueueID IS NOT NULL;

END$$
DELIMITER ;