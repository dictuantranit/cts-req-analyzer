DELIMITER $$

USE DCS_DataCenter$$

DROP PROCEDURE IF EXISTS DCS_DataCenter.zzzIssueDI_Association_Remove$$

CREATE PROCEDURE DCS_DataCenter.zzzIssueDI_Association_Remove()
BEGIN
	/*
		Created:	20200313@CaseyHuynh
		Task :		Wrong DI. Remove Record From 03-37 to 04-01
		DB:			DCS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
        
        SELECT 	COUNT(1), MIN(AssociationID), MAX(AssociationID)
		FROM	DCS_DataCenter.Association ad
		WHERE	ad.CreatedDate >= '2020-03-07' AND ad.CreatedDate < '2020-04-02';
		#RETURN 173493	15309070	15571751
	*/
    
    DECLARE vr_AssociationID BIGINT;
    
    SET vr_AssociationID = 15309069;
    
   
   DROP TEMPORARY TABLE IF EXISTS Temp_AssociationID;
   CREATE TEMPORARY TABLE Temp_AssociationID
   (
		AssociationID	BIGINT
   );
      
   WHILE EXISTS (SELECT AssociationID
        FROM 	DCS_DataCenter.Association ad
        WHERE 	ad.CreatedTime >= '2020-03-27' AND ad.CreatedTime <= '2020-04-01 00:00:00' AND AssociationID > vr_AssociationID)  
   DO
		
        SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
        
        TRUNCATE TABLE Temp_AssociationID;
		INSERT INTO Temp_AssociationID(AssociationID)
        SELECT 	AssociationID
        FROM 	DCS_DataCenter.Association ad
        WHERE 	ad.CreatedTime >= '2020-03-27' AND ad.CreatedTime <= '2020-04-01 00:00:00' AND AssociationID > vr_AssociationID
        LIMIT	2000;

        INSERT IGNORE INTO DCS_DataCenter.zzzIssueDI_Association
		SELECT 		ad.*
        FROM 		DCS_DataCenter.Association AS ad
        INNER JOIN	DCS_DataCenter.Temp_AssociationID	AS ta 
					ON ad.AssociationID = ta.AssociationID
		LIMIT 		2000;
          
		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        
		DELETE 		ad
		FROM 		DCS_DataCenter.Association AS ad
        INNER JOIN	Temp_AssociationID	AS ta 
					ON ad.AssociationID = ta.AssociationID;
      
		SET vr_AssociationID = (SELECT MAX(AssociationID) FROM Temp_AssociationID);
	END WHILE;
END$$

DELIMITER ;