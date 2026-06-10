DELIMITER $$
USE CTS_Adhoc $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetAccount$$

CREATE PROCEDURE CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetAccount()
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
    DROP TABLE IF EXISTS CTS_Adhoc.cs0519_Account_RemoveBK;
	CREATE TABLE CTS_Adhoc.cs0519_Account_RemoveBK
	SELECT 		acc.*
	FROM 		DCS_DataCenter.Account	acc
	LEFT JOIN 	CTS_DataCenter.CustDCSAccount cusAcc
				ON acc.AccountID = cusAcc.AccountID
	WHERE		cusAcc.AccountID IS NULL
				AND IsCTSTransformed = 1;

END$$
DELIMITER ;