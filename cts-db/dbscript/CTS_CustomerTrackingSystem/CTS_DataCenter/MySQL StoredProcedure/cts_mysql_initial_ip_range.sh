#!/bin/bash
 for i in $( find /home/vnteam/fps40/ -name *.csv); 
 do
 $(MYSQL_PWD=fps@1qaz@Wsx# mysql -u "fps" -D "CTS_DataCenter" -e "TRUNCATE TABLE IPRangeLocation_Initial; LOAD DATA LOCAL INFILE '$i' 
                                                              INTO TABLE IPRangeLocation_Initial 
                                                              FIELDS TERMINATED BY '|' 
                                                              LINES TERMINATED BY '\r\n' 
                                                              (IPRangeLocationCode,FromIP,ToIP,CountryCode,CountryName,Region,City,ISPName,Status,CreatedDate);")
 done
