/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transform_Account_UpdateLastLoginTime`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transform_Account_UpdateLastLoginTime`(
		IN BatchSize 	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230630@Casey.Huynh
		Task:		Transform CTSMax, Velki
		DB:			DCS_Extra
		Original:

		Revisions:
			- 20230630@Casey.Huynh: Created [RedmineID: #190118]
			
		Param's Explanation (filtered by):
	*/ 
   
    DROP TEMPORARY TABLE IF EXISTS Temp_AccountLastLoginTimeProcess;  
	CREATE TEMPORARY TABLE Temp_AccountLastLoginTimeProcess(
			ID 				BIGINT UNSIGNED
		,	AccountID 		BIGINT UNSIGNED
		,	LastLoginTime 	TIMESTAMP(4) NOT NULL
		,	PRIMARY KEY (ID)     
        ,	INDEX 			IX_Temp_AccountLastLoginTimeProcess_AccountID(AccountID)
    );
    
    INSERT INTO Temp_AccountLastLoginTimeProcess(ID, AccountID, LastLoginTime)
    SELECT 	acc.ID
		,	acc.AccountID
        ,	acc.LastLoginTime
    FROM DCS_Extra.AccountLastLoginTimeProcess AS acc
    ORDER BY acc.ID ASC
    LIMIT BatchSize;
    
    UPDATE DCS_Extra.Account 	AS acc
        INNER JOIN	Temp_AccountLastLoginTimeProcess AS tll ON acc.AccountID = tll.AccountID
	SET	 acc.LastLoginTime = tll.LastLoginTime; 
    
    DELETE FROM DCS_Extra.AccountLastLoginTimeProcess AS acc
    WHERE acc.ID IN (SELECT ID FROM Temp_AccountLastLoginTimeProcess);
    
END$$
DELIMITER ;
