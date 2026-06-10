#/bin/bash
###################################
#check_container=$1
#login_path=$2
###################################
function init_archive_process_status()
{
    #### input parrams
    from_container=$1
    login_path=$2
    source_dbname=$3

    ##### local variables
    init_command="CALL DCS_Task_RawTransaction_Cleanup();"
    init_status=$(docker exec ${from_container} mysql --login-path=${login_path} -D${source_dbname} -sN -e "${init_command}")

    echo "$init_status"
    return 0
}

###################################
#check_container=$1
#login_path=$2
#check_dbname=$3
#check_table_name=$4
#partition_week=$5
###################################
function check_exists_partition() 
{
        #### input parrams
        from_container=$1
	    login_path=$2
        source_dbname=$3
        check_table_name=$4
        partition_week=$5
        
        ##### local variables
        partition_name="pw${partition_week}"

        check_command="SELECT pa.partition_name \
                FROM INFORMATION_SCHEMA.PARTITIONS pa \
                WHERE table_schema='${source_dbname}' \
                        AND table_name='${check_table_name}' \
                        AND partition_name='${partition_name}' \
                        AND EXISTS(SELECT 1 FROM ${check_table_name}) \
                LIMIT 1;"

        ##### run query from checking server
        check_exists=$(docker exec ${from_container} mysql --login-path=${login_path} -D${source_dbname} -sN -e "${check_command}")
        echo $check_exists
        return 0
}

###################################
#check_container=$1
#login_path=$2
#check_dbname=$3
#archive_mode=$4
#partition_week=$5
###################################
function update_archive_process_status() 
{
        #### input parrams
        check_container=$1
        login_path=$2
        source_dbname=$3
        archive_mode=$4
        partition_week=$5

        ##### local variables
        archive_fullmode="${source_dbname}.${archive_mode}"

        check_command="update SystemSetting \
                set VValue='${partition_week}', updatedtime=now() \
                where VGroup='System_Archive' \
                and VName='${archive_fullmode}';"

        ##### run query from checking server
        docker exec ${check_container} mysql --login-path=${login_path} -D${source_dbname} -e "${check_command}"
}

###################################
#check_container=$1
#login_path=$2
#log_dbname=$3
#archive_id=$4
#archive_status="$5"
#archive_info="$6"
###################################
function update_archive_log_info() 
{
        #### input parrams
        from_container=$1
        login_path=$2
        source_dbname=$3
        archive_id=$4
        archive_status="$5"
        archive_info="$6"

        ##### local variables
        start_command="update dba_ArchiveTask_Log \
                set status='${archive_status}', start_time=now() \
                where row_id=${archive_id};"

        end_command="update dba_ArchiveTask_Log \
                set archive_info='${archive_info}',status='${archive_status}', end_time=now() \
                where row_id=${archive_id};"

        ##### run query from checking server
        if [ $archive_status = "RUNNING" -o  $archive_status = "INVALID" ]
        then
	       	docker exec ${from_container} mysql --login-path=${login_path} -D${source_dbname} -e "${start_command}"

        elif [ $archive_status = "COMPLETED" ]
	    then
                docker exec ${from_container} mysql --login-path=${login_path} -D${source_dbname} -e "${end_command}"
        fi
}


