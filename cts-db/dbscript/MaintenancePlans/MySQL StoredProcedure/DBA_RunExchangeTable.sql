/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsCrontab" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DBA_RunExchangeTable`;


DELIMITER $$
CREATE DEFINER=`bobby.vn`@`%` PROCEDURE `DBA_RunExchangeTable`(IN runMode varchar(128), IN stepId int, IN partition_week int, IN partition_week_next int)
BEGIN
	if runMode='Transaction180'
    THEN
		IF stepId=1
        THEN
			alter table Transaction180_temp drop index IX_Transaction07_CreatedDate;
			alter table Transaction180_temp drop index IX_Transaction07_TransTime;
			alter table Transaction180_temp drop index IX_Transaction07_SubscriberID_TransTime;
            alter table Transaction180_temp drop index IX_Transaction07_AccountID;

			##################################################################################
			drop table if exists Transaction180_exchange;
			CREATE TABLE Transaction180_exchange LIKE Transaction180;
			ALTER TABLE Transaction180_exchange REMOVE PARTITIONING;
			ALTER TABLE Transaction180_exchange DISCARD TABLESPACE;
        ELSEIF stepId=2
        THEN
			set @partition_name = CONCAT('pw', partition_week);
            #table exchange
            set @prepare_TSQL = CONCAT('
			ALTER TABLE Transaction180
			reorganize partition pw999999 INTO ( 
					partition ', @partition_name, ' VALUES LESS THAN (', partition_week_next, '), 
					partition pw999999 VALUES LESS THAN (MAXVALUE)
			);');
            PREPARE prepare_statement FROM @prepare_TSQL;
			EXECUTE prepare_statement;
			DEALLOCATE PREPARE prepare_statement;
            
            set @exchange_TSQL = CONCAT('ALTER TABLE Transaction180 EXCHANGE PARTITION ', @partition_name, ' WITH TABLE Transaction180_exchange;');
            PREPARE exchange_statement FROM @exchange_TSQL;
			EXECUTE exchange_statement;
			DEALLOCATE PREPARE exchange_statement;
            
            #clean exchange table
			#drop table if exists Transaction180_exchange;
            #drop table if exists Transaction180_temp;
			#CREATE TABLE Transaction180_temp LIKE Transaction07_master;
        END IF;
    END IF;
    
    IF runMode='ProcessedTransaction180'
    THEN
		IF stepId=1
        THEN
			alter table ProcessedTransaction180_temp drop index IX_RawTransaction_IsProcessed;
			alter table ProcessedTransaction180_temp drop index IX_RawTransaction_TransTime;
			alter table ProcessedTransaction180_temp drop index IX_RawTransaction_SubscriberName_CreatedDate;

			##################################################################################
			drop table if exists ProcessedTransaction180_exchange;
			CREATE TABLE ProcessedTransaction180_exchange LIKE ProcessedTransaction180;
			ALTER TABLE ProcessedTransaction180_exchange REMOVE PARTITIONING;
			ALTER TABLE ProcessedTransaction180_exchange DISCARD TABLESPACE;
        ELSEIF stepId=2
        THEN
			set @partition_name = CONCAT('pw', partition_week);
            #table exchange
            set @prepare_TSQL = CONCAT('
			ALTER TABLE ProcessedTransaction180
			reorganize partition pw999999 INTO ( 
					partition ', @partition_name, ' VALUES LESS THAN (', partition_week_next, '), 
					partition pw999999 VALUES LESS THAN (MAXVALUE)
			);');
            PREPARE prepare_statement FROM @prepare_TSQL;
			EXECUTE prepare_statement;
			DEALLOCATE PREPARE prepare_statement;
            
            set @exchange_TSQL = CONCAT('ALTER TABLE ProcessedTransaction180 EXCHANGE PARTITION ', @partition_name, ' WITH TABLE ProcessedTransaction180_exchange;');
            PREPARE exchange_statement FROM @exchange_TSQL;
			EXECUTE exchange_statement;
			DEALLOCATE PREPARE exchange_statement;
            
            #clean exchange table
			#drop table if exists ProcessedTransaction180_exchange;
			#drop table if exists ProcessedTransaction180_temp;
			#CREATE TABLE ProcessedTransaction180_temp LIKE ProcessedTransaction_master;
        END IF;
    END IF;
END$$

DELIMITER ;
;

