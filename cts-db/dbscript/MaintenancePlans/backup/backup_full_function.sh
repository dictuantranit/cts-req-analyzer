#!/bin/bash
function process_full_backup()
{
    ###### input params
    from_container=$1
    backup_path=$2
    slave_login_backup_path=$3
    master_login_log_path=$4
    log_dbname=$5
    run_date=$6
    binlog_volume=$7
    data_volume=$8
    network=$9
    login_path_folder=${10}
    
    ##### local variables
    BKSizeM=0

    if [ -n "$backup_path" ]
    then
        ##### log start process
        docker exec ${from_container} mysql --login-path=${master_login_log_path} -D${log_dbname} -e "
            INSERT INTO dba_BackupTask_Log(db_name,file_name,run_date) value ('','$backup_path','$run_date');
        "
		
        ##### do backup process	
	docker run -v ${binlog_volume}:/var/log/mysql/binlog \
		-v ${data_volume}:/var/lib/mysql \
		-v ${backup_path}:/xtrabackup_backupfiles \
		-v ${login_path_folder}:/root/.mylogin.cnf \
		--network ${network} perconalab/percona-xtrabackup:8.0.12 xtrabackup \
		--host=${from_container} \
		--login-path=${slave_login_backup_path} \
		--port=3306 \
		--slave-info \
		--compress-threads=2 \
		--parallel=2 \
		--compress \
		--backup                    

        ##### log end process
        BKSizeM=`du -sm $backup_path | awk '{print $1}'`
        docker exec ${from_container} mysql --login-path=${master_login_log_path} -D${log_dbname} -e "
            update dba_BackupTask_Log set file_size_m=$BKSizeM,end_time=current_timestamp() where file_name='$backup_path'; \
            update DCS_DataCenter.SystemSetting SET VValue='$run_date', UpdatedTime=now() WHERE VGroup='System_Backup' and VName='$backup_dbname';
        "
        echo "${backup_path}: SUCCESS"
        return 0
    fi

    echo "FAILED"
    return -1
}
