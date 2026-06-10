DELIMITER $$
DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_DC_ArchiveData_Transaction07_Delete$$
CREATE DEFINER=`fps`@`%` PROCEDURE DCS_DataCenter.DCS_DC_ArchiveData_Transaction07_Delete(IN ip_ArchivedDate DATETIME, OUT ip_Completed BOOLEAN)
BEGIN
	/*
	Created: 	20200723@Casey.Huynh
	Task : 		Enhance Archive Data From Transaction07 to Transaction90
	DB: 		DCS_DataCenter
	Original:

	Revisions:
	Param's Explanation (filtered by):
	*/   
	DECLARE vrMinID  BIGINT UNSIGNED;
    DECLARE vrMaxID  BIGINT UNSIGNED;
    DECLARE vrArchiveTransLogID INT;
    #=========================================================    
    SET ip_Completed = FALSE;
    
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;    
    SELECT 	FromTransId, ToTransId, ID
    INTO	vrMinID, vrMaxID, vrArchiveTransLogID
    FROM 	DCS_DataCenter.ArchiveTransLog 
    WHERE 	ArchivedDate = ip_ArchivedDate 
			AND Deleted = 0
    LIMIT 1;

    IF(vrMinID IS NULL)
    THEN
		UPDATE DCS_DataCenter.ArchiveHistory
		SET		Status = 2
				, EndTime = NOW()
        WHERE  	ArchivedDate = ip_ArchivedDate;        
        SET ip_Completed = TRUE;   
        
        UPDATE DCS_DataCenter.ArchiveStatus
        SET 	LastArchivedDate = GREATEST(LastArchivedDate, ip_ArchivedDate)
				, UpdateTime = NOW()
		WHERE	ArchiveID = 1;        
	ELSE
		DELETE ts07
        FROM	DCS_DataCenter.Transaction07 AS ts07 
        WHERE	ts07.TransID BETWEEN vrMinID AND vrMaxID
				AND CreatedDate = ip_ArchivedDate;
                
        UPDATE 	DCS_DataCenter.ArchiveTransLog
        SET 	Deleted = 1				
        WHERE	ID = vrArchiveTransLogID;
	END IF;

END$$
DELIMITER ;
