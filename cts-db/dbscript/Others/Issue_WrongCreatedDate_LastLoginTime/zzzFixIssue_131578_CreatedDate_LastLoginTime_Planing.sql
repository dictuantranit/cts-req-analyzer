DELIMITER $$
CREATE DEFINER=`fps`@`%` PROCEDURE `zzzFixIssue_131578_CreatedDate_LastLoginTime_Planing`(IN ip_size INT, IN ip_maxTransId BIGINT, IN ip_isBK BOOLEAN)
BEGIN
	DECLARE v_maxId   BIGINT UNSIGNED default 1;
    DECLARE v_minId   BIGINT UNSIGNED default 0;
	DECLARE v_take INT;    
    
    CREATE TABLE IF NOT EXISTS DCS_DataCenter.zzzTransaction_temp_planingByTransId (
		  Id INT NOT NULL AUTO_INCREMENT,  
 		  FromTransId BIGINT, 
          ToTransId BIGINT,
          Status BOOLEAN,   
          IsBK BOOLEAN,
          MaxTransId BIGINT,
		  PRIMARY KEY  (Id),
          INDEX RangeIndex(FromTransId, ToTransId)
		);
        
    #TRUNCATE TABLE DCS_DataCenter.zzzTransaction_temp_planingByTransId;
    
    SET v_take = ip_size;
	SET v_maxId = ip_maxTransId;
    
    IF ip_isBK = false THEN
		WHILE v_maxId is not null && v_maxId != 0 DO   
				
                SELECT Min(a.TransId), Max(a.TransId) INTO v_minId, v_maxId 
					FROM (SELECT TransId 
					FROM DCS_DataCenter.Transaction07 a WHERE TransId > v_maxId ORDER BY TransId LIMIT v_take) as a;
                
				IF v_minId is not null && v_maxId is not null THEN
					INSERT INTO DCS_DataCenter.zzzTransaction_temp_planingByTransId(FromTransId, ToTransId, Status, IsBK, MaxTransId)
					VALUE(v_minId, v_maxId, false, false, v_maxId);  
					
					Call DCS_DataCenter.zzzFixIssue_131578_CreatedDate_LastLoginTime_Processing(v_minId, v_maxId, false);
				END IF;
			END WHILE;
    ELSE
		WHILE v_maxId is not null && v_maxId != 0 DO    
			SELECT Min(a.TransId), Max(a.TransId) INTO v_minId, v_maxId 
					FROM (SELECT TransId
					FROM DCS_DataCenter.Transaction_BK01 a WHERE TransId > v_maxId ORDER BY TransId LIMIT v_take) as a;			
				
			IF v_minId is not null && v_maxId is not null THEN
				INSERT INTO DCS_DataCenter.zzzTransaction_temp_planingByTransId(FromTransId, ToTransId, Status, IsBK, MaxTransId)
				VALUE(v_minId, v_maxId, false, true, v_maxId); 
				
				Call DCS_DataCenter.zzzFixIssue_131578_CreatedDate_LastLoginTime_Processing(v_minId, v_maxId, true);
			END IF;        
		END WHILE; 
    END IF;       
        
END$$
DELIMITER ;
