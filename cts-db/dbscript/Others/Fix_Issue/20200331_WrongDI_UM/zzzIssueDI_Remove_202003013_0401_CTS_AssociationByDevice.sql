DELIMITER $$

USE CTS_DataCenter$$

DROP PROCEDURE IF EXISTS CTS_DataCenter.zzzIssueDI_AssociationByDevice_RemoveUM$$

CREATE PROCEDURE CTS_DataCenter.zzzIssueDI_AssociationByDevice_RemoveUM()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong DI. Remove Record From 03-37 to 04-01
		DB:			CTS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):              

		SELECT 	COUNT(1), MIN(CTSAssDevID), MAX(CTSAssDevID)
		FROM 	CTS_DataCenter.AssociationByDevice ad
		WHERE 	ad.CreatedTime >= '2020-04-01' AND ad.CreatedTime <= '2020-04-01 5:00:00'
		; #45027	11787533	12285187
        
	*/
    
    DECLARE vr_CTSAssDevID BIGINT;
    
    SET vr_CTSAssDevID = 11787532;
    
   
   DROP TEMPORARY TABLE IF EXISTS Temp_AssociationID;
   CREATE TEMPORARY TABLE Temp_AssociationID
   (
		CTSAssDevID	BIGINT
   );
   
   
   WHILE EXISTS (SELECT CTSAssDevID
        FROM 	CTS_DataCenter.AssociationByDevice ad
        WHERE 	ad.CreatedTime >= '2020-04-01' AND ad.CreatedTime <= '2020-04-01 5:00:00' AND CTSAssDevID > vr_CTSAssDevID)  
   DO
		
        SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        
        TRUNCATE TABLE Temp_AssociationID;
		INSERT INTO Temp_AssociationID(CTSAssDevID)
        SELECT 	CTSAssDevID
        FROM 	CTS_DataCenter.AssociationByDevice ad
        WHERE 	ad.CreatedTime >= '2020-04-01' AND ad.CreatedTime <= '2020-04-01 5:00:00' AND CTSAssDevID > vr_CTSAssDevID
        LIMIT	2000;

        INSERT IGNORE INTO CTS_DataCenter.zzzIssueDI_AssociationByDevice_UM
		SELECT		ad.*
        FROM 		CTS_DataCenter.AssociationByDevice AS ad
        INNER JOIN	CTS_DataCenter.Temp_AssociationID	AS ta 
					ON ad.CTSAssDevID = ta.CTSAssDevID;
          
		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
		
		DELETE 		ad
		FROM 		CTS_DataCenter.AssociationByDevice AS ad
        INNER JOIN	Temp_AssociationID	AS ta 
					ON ad.CTSAssDevID = ta.CTSAssDevID;       
        
        SET vr_CTSAssDevID = (SELECT MAX(CTSAssDevID) FROM Temp_AssociationID);
	END WHILE;
END$$

DELIMITER ;