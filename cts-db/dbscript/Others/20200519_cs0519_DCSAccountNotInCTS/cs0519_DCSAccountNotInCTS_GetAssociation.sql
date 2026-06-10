DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetAssociation$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetAssociation()
BEGIN
	/*
		Created:	20200519@Casey
		Task:		Remove Account NOT In CTS
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DROP TABLE IF EXISTS CTS_Adhoc.cs0519_Association_RemoveBK;
	CREATE TABLE CTS_Adhoc.cs0519_Association_RemoveBK
    SELECT		ass.*
	FROM 		DCS_DataCenter.Association AS ass
	INNER JOIN 	CTS_Adhoc.cs0519_Account_RemoveBK AS accRe
				ON ass.AccountID = accRe.AccountID;	

END$$
DELIMITER ;