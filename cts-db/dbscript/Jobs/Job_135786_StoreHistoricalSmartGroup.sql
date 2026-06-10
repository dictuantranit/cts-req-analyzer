/*
	Created: 20200630@Long.Luu
	Task: Job to daily store the SmartGroup into SmartGroupHistory table
	DB: CTS_DataCenter
  
	Revisions:
		- 20200630@Long.Luu: created  [Redmine ID: #135786]

	Param's Explanation:  
	
*/

DELIMITER @@;

CREATE EVENT CTS_DataCenter.CTS_JOB_StoreSmartGroupHistory
	ON SCHEDULE
		EVERY 1 DAY
		STARTS '2020-06-30 04:00:00' ON COMPLETION PRESERVE ENABLE 
	DO BEGIN
		DECLARE CutOffDate		DATE;
		SET	CutOffDate = ADDDATE(DATE_FORMAT(CURRENT_DATE(), '%Y-%m-%d'), INTERVAL -14 DAY);
		
		DELETE FROM CTS_DataCenter.SmartGroupHistory
		WHERE CreatedDate < CutOffDate;
		
		SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;        
		INSERT INTO CTS_DataCenter.SmartGroupHistory(GroupID, CustID, Username, Similarity, Currency, Site, AgentID, AgentName, MasterID, MasterName, SuperID, SuperName, CreatedDate)
		SELECT GroupID, CustID, Username, Similarity, Currency, Site, AgentID, AgentName, MasterID, MasterName, SuperID, SuperName, CURRENT_DATE()
		FROM CTS_DataCenter.SmartGroup;
	END;
    @@;
DELIMITER ;

        
        
        
        
