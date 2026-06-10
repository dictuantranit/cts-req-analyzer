#!/bin/bash
# RUN mysql_logrotae weekly
docker exec cts_slave_mysql80 logrotate -f /etc/logrotate.d/mysql_logrotate
