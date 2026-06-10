/*
	Created: 20200706@Long.Luu
	Task: Job to Count Associated Account New Association
	DB: CTS_DataCenter
  
	Revisions:
		- 20200706@Long.Luu: created  [Redmine ID: #134652]

	Param's Explanation:
*/

DELIMITER @@;
# DROP EVENT IF EXISTS CTS_DataCenter.CTS_DC_JOB_CountAssociatedAccountNewAssociation;
CREATE EVENT CTS_DataCenter.CTS_DC_JOB_CountAssociatedAccountNewAssociation
	ON SCHEDULE
		EVERY 5 MINUTE
		STARTS '2020-07-07 07:00:00' ON COMPLETION PRESERVE ENABLE 
	DO BEGIN
		CALL CTS_DC_Task_CountAssociatedAccountNewAssociation();
	END;
    @@;
DELIMITER;