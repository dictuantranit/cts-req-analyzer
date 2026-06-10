DELIMITER $$

USE CTS_DataCenter$$

DROP PROCEDURE IF EXISTS CTS_DataCenter.zzzIssueLoginName_Step9_CustIDNULL_CustEvidence_Remove$$

CREATE PROCEDURE CTS_DataCenter.zzzIssueLoginName_Step9_CustIDNULL_CustEvidence_Remove()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong LoginName
	*/
    
	DECLARE vr_MaxID BIGINT;
    
	DECLARE vr_FromID BIGINT;
    DECLARE vr_ToID BIGINT;
 
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;  
	
    SELECT	MIN(zz.CustEvidID), MAX(zz.CustEvidID)
    INTO 	 vr_FromID, vr_MaxID
	FROM 	CTS_DataCenter.zzzIssueLoginName_CustEvidence AS zz;
    #INNER JOIN 	CTS_DataCenter.CustEvidence AS ct
	#			ON ct.CustEvidID = zz.CustEvidID;
    

   WHILE (vr_FromID < vr_MaxID)  
   DO
		SET vr_ToID = (	SELECT MAX(tmp.CustEvidID) 
							FROM (SELECT CustEvidID FROM CTS_DataCenter.zzzIssueLoginName_CustEvidence WHERE CustEvidID >= vr_FromID LIMIT 10000) AS tmp);

        DELETE 		ct
        FROM 		CTS_DataCenter.CustEvidence AS ct
        INNER JOIN	CTS_DataCenter.zzzIssueLoginName_CustEvidence AS zz
					ON ct.CustEvidID = zz.CustEvidID
        WHERE		zz.CustEvidID BETWEEN vr_FromID AND vr_ToID;
        
        SET vr_FromID = vr_ToID + 1 ;
        
	END WHILE;
    
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END$$

DELIMITER ;