#/bin/bash
BASEDIR=$(dirname "$0")
source $BASEDIR/archive_main_function.sh
source $BASEDIR/archive_status_function.sh
source $BASEDIR/archive_variable.sh

RUN_MODE="$1"
ERROR_CODE=0

if [ "$RUN_MODE" = "Transaction07" ]
then
    CTS_ARCHIVE_SOURCE="DCS_DataCenter Transaction07"
    CTS_ARCHIVE_TARGER="CTS_Archive Transaction180"
elif [ "$RUN_MODE" = "ProcessedTransaction" ]
then
    CTS_ARCHIVE_SOURCE="DCS_DataCenter ProcessedTransaction"
    CTS_ARCHIVE_TARGER="CTS_Archive ProcessedTransaction180"
fi

echo "RUN_MODE: ${RUN_MODE}"
if [ -z $RUN_MODE ]
then
    echo "RUN_MODE in Transaction07 or Transaction180 is REQUIRE"
    exit 0
fi

#SOURE_DBNAME="DCS_DataCenter"
#archive_mode="Transaction07"
SOURE_DBNAME=$(echo $CTS_ARCHIVE_SOURCE | awk '{print $1}')
ARCHIVE_MODE=$(echo $CTS_ARCHIVE_SOURCE | awk '{print $2}')

#archive_dbname="CTS_Archive"
#archive_table_name="Transaction180"
ARCHIVE_DBNAME=$(echo $CTS_ARCHIVE_TARGER | awk '{print $1}')
ARCHIVE_TABLE_NAME=$(echo $CTS_ARCHIVE_TARGER | awk '{print $2}')

###################################################################################################################
# Start archiving job
###################################################################################################################
echo "START archiving process ........"
echo "######################################################################"

#######################################################
# RUN ARCHIVING PROCESS
#######################################################
# Step 1 - Initial partition files to archive from slave
RESULT_INFO=$(get_archive_info_to_process $SLAVE_CONTAINER \
        $LOGIN_PATH_MASTER \
        $SOURE_DBNAME \
        $ARCHIVE_MODE \
        $LOG_DBNAME);

PARTITION_WEEK=$(echo $RESULT_INFO | awk '{print $1}')
ARCHIVE_STATUS=$(echo $RESULT_INFO | awk '{print $2}')
ARCHIVE_ID=$(echo $RESULT_INFO | awk '{print $3}')
ARCHIVE_ROWS=$(echo $RESULT_INFO | awk '{print $4}')
ARCHIVE_SIZE=$(echo $RESULT_INFO | awk '{print $5}')
PARTITION_WEEK_NEXT=$(echo $RESULT_INFO | awk '{print $6}')

##########################################################
# ARCHIVE INFO
##########################################################
echo "Step 1 >> ARCHIVE_MODE: ${ARCHIVE_MODE}, PARTITION_WEEK: ${PARTITION_WEEK}, ARCHIVE_STATUS: ${ARCHIVE_STATUS}, ARCHIVE_ROWS: ${ARCHIVE_ROWS}, ARCHIVE_SIZE: ${ARCHIVE_SIZE}"
echo "----------------------------------------------------------------------"

: <<'END'
##########################################################
# CHECK ZEROLIZE PARTITION
##########################################################
if [ "$ARCHIVE_STATUS" = "NEW" -a "$ARCHIVE_ROWS" = "0" ]
then
    RESULT_INFO=$(delete_partition_file_from_master $SLAVE_CONTAINER \
	    $LOGIN_PATH_MASTER \
	    $SOURE_DBNAME \
	    $ARCHIVE_MODE \
	    $PARTITION_WEEK)
    ERROR_CODE=$?
    echo "Step 1.1 >> ZEROLIZE PARTITION FOUND. EXIT with CODE ${ERROR_CODE}"
    echo "----------------------------------------------------------------------"
    exit 0
fi
END

##################################################
# Step 2 - Prepare partition from TARGET
##################################################
if [ "$ARCHIVE_STATUS" = "NEW" ]
then
    #### CHECK for existing from SOURCE
    check_exists=$(check_exists_partition $SLAVE_CONTAINER \
            $LOGIN_PATH_MASTER \
            $SOURE_DBNAME \
            $ARCHIVE_MODE \
            $PARTITION_WEEK)
    ERROR_CODE=$?

    #### SET ARCHIVE_STATUS
    ARCHIVE_STATUS="RUNNING"
    if [ -z $check_exists -a "$ERROR_CODE" = "0" ]
    then
        ARCHIVE_STATUS="INVALID"
    fi

    #### UPDATE ARCHIVE_STATUS
    $(update_archive_log_info $SLAVE_CONTAINER \
	        $LOGIN_PATH_MASTER \
	        $LOG_DBNAME \
	        $ARCHIVE_ID \
	        $ARCHIVE_STATUS)
    ERROR_CODE=$?

    #### ADD PARTITION from TARGET
    if [ "$ERROR_CODE" = "0" -a "$ARCHIVE_STATUS" = "RUNNING" ]
    then
        RESULT_INFO=$(prepare_partition_file_from_archive $SLAVE_CONTAINER \
            $LOGIN_PATH_ARCHIVE \
            $ARCHIVE_DBNAME \
            $ARCHIVE_TABLE_NAME \
            $PARTITION_WEEK \
            $PARTITION_WEEK_NEXT)
        ERROR_CODE=$?

        echo "Step 2 >> ARCHIVE_REORGANIZE: ${RESULT_INFO}"
    else
        echo "Step 2 >> ARCHIVE_REORGANIZE: ${ARCHIVE_STATUS}"
    fi
    echo "----------------------------------------------------------------------"
else
    echo "Step 2 >> ARCHIVE_REORGANIZE: ${ARCHIVE_STATUS}"
    echo "----------------------------------------------------------------------"
fi

################################################
# Step 3 - EXPORT partition data file from SOURCE to TARGET server
###############################################
if [ "$ERROR_CODE" = "0" ]
then
    # EXPORT data files
    RESULT_INFO=$(export_data_file_from_slave $SLAVE_CONTAINER \
            $SOURE_DBNAME \
            $ARCHIVE_MODE \
            $PARTITION_WEEK \
            $LOGIN_PATH_SLAVE \
            $ARCHIVE_HOST \
            $ARCHIVE_USER \
            $ARCHIVE_DATADIR \
            $ARCHIVE_DBNAME \
            $ARCHIVE_TABLE_NAME)
     ERROR_CODE=$?

    echo "Step 3 >> ARCHIVE_EXPORT_FILE: ${RESULT_INFO}"
    echo "----------------------------------------------------------------------"
fi

################################################
#step 4 - Load data file into target tablespace
################################################
if [ "$ERROR_CODE" = "0" ]
then
    RESULT_INFO=$(load_partition_file_from_archive $SLAVE_CONTAINER \
        $ARCHIVE_CONTAINER \
        $ARCHIVE_HOST \
        $ARCHIVE_USER \
        $ARCHIVE_DBNAME \
        $ARCHIVE_TABLE_NAME \
        $PARTITION_WEEK)
    ERROR_CODE=$?

    echo "Step 4 >> ARCHIVE_LOADING: ${RESULT_INFO}"
    echo "----------------------------------------------------------------------"
fi

################################################
#step 5.1 - Import partition tablespace from target
################################################
IMPORT_STATUS="NEW"
if [ "$ERROR_CODE" = "0" ]
then
    IMPORT_STATUS=$(import_partition_file_from_archive $SLAVE_CONTAINER \
            $LOGIN_PATH_ARCHIVE \
            $ARCHIVE_DBNAME \
            $ARCHIVE_TABLE_NAME \
            $PARTITION_WEEK) 
    ERROR_CODE=$?

    echo "Step 5.1 >> ARCHIVE_IMPORT: ${IMPORT_STATUS}"
    echo "----------------------------------------------------------------------"
fi

################################################
#step 5.1 - Import partition tablespace from target
################################################
EXCHANGE_STATUS="NEW"
if [ "$ERROR_CODE" = "0" ]
then
    EXCHANGE_STATUS=$(exchange_partition_file_to_table $SLAVE_CONTAINER \
            $ARCHIVE_CONTAINER \
            $ARCHIVE_HOST \
            $ARCHIVE_USER \
            $LOGIN_PATH_ARCHIVE \
            $ARCHIVE_DBNAME \
            $ARCHIVE_TABLE_NAME \
            $PARTITION_WEEK \
            $PARTITION_WEEK_NEXT) 
    ERROR_CODE=$?

    echo "Step 5.2 >> EXCHANGE_STATUS (${ERROR_CODE}): ${EXCHANGE_STATUS}"
    echo "----------------------------------------------------------------------"
fi


################################################
#step 6 - Delete partition from SOURE if existing from TARGET
################################################
if [ "$ERROR_CODE" = "0" ]
then
    #### CHECK for existing from TARGET
    check_exists=$(check_exists_partition $SLAVE_CONTAINER \
            $LOGIN_PATH_ARCHIVE \
            $ARCHIVE_DBNAME \
            $ARCHIVE_TABLE_NAME \
            $PARTITION_WEEK)
    ERROR_CODE=$?

    #### DROP partition from SOURE
    if [ -n "$check_exists" -a "$ERROR_CODE" = "0" ]
    then
        RESULT_INFO=$(delete_partition_file_from_master $SLAVE_CONTAINER \
	        $LOGIN_PATH_MASTER \
	        $SOURE_DBNAME \
	        $ARCHIVE_MODE \
	        $PARTITION_WEEK)
        #ERROR_CODE=$?

        echo "Step 6 >> ARCHIVE_DROP_SOURCE: ${RESULT_INFO}"
    else
        echo "Step 6 >> ARCHIVE_DROP_SOURCE: FAILED"
    fi
    echo "----------------------------------------------------------------------"
fi

##############################################
#step 7 - UPDATE log status
##############################################
ARCHIVE_STATUS="COMPLETED"
if [ "$ERROR_CODE" = "0" ]
then
    # UPDATE System_Archive status
    $(update_archive_process_status $SLAVE_CONTAINER \
	    $LOGIN_PATH_MASTER \
	    $SOURE_DBNAME \
	    $ARCHIVE_MODE \
        $PARTITION_WEEK)

    # UPDATE System_Archive Logs info
    ARCHIVE_INFO="{\"week\":${PARTITION_WEEK},\"rows\":${ARCHIVE_ROWS},\"sizeM\":${ARCHIVE_SIZE}}"
    $(update_archive_log_info $SLAVE_CONTAINER \
	    $LOGIN_PATH_MASTER \
	    $LOG_DBNAME \
	    $ARCHIVE_ID \
	    $ARCHIVE_STATUS \
        $ARCHIVE_INFO)

    echo "END archiving process with SUCCESS"
else
    ARCHIVE_STATUS="FAILED"
    # UPDATE System_Archive Logs info
    $(update_archive_log_info $SLAVE_CONTAINER \
	    $LOGIN_PATH_MASTER \
	    $LOG_DBNAME \
	    $ARCHIVE_ID \
	    $ARCHIVE_STATUS)
    echo "END archiving process with ERROR"
fi
echo "######################################################################"
########################################END proccess


