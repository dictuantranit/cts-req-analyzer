/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2"></info>*/
# [20220207@Harvey.Nguyen][168091]: Add new table and  system parameter
INSERT INTO `CTS_DataCenter`.`SystemParameter` (`ParameterID`, `ParameterName`, `ParameterDesc`, `ParameterDataType`, `ParameterValue`) VALUES ('68', 'MonitorNeo4jCustomer_LastScannedCTSCustID', 'MonitorNeo4jCustomer_LastScannedCTSCustID', 'BIGINT', '0');
CREATE TABLE `CTS_Log`.`Monitor_Neo4j_CTSCustomer_Missing` (
  `CTSCustID` INT NOT NULL,
  `ScannedDate` DATETIME NULL,
  `IsResolved` BIT NULL,
  PRIMARY KEY (`CTSCustID`));
