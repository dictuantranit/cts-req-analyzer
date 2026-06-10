/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_ArchiveData_NewAccountDevice`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_ArchiveData_NewAccountDevice`()
    SQL SECURITY INVOKER
sp:BEGIN
	/*
		Created:	20230413@Jonathan.Doan
		Task:		Archive Sent Transactions
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20230413@Jonathan.Doan: Created [Redmine ID: #185185]
		Param's Explanation (filtered by):

		Example:
			- CALL DCS_DataCenter.DCS_DC_ArchiveData_NewAccountDevice();
	*/ 
	
    DECLARE lv_CurrentDate			DATETIME DEFAULT NOW();
    DECLARE lv_LastWeekDate			DATETIME DEFAULT DATE_SUB(lv_CurrentDate, INTERVAL 1 WEEK);
    DECLARE lv_LastPartition		VARCHAR(50) DEFAULT CONCAT('p',10000000+YEARWEEK(lv_LastWeekDate));
    
    DECLARE lv_DropPartition		LONGTEXT;
    DECLARE lv_AlterPartition		LONGTEXT;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Partition;
    CREATE TEMPORARY TABLE Temp_Partition(
			PartitionOrdinalPosition INT PRIMARY KEY
        ,	PartitionName	VARCHAR(100)
        
        ,	INDEX IX_Temp_Partition_PartitionName(PartitionName)
    );
    
    INSERT INTO Temp_Partition(PartitionOrdinalPosition, PartitionName)
    SELECT	p.Partition_Ordinal_Position
		,	p.Partition_Name 
    FROM INFORMATION_SCHEMA.`PARTITIONS` AS p
    WHERE p.TABLE_SCHEMA = 'DCS_DataCenter' 
		AND p.`TABLE_NAME` = 'NewAccountDevice';
        
	SELECT GROUP_CONCAT(tmp.PartitionName SEPARATOR ',')
    INTO lv_DropPartition
    FROM Temp_Partition AS tmp
    WHERE tmp.PartitionName <= lv_LastPartition
		AND tmp.PartitionName <> 'p10000000';
    
    IF lv_DropPartition IS NOT NULL THEN        
		SET @sql = CONCAT('ALTER TABLE DCS_DataCenter.NewAccountDevice DROP PARTITION ',lv_DropPartition,';');
		PREPARE stmt FROM  @sql;
		EXECUTE stmt; 
		DEALLOCATE PREPARE stmt;
    END IF;    
    
    WITH RECURSIVE week_numbers AS (
		SELECT 10000000+YEARWEEK(lv_CurrentDate) AS week_number, CONCAT('p',10000000+YEARWEEK(lv_CurrentDate)) AS partition_name, 1 AS rn
		UNION ALL
		SELECT 10000000+YEARWEEK(DATE_ADD(lv_CurrentDate, INTERVAL rn WEEK)) AS week_number, CONCAT('p',10000000+YEARWEEK(DATE_ADD(lv_CurrentDate, INTERVAL rn WEEK))) AS partition_name, rn + 1
		FROM week_numbers
		WHERE rn < 10
	)
	SELECT GROUP_CONCAT(CONCAT('PARTITION ',partition_name,' VALUES LESS THAN (',week_number,')') SEPARATOR ',')
    INTO lv_AlterPartition
	FROM week_numbers AS wno
		LEFT JOIN Temp_Partition AS tmp ON tmp.PartitionName = wno.partition_name
	WHERE tmp.PartitionOrdinalPosition IS NULL;
    
    IF lv_AlterPartition IS NOT NULL THEN
		SET @sql = CONCAT('
			ALTER TABLE DCS_DataCenter.NewAccountDevice
			REORGANIZE PARTITION p19999999 INTO (    
			',lv_AlterPartition,',
			PARTITION p19999999 VALUES LESS THAN MAXVALUE) 
			;
		');
		PREPARE stmt FROM  @sql;
		EXECUTE stmt; 
		DEALLOCATE PREPARE stmt;
    END IF;
    
END$$

DELIMITER ;