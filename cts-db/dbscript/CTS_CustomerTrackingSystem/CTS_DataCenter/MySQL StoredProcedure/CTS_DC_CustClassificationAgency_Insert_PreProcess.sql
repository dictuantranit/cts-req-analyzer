/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_Insert_PreProcess`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_Insert_PreProcess`(
    	IN ip_InputFlowID 	INT
)
    SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240927@Thomas.Nguyen
		Task:		
		DB:			CTS_DataCenter

		Param's Explanation (filtered by):
        
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Insert_PreProcess(1009);
				
		Revisions: 
			-	20240927@Thomas.Nguyen: Created [Redmine ID: #185799]
            -	20250725@Casey.Huynh: Agent CC, Considerable Danger [Redmine ID: #219679]
*/ 
    DECLARE CONST_ACTIONTYPE_EXISTEDPA 						INT DEFAULT 3;
    DECLARE CONST_ACTIONTYPE_EXISTEDVVIP					INT DEFAULT 4;
    DECLARE CONST_ACTIONTYPE_EXISTEDCD						INT DEFAULT 9;

	/*EXCLUDE INTERNAL CUSTOMERS*/      
	CALL CTS_DataCenter.CTS_DC_ExcludeCustByCondition('Temp_NewClassification');

    DROP TEMPORARY TABLE IF EXISTS Temp_CustIgnoranceAction;    
    CREATE TEMPORARY TABLE Temp_CustIgnoranceAction(	  	
            CustID					BIGINT UNSIGNED	PRIMARY KEY
        , 	ActionType				SMALLINT      
        ,	IsReturnData			TINYINT(1)
    ); 
    
    INSERT IGNORE INTO Temp_CustIgnoranceAction(CustID, ActionType, IsReturnData)
    SELECT DISTINCT temp.CustID, CONST_ACTIONTYPE_EXISTEDVVIP, 0 AS IsReturnData
    FROM Temp_NewClassification AS temp
    WHERE temp.IsExistVVIP = 1;

    INSERT IGNORE INTO Temp_CustIgnoranceAction(CustID, ActionType, IsReturnData)
    SELECT DISTINCT temp.CustID, CONST_ACTIONTYPE_EXISTEDPA, 0 AS IsReturnData
    FROM Temp_NewClassification AS temp
    WHERE temp.IsExistPA = 1;
    
    INSERT IGNORE INTO Temp_CustIgnoranceAction(CustID, ActionType, IsReturnData)
    SELECT DISTINCT temp.CustID, CONST_ACTIONTYPE_EXISTEDCD, 0 AS IsReturnData
    FROM Temp_NewClassification AS temp
    WHERE temp.IsExistCD = 1;
    
    /* NO ACTION + VIEW LOG FOR IGNORE CASES*/ 
    UPDATE Temp_NewClassification AS temp 
        INNER JOIN Temp_CustIgnoranceAction AS ig ON temp.CustID = ig.CustID
    SET 	temp.ActionType = ig.ActionType
        , 	temp.IsDataChanged = 0
        , 	temp.IsReturnData = ig.IsReturnData;
		
END$$
DELIMITER ;