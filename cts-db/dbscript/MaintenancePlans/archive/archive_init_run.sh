#/bin/bash
BASEDIR=$(dirname "$0")
source $BASEDIR/archive_variable.sh
source $BASEDIR/archive_status_function.sh

ERROR_CODE=0
RESULT_INFO=$(init_archive_process_status $SLAVE_CONTAINER \
	$LOGIN_PATH_MASTER \
	$SLAVE_DBNAME)
ERROR_CODE=$?

ERROR_MSG=$(echo $RESULT_INFO | awk '{print $1}')
echo "init_archive_process_status: ${ERROR_CODE}-${ERROR_MSG}"

if [ "$ERROR_CODE" != "0" ]
then
	echo "EXIT -1"
	exit -1
fi
