DELIMITER $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.CTMAX_GetDCSAssociationByDevice$$
CREATE PROCEDURE CTS_Adhoc.CTMAX_GetDCSAssociationByDevice()
BEGIN
	/*
		Created:	20200527@CaseyHuynh 
		Param's Explanation (filtered by):                
	*/
    
	DECLARE prevID 	BIGINT DEFAULT -1;
    DECLARE toID 	BIGINT DEFAULT 0;
    
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    
    
    WHILE (prevID < toID)
    DO
		SET prevID = toID;
        
		INSERT INTO CTS_Adhoc.csCTMax_AssociationByDevice_bk
		SELECT 	*, 0
		FROM 	CTS_DataCenter.AssociationByDevice
		WHERE	SubscriberID IN (2328, 2367)
				AND CTSAssDevID > prevID
		ORDER BY CTSAssDevID
		LIMIT 10000;
                
		SET toID = (SELECT MAX(CTSAssDevID) FROM CTS_Adhoc.csCTMax_AssociationByDevice_bk);
        
    END WHILE;
    
END$$
DELIMITER ;