#RUN on master server
use mysql;
CREATE USER 'repl_sql'@'%' IDENTIFIED BY 'password';
GRANT REPLICATION SLAVE ON *.* TO 'repl_sql'@'%';
FLUSH PRIVILEGES;