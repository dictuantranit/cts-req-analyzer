#!/bin/bash
########## BACKUP variables
CTS_DIR=/var/cts 
SLAVE_LOGIN_FOR_BACKUP=slave-backup 
MASTER_LOGIN_FOR_LOG=master-login 
CONTAINER_NAME=cts_slave_mysql80 
CONTAINER_BINLOG_VOLUMNE=/volumes/cts_slave_mysql80/binlog 
CONTAINER_DATA_VOLUMNE=/volumes/cts_slave_mysql80/data 
CONTAINER_LOGIN_VOLUMNE=/var/cts/backup/login_path/.mylogin.cnf 
CONTAINER_NETWORK=cts_network 
LOG_DB=CTS_Log 
RUN_DATE=$(date +%Y-%m-%d) 
BK_DIR=/var/cts/dump 
ERROR_CODE=0

########## LOAD cts backup function
source ${CTS_DIR}/backup/backup_full_function_xtrabackup.sh
                       
######### START backup process
echo "INFO - $(date +%Y-%m-%d-%H:%M:%S) >> START backing up ... "
   
BACKUP_PATH="$BK_DIR/CTS_BK_$(date +%Y%m%d)" 
mkdir $BACKUP_PATH 

result=$(process_full_backup $CONTAINER_NAME \
    $BACKUP_PATH \
    $SLAVE_LOGIN_FOR_BACKUP \
    $MASTER_LOGIN_FOR_LOG \
    $LOG_DB \
    $RUN_DATE \
    $CONTAINER_BINLOG_VOLUMNE \
    $CONTAINER_DATA_VOLUMNE \
    $CONTAINER_NETWORK \
    $CONTAINER_LOGIN_VOLUMNE)
    ERROR_CODE=$? 

echo "INFO - $(date +%Y-%m-%d-%H:%M:%S) >> END backing up $backup_dbname: $result"
# RUN mysql_logrotae weekly docker exec cts_slave_mysql80 logrotate -f /etc/logrotate.d/mysql_logrotate >> /var/cts/log/mysql_logrotate.log
