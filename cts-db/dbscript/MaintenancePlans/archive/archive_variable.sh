#/bin/bash
###########################
#SSH info
SSH_KEY_FILE="/var/log/mysql/tmp/.ssh/ctskey"

###############################
#MySQL login
LOGIN_PATH_MASTER="master-login"
LOGIN_PATH_SLAVE="slave-login"
LOGIN_PATH_ARCHIVE="archive-login"

###########################
#SLAVE info
SLAVE_CONTAINER="cts_slave_mysql80"
SLAVE_DBNAME="DCS_DataCenter"

##########################
#ARCHIVE info
ARCHIVE_CONTAINER="cts_archive_mysql80"
ARCHIVE_HOST="10.18.200.72"
ARCHIVE_USER="ctsdocker"
ARCHIVE_DATADIR="/volumes/cts_archive_mysql80/data"

################################################
#LOG info
LOG_DBNAME="CTS_Log"
PARTITION_PREFIX=p

