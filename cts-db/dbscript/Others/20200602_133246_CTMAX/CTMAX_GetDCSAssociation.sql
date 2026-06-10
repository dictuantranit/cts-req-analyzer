DELIMITER $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.CTMAX_GetDCSAssociation$$
CREATE PROCEDURE CTS_Adhoc.CTMAX_GetDCSAssociation()
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
        
		INSERT INTO CTS_Adhoc.csCTMax_Association_bk
		SELECT 	*, 0 AS IssueType
		FROM 	DCS_DataCenter.Association
		WHERE	SubscriberID IN (2328, 2367)
				AND AssociationID > prevID
		ORDER BY AssociationID
		LIMIT 10000;
                
		SET toID = (SELECT MAX(AssociationID) FROM CTS_Adhoc.csCTMax_Association_bk);
        
    END WHILE;
    
END$$
DELIMITER ;