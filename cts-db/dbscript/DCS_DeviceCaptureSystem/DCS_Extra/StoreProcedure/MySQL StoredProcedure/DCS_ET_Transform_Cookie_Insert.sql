/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transform_Cookie_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transform_Cookie_Insert`(
	IN ip_TableName VARCHAR(50)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230809@Jonathan.Doan
		Task :		Insert into Cookie
		DB:			DCS_Extra
		Original:

		Revisions:
			- 20231108@Jonathan.Doan: Created [Redmine ID: #196570]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Transform_Cookie_Insert('Temp_Transaction');
    
    */
    DECLARE lv_CurrentDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Cookie;
        
	CREATE TEMPORARY TABLE Temp_Cookie(
			TmpID			INT UNSIGNED 		PRIMARY KEY
        ,	CookieID		BIGINT UNSIGNED		DEFAULT NULL
        ,	CookieCode		VARCHAR(64) 		NOT NULL
		,	IsNewCookie		TINYINT		 		DEFAULT 1
    );
    
	SET @sql = CONCAT('INSERT INTO Temp_Cookie(TmpID, CookieCode) 
						SELECT 	ID AS TmpID
							,	CookieCode 
                        FROM ', ip_TableName, 
					' WHERE CookieCode IS NOT NULL');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
	
	ALTER TABLE Temp_Cookie
	ADD INDEX IX_Temp_Cookie_CookieCode (CookieCode);
	 
    UPDATE Temp_Cookie AS tmp
		INNER JOIN DCS_Extra.Cookie AS c ON c.CookieCode = tmp.CookieCode
    SET tmp.IsNewCookie = 0;
	
	INSERT IGNORE INTO DCS_Extra.Cookie(CookieCode, CreatedDate)
	SELECT	DISTINCT
			CookieCode
		,	lv_CurrentDate AS CreatedDate
	FROM Temp_Cookie
    WHERE IsNewCookie = 1;
    
	UPDATE Temp_Cookie AS tmp
		INNER JOIN DCS_Extra.Cookie AS c ON c.CookieCode = tmp.CookieCode
	SET tmp.CookieID = c.ID;
    
	SET @sql = CONCAT('UPDATE ', ip_TableName,' AS tmp
						INNER JOIN Temp_Cookie AS c ON c.TmpID = tmp.ID
                        SET tmp.CookieID = c.CookieID');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;
