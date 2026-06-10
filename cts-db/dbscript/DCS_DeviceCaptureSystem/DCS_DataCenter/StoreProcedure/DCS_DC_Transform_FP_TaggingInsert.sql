/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_FP_TaggingInsert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_FP_TaggingInsert`(
	IN ip_Taggings	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20240731@Jonathan.Doan
	    Task : Change Data Flow Ver. 6
		DB: DCS_DataCenter
		Original:

		Revisions:
			- 20240730@Jonathan.Doan: Created [Redmine ID: #206403]
			- 20241111@Jonathan.Doan: Check when Tagging empty [Redmine ID: #212696]

		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Transform_FP_TaggingInsert('Tagging1,Tagging2,Tagging4');
            select * from DCS_DataCenter.FP_Tagging;
	*/
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Tagging;
    
	CREATE TEMPORARY TABLE Temp_Tagging(
			Tagging			 			VARCHAR(32) NOT NULL			PRIMARY KEY
		,	IsNewRecord					TINYINT		 					DEFAULT 1
    );
    
    SET @sql = CONCAT("INSERT IGNORE INTO Temp_Tagging (Tagging) VALUES ('", REPLACE(ip_Taggings, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    UPDATE Temp_Tagging AS tmp
		INNER JOIN DCS_DataCenter.FP_Tagging AS tg ON tg.Tagging = tmp.Tagging
    SET tmp.IsNewRecord = 0;
	
    INSERT IGNORE INTO DCS_DataCenter.FP_Tagging(Tagging)
	SELECT Tagging
	FROM Temp_Tagging
    WHERE IsNewRecord = 1
		AND Tagging <> '';
END$$

DELIMITER ;