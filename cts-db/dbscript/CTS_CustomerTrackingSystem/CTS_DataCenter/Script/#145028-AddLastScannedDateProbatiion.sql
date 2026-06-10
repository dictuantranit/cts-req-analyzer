/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2"></info>*/
# [20201016@Irena.Vo][145028]: Add LastScannedDate column
ALTER TABLE CTS_DataCenter.ProbationAccountMonitor
ADD COLUMN LastScannedDate DATE,
ADD INDEX IX_ProbationAccountMonitor_LastScannedDate(LastScannedDate);