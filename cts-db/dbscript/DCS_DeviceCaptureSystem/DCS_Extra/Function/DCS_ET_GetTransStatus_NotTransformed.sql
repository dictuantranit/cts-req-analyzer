/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin,ctsService" isFunction="1" isNested="0"></info>*/
DROP FUNCTION IF EXISTS DCS_ET_GetTransStatus_NotTransformed;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` FUNCTION DCS_ET_GetTransStatus_NotTransformed() 

RETURNS BIT(16)

DETERMINISTIC
SQL SECURITY INVOKER
BEGIN
/*
	Created: 20190610@Casey.Huynh
	Task : Return the value of all TransStatus that Not Transform
	DB: DCS_Extra
	Original:

	Revisions:
		- 20190610@Casey.Huynh: Created [RedmineID: 190118]
        
	Param's Explanation (filtered by):
    
    Example: SELECT DCS_ET_GetTransStatus_NotTransformed();
*/

	DECLARE vrTransStatus BIT(16) DEFAULT 0;
	DECLARE vrTransStatus_i BIT(16) DEFAULT 0;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_NotTransformedStatus;
	CREATE TEMPORARY TABLE Temp_NotTransformedStatus(
		TransStatus BIT(16)
	);
	
	INSERT INTO Temp_NotTransformedStatus(TransStatus)
	SELECT  StatusValue
	FROM 	DCS_Extra.TransStatus
	WHERE	IsTransformed = 0;

	WHILE EXISTS (SELECT 1 FROM Temp_NotTransformedStatus LIMIT 1)
	DO
		SET vrTransStatus_i = (SELECT TransStatus FROM Temp_NotTransformedStatus LIMIT 1);        
		SET vrTransStatus = vrTransStatus | vrTransStatus_i;
		
		DELETE	ts
		FROM	Temp_NotTransformedStatus ts
		WHERE 	ts.TransStatus = vrTransStatus_i;        
	END WHILE;
	RETURN vrTransStatus;
END$$

DELIMITER ;

