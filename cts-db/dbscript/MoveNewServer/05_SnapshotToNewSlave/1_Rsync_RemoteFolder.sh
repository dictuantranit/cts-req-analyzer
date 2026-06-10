#remote rsync
cd /dev/mapper/volumes/cts_master_mysql80
rsync -rvh --progress data/ vnteam@10.40.40.185:/volumes/cts_master_mysql80/data/