#/bin/bash
CTS_DIR=/var/cts/archive
source $CTS_DIR/archive_variable.sh
source $CTS_DIR/archive_status_function.sh

########## RUN init function
ERROR_CODE=0
#esult="0"
result=$(init_archive_process_status $SLAVE_CONTAINER \
  		$LOGIN_PATH_MASTER \
  		$SLAVE_DBNAME)

ERROR_CODE=$(echo $result | awk '{print $1}')

echo "INFO - $(date +%Y-%m-%d-%H:%M:%S) - Archiving process initializing ... >> ${result:-NA}"
if [ "$ERROR_CODE" = "0" ]
then
	###############################
	bash ${CTS_DIR}/archive_process_run.sh "Transaction07"
else
	echo "ERROR - $(date +%Y-%m-%d-%H:%M:%S) - Archiving process stopped with ERROR-${ERROR_CODE}"
fi


