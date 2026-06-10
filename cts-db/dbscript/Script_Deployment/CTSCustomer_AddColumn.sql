/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2"></info>*/
USE CTS_DataCenter;
ALTER TABLE CTS_DataCenter.CTSCustomer ADD COLUMN InsertedTime DATETIME(4) COMMENT "When row inserted", ALGORITHM=INSTANT;
ALTER TABLE CTS_DataCenter.CTSCustomer ADD COLUMN ModifiedTime DATETIME(4) COMMENT "When row modified", ALGORITHM=INSTANT;










