use DCS_DataCenter;
# CREATE RawTransaction_New like RawTransaction with the right partition design;
ALTER TABLE RawTransaction_New DISCARD PARTITION pw202040 TABLESPACE;

use DCS_DataCenter;
FLUSH TABLE RawTransaction for export;

#cp RawTransaction#p#pw202040.ibd RawTransaction_New#p#pw202040.ibd
#cp RawTransaction#p#pw202040.cfg RawTransaction_New#p#pw202040.cfg
#chmod 660 RawTransaction_New#p#pw202040.ibd
#chmod 660 RawTransaction_New#p#pw202040.cfg
#chown mysql.mysql RawTransaction_New#p#pw202040.ibd
#chmod mysql.mysql RawTransaction_New#p#pw202040.cfg

use DCS_DataCenter;
unlock TABLEs;

use DCS_DataCenter;
ALTER TABLE RawTransaction_New IMPORT PARTITION pw202040 TABLESPACE;

use DCS_DataCenter;
DROP TABLE RawTransaction;
RENAME TABLE RawTransaction_New TO RawTransaction;

use DCS_DataCenter;
ALTER TABLE ProcessedTransaction truncate partition pw202040;

# Transaction
# CREATE Transaction_New like Transaction with UNIQUE KEY `UN_RawTransID`(`RawTransID`);
DROP TABLE `Transaction`;
RENAME TABLE Transaction_New TO `Transaction`;

# Transaction
# CREATE Transaction07_New like Transaction with adding UNIQUE KEY `UN_RawTransID`(`CreatedDate`,`RawTransID`);
DROP TABLE `Transaction07`;
RENAME TABLE Transaction07_New TO `Transaction07`;

