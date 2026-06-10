#######################################################################################
# CTS >> backup full at 1:00 AM on TUE weekly
0 1 * * 2 bash /var/cts/cronjob/cts_backup_job.sh >> /var/cts/log/cts_backup_job.log
# CTS >> archive parttion at 1:00 AM on SUN weekly
0 1 * * 7 bash /var/cts/cronjob/cts_archive_job.sh >> /var/cts/log/cts_archive_job.log
