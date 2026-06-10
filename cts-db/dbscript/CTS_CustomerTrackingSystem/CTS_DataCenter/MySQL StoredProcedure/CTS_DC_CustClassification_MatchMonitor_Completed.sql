/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_MatchMonitor_Completed`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_MatchMonitor_Completed`(
		IN ip_MatchID			INT
    ,	IN ip_MMDetailsIDList	TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220627@Casey.Huynh	
		Task :		Get CTSCustomer Category
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20220627@Casey.Huynh [Redmine ID: #174218]: Created 
            
		Param's Explanation:
        
		Example:
			CALL CTS_DataCenter.CTS_DC_CustClassification_MatchMonitor_Classify();
	 */ 
	DROP TEMPORARY TABLE IF EXISTS Temp_MMDetailsID;    
	CREATE TEMPORARY TABLE Temp_MMDetailsID(	  
			 MMDetailsID	BIGINT UNSIGNED PRIMARY KEY 
     );
     
	#====GET MatchMonitorDetails.ID Completed===============
    IF ip_MMDetailsIDList IS NOT NULL THEN    
		SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_MMDetailsID (MMDetailsID) VALUES ('", REPLACE(ip_MMDetailsIDList, ",", "'),('"),"');");
		PREPARE 	stmt1 FROM @sql;
		EXECUTE 	stmt1;   
        
        UPDATE CTS_DataCenter.MatchMonitorDetails AS mmd
		INNER JOIN Temp_MMDetailsID AS tmp ON mmd.ID = tmp.MMDetailsID
		SET mmd.ClassifyStatus = 1; # Completed
	ELSE
		UPDATE CTS_DataCenter.MatchMonitor AS mm
		SET mm.ClassifyStatus = 1
		WHERE mm.MatchID = ip_MatchID;
        
        UPDATE CTS_DataCenter.SystemParameter AS s
        SET s.ParameterValue = 0
        WHERE s.ParameterID = 96;   
	END IF;    
END$$
DELIMITER ;