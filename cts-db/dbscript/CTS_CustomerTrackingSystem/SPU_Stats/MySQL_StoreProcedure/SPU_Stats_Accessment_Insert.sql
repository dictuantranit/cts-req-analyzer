
DROP PROCEDURE IF EXISTS `SPU_Stats_Accessment_Insert_xtest`;

DELIMITER $$
CREATE DEFINER=`SPUStatsOwner`@`%` PROCEDURE `SPU_Stats_Accessment_Insert_xtest`(
		IN ip_SystemId 			BIGINT UNSIGNED
	,	IN ip_FunctionId		INT
	,	IN ip_UserId 			INT 
	
	,	OUT op_ErrorMessage 	VARCHAR(200)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220114@Long.Luu
		Task:		Insert accessment
		DB:			SPU_Stats
		Revisions:
			- 20220114@Long.Luu: Created [Redmine ID: #0000]
            
		Param's Explanation (filtered by):
        
        Example:
			-  set @op_OutPut='0';
			   CALL SPU_Stats.SPU_Stats_Accessment_Insert(1,1,1, @op_TotalItems);
			   select @op_OutPut; 
	*/
    
	DECLARE lv_CurrentMonth	 	DATE;
    DECLARE lv_AccessCounter 	INT UNSIGNED;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    SET lv_CurrentMonth = DATE_ADD(DATE_ADD(LAST_DAY(NOW()),interval 1 DAY),interval -1 MONTH);
    
    IF EXISTS (	SELECT 1 
				FROM SPU_Stats.AccessStats 
				WHERE SystemId = ip_SystemId AND FunctionId = ip_FunctionId 
					AND UserId = ip_UserId AND RptMonth = lv_CurrentMonth) THEN
                    
		SELECT (AccessCounter + 1)
        INTO lv_AccessCounter
        FROM SPU_Stats.AccessStats 
		WHERE SystemId = ip_SystemId AND FunctionId = ip_FunctionId 
			AND UserId = ip_UserId AND RptMonth = lv_CurrentMonth;
              
		UPDATE SPU_Stats.AccessStats
        SET AccessCounter = lv_AccessCounter
			,	LastAccessedTime = NOW()
        WHERE SystemId = ip_SystemId 
			AND FunctionId = ip_FunctionId 
            AND UserId = ip_UserId 
            AND RptMonth = lv_CurrentMonth;
	ELSE
		INSERT INTO SPU_Stats.AccessStats(SystemId, FunctionId, UserId, RptMonth, AccessCounter, LastAccessedTime)
        VALUES (ip_SystemId, ip_FunctionId, ip_UserId, lv_CurrentMonth, 1, NOW());
    END IF;
                
END$$
DELIMITER ;


