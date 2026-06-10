/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_ArchiveData_ModifiedDate_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_ArchiveData_ModifiedDate_Update`(
	ip_BatchSize INT
)
    SQL SECURITY INVOKER
sp:BEGIN
	/*
		Created:	20230821@Jonathan.Doan
		Task:		Update the ModifiedDate of tables that require archiving.
		DB:			DCS_Extra
		Original:

		Revisions:
			- 20230821@Jonathan.Doan: Created [Redmine ID: #191960]
            
		Param's Explanation (filtered by):

		Example:
			CALL DCS_ET_ArchiveData_ModifiedDate_Update(100);
	*/ 
    DECLARE CONST_TRANS07_SYSTEMARCHIVEID INT DEFAULT 4963733;
    DECLARE lv_MaxTransID BIGINT UNSIGNED;
    
    SELECT VValue
    INTO lv_MaxTransID
    FROM DCS_Extra.SystemSetting
    WHERE ID = CONST_TRANS07_SYSTEMARCHIVEID;


    /*******INIT TEMPORARY TABLE************/
    DROP TEMPORARY TABLE IF EXISTS Temp_Transaction07;
	CREATE TEMPORARY TABLE Temp_Transaction07(
        	TransID				BIGINT UNSIGNED PRIMARY KEY
        ,	BotComponentID		BIGINT UNSIGNED DEFAULT NULL
        ,	CreatedDate			DATETIME
        , 	INDEX IX_Temp_Transaction07_CreatedDate(CreatedDate)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_BotComponent;
	CREATE TEMPORARY TABLE Temp_BotComponent(
        	ID					BIGINT UNSIGNED PRIMARY KEY
        ,	MaxCreatedDate		DATETIME
    );
    
    /*******GET DATA Transaction07********************/
    INSERT INTO Temp_Transaction07(TransID, BotComponentID, CreatedDate)
    SELECT 	TransID
        ,	BotComponentID
        ,	CreatedDate
	FROM DCS_Extra.Transaction07
	WHERE TransID > lv_MaxTransID
	LIMIT ip_BatchSize;
    
    /*******INIT DATA********************/
    INSERT INTO Temp_BotComponent(ID, MaxCreatedDate)
    SELECT 	BotComponentID AS ID
		,	MAX(CreatedDate) AS MaxCreatedDate
    FROM Temp_Transaction07
    WHERE BotComponentID IS NOT NULL
    GROUP BY BotComponentID;

    /*******UPDATE ModifiedDate********************/
	UPDATE DCS_Extra.BotComponent AS main
		INNER JOIN Temp_BotComponent AS tmp ON tmp.ID = main.ID
	SET main.ModifiedDate = tmp.MaxCreatedDate;
    
    
    /*******UPDATE SystemSetting MaxTransID********************/
    SELECT MAX(TransID)
    INTO lv_MaxTransID
    FROM Temp_Transaction07;
    
    IF lv_MaxTransID IS NOT NULL
    THEN
		UPDATE DCS_Extra.SystemSetting
		SET VValue = lv_MaxTransID
		WHERE ID = CONST_TRANS07_SYSTEMARCHIVEID;
    END IF;
END$$

DELIMITER ;