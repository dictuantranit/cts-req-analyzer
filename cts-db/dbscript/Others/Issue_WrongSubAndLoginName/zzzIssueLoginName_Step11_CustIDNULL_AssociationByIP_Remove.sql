DELIMITER $$

USE CTS_DataCenter$$

DROP PROCEDURE IF EXISTS CTS_DataCenter.zzzIssueLoginName_Step11_CustIDNULL_AssociationByIP_Remove$$

CREATE PROCEDURE CTS_DataCenter.zzzIssueLoginName_Step11_CustIDNULL_AssociationByIP_Remove()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong LoginName
	*/
    
	DECLARE vr_MaxID BIGINT;
    
	DECLARE vr_FromID BIGINT;
    DECLARE vr_ToID BIGINT;
 
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;  
	
    SELECT	MIN(zz.CTSAssIPID), MAX(zz.CTSAssIPID)
    INTO 	 vr_FromID, vr_MaxID
	FROM 	CTS_DataCenter.zzzIssueLoginName_AssociationByIP AS zz;
    #INNER JOIN 	CTS_DataCenter.CustEvidence AS ct
	#			ON ct.CTSAssIPID = zz.CTSAssIPID;
    

   WHILE (vr_FromID < vr_MaxID)  
   DO
		SET vr_ToID = (	SELECT MAX(tmp.CTSAssIPID) 
							FROM (SELECT CTSAssIPID FROM CTS_DataCenter.zzzIssueLoginName_AssociationByIP WHERE CTSAssIPID >= vr_FromID LIMIT 10000) AS tmp);

        DELETE 		ct
        FROM 		CTS_DataCenter.AssociationByIP AS ct
        INNER JOIN	CTS_DataCenter.zzzIssueLoginName_AssociationByIP AS zz
					ON ct.CTSAssIPID = zz.CTSAssIPID
        WHERE		ct.CTSAssIPID BETWEEN vr_FromID AND vr_ToID;
        
        SET vr_FromID = vr_ToID + 1 ;
        
	END WHILE;
    
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END$$

DELIMITER ;