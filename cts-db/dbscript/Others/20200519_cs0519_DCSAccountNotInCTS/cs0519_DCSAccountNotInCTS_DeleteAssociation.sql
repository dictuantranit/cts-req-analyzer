DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteAssociation$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteAssociation()
BEGIN
	/*
		Created:	20200519@Casey
		Task:		Remove Account NOT In CTS
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	
	DELETE 		ass
    FROM 		DCS_DataCenter.Association AS ass
    INNER JOIN	CTS_Adhoc.cs0519_Association_RemoveBK AS accRev
    WHERE		ass.AssociationID = accRev.AssociationID;
    
END$$
DELIMITER ;