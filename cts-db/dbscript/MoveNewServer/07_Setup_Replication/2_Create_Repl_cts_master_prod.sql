# RUN on slave server
use mysql;
stop slave;
reset slave all;
CHANGE MASTER TO MASTER_HOST='10.40.40.58',  
	MASTER_PORT=3306, 
	MASTER_USER='repl_sql', 
	MASTER_PASSWORD='cts@repl!0pen', 
	MASTER_AUTO_POSITION=1 
FOR CHANNEL 'cts_master_prod';

start slave for channel 'cts_master_prod';