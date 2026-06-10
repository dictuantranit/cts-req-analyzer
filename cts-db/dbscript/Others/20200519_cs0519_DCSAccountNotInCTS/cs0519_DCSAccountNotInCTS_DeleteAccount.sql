DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteAccount$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteAccount()
BEGIN
	/*
		Created:	20200519@Casey
		Task:		Remove Account NOT In CTS
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	
	DELETE 		acc
    FROM 		DCS_DataCenter.Account AS acc
    INNER JOIN	CTS_Adhoc.cs0519_Account_RemoveBK AS accRev
    WHERE		acc.AccountID = accRev.AccountID;
    
END$$
DELIMITER ;