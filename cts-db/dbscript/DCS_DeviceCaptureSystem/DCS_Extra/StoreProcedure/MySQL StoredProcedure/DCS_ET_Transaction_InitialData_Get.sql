/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transaction_InitialData_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transaction_InitialData_Get`(
		ip_BatchSize INT
	,	ip_LastTransID_ParameterID INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230809@Casey.Huynh
		Task :		Get Transaction IPID
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230809@Casey.Huynh: Created, Return IP [Redmine ID: 192402]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Transaction_InitialData_Get(10, 1001);
    
    */
    DECLARE lv_LastTransID 			BIGINT UNSIGNED;
    
    SELECT st.VValue
    INTO lv_LastTransID
    FROM DCS_Extra.SystemSetting AS st
    WHERE st.ID = ip_LastTransID_ParameterID;
    
	SELECT 	t.TransID
        ,	INET_ATON(t.IP) AS IPID
	FROM DCS_Extra.Transaction07 AS t
	WHERE t.TransID < lv_LastTransID
	ORDER BY t.TransID DESC
	LIMIT ip_BatchSize;
    
END$$

DELIMITER ;
