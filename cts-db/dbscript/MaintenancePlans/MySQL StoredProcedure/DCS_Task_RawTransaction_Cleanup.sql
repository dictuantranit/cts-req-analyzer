/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsCrontab" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transaction_GetLatest`;


DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_Task_RawTransaction_Cleanup`()
    SQL SECURITY INVOKER
BEGIN
	/*	
	Created: 20201102@Bobby.Nguyen
	Task : DCS_Task_RawTransaction_Cleanup
	DB: DCS_DataCenter
	Original: 
		- 20201102@Bobby.Nguyen: RawTransaction Cleanup - Keep the last two weeks
        - 20201118@Bobby.Nguyen: Extend partition - Transaction07 vs ProcessedTransaction
        
	Revisions:
	Param's Explanation (filtered by):
	*/
    
    DECLARE err_message VARCHAR(255);
    DECLARE err_no int DEFAULT 0;
    
    # ERROR handler
    DECLARE exit HANDLER FOR SQLEXCEPTION
	BEGIN
		GET DIAGNOSTICS CONDITION 1	
			err_message = MESSAGE_TEXT
            ,err_no = MYSQL_ERRNO;
		
		SELECT err_no, err_message;
	END;
    
    set @currentdate = now();
    set @currentweek = yearweek(@currentdate);
    set @weekdatedrop = date_add(@currentdate, interval -2 week);
	set @dropweek = yearweek(@weekdatedrop);
	set @pweekdrop = concat('pw', @dropweek);
		
    set @weekdatenext = date_add(@currentdate, interval 1 week);
	set @nextweek := yearweek(@weekdatenext);
	set @nextweeklimit := yearweek(date_add(@currentdate, interval 2 week));
	set @pnextweek := concat('pw', @nextweek);
    
    #select @currentweek as 'current_week', @dropweek as 'week_to_drop', @nextweek 'week_to_add';
    #####################################
    set @dropCMD = concat('alter table DCS_DataCenter.RawTransaction DROP partition ', @pweekdrop, ';');
    #select @dropCMD;
	prepare drop_statement from @dropCMD;
	execute drop_statement;
	deallocate prepare drop_statement;

	set @dropCMD = concat('alter table DCS_DataCenter.ProcessedTransaction DROP partition ', @pweekdrop, ';');
    #select @dropCMD;
	prepare drop_statement from @dropCMD;
	execute drop_statement;
	deallocate prepare drop_statement;
    
    ##########################################
	set @addCMD = concat('',
	'alter table DCS_DataCenter.RawTransaction ',
	'reorganize partition pw999999 INTO (',
		'partition ',@pnextweek,' VALUES LESS THAN (',@nextweeklimit,'), ',
		'partition pw999999 VALUES LESS THAN (MAXVALUE) ',
	');');
	prepare add_statement from @addCMD;
	execute add_statement;
	deallocate prepare add_statement;
    
    #############################################
    set @addCMD = concat('',
	'alter table DCS_DataCenter.Transaction07 ',
	'reorganize partition pw999999 INTO (',
		'partition ',@pnextweek,' VALUES LESS THAN (',@nextweeklimit,'), ',
		'partition pw999999 VALUES LESS THAN (MAXVALUE) ',
	');');
	prepare add_statement from @addCMD;
	execute add_statement;
	deallocate prepare add_statement;
    
    #############################################
    set @addCMD = concat('',
	'alter table DCS_DataCenter.ProcessedTransaction ',
	'reorganize partition pw999999 INTO (',
		'partition ',@pnextweek,' VALUES LESS THAN (',@nextweeklimit,'), ',
		'partition pw999999 VALUES LESS THAN (MAXVALUE) ',
	');');
	prepare add_statement from @addCMD;
	execute add_statement;
	deallocate prepare add_statement;
	#select @addCMD;
    
    ############################################
    ## Add dropweek to archive job
    INSERT INTO `CTS_Log`.`dba_ArchiveTask_Log`(`db_name`,`obj_name`,`archive_info`,`status`)
    WITH cts_archive as (
		select 'DCS_DataCenter' as `db_name`,
			'Transaction07' as `obj_name`,
			concat('{"week": ',@dropweek,'}') as `archive_info`,
			'NEW' as `status`
    )
    select `db_name`,`obj_name`,`archive_info`,	`status`
    from cts_archive;
    
    SELECT 0 AS err_no, '' AS err_message;
END$$

DELIMITER ;
;

