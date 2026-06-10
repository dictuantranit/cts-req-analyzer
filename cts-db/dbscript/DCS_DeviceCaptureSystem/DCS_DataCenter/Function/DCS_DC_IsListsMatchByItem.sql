
DELIMITER $$

USE `DCS_DataCenter`$$
DROP FUNCTION IF EXISTS DCS_DC_IsListsMatchByItem$$
CREATE FUNCTION DCS_DC_IsListsMatchByItem(ip_seperator VARCHAR(5), ip_List01 VARCHAR(5000), ip_List02 VARCHAR(5000))

RETURNS TINYINT

DETERMINISTIC

BEGIN
/*
	Created: 20190610@Casey.Huynh
	Task : Check 2 Lists are match if have any the same Item. Return 1 if match else return 0
	DB: DCS_DataCenter
	Original:

	Revisions:
	Param's Explanation (filtered by):
*/

	DECLARE i 		INT;
    DECLARE Result 	TINYINT DEFAULT 0;
	DECLARE Item 	VARCHAR(5000);	
    DECLARE	Str01	VARCHAR(5000);
    DECLARE	Str02	VARCHAR(5000);
    
	IF(ip_List01 = '' OR ISNULL(ip_List01)= 1 OR ip_List02 = '' OR ISNULL(ip_List02)= 1 ) THEN
		
		Return Result;
		
	END IF;
    
	SET Str01 = CONCAT(REPLACE(ip_List01,ip_seperator,','),',');
	SET Str02 = REPLACE(ip_List02,ip_seperator,',');  
    SET Item = SUBSTRING_INDEX(Str01,',',1);
    WHILE Length(Item) >=1 DO
		IF (FIND_IN_SET(Item, Str02) >  0) THEN
			SET Item = '';
            SET Result = 1;
		ELSE
			  SET Str01 = REPLACE(Str01,CONCAT(Item,','),'');
              SET Item = SUBSTRING_INDEX(Str01,',',1);
        END IF; 
    END WHILE;
    RETURN Result;
END$$

DELIMITER ;

