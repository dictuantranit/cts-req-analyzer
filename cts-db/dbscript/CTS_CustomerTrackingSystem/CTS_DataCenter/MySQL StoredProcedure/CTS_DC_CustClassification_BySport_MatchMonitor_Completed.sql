/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_MatchMonitor_Completed`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_MatchMonitor_Completed`(
		IN ip_MatchID			INT
    ,	IN ip_MMDetailsIDList	TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20251113@Winfred.pham	
		Task :		Get CTSCustomer Category by sport
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20251113@Winfred.pham : Created [Redmine ID: #239955]
            
		Param's Explanation:
        
		Example:
			CALL CTS_DataCenter.CTS_DC_CustClassification_BySport_MatchMonitor_Completed();
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
		SET mmd.ClassifyStatusBySport = 1; # Completed
	ELSE
		UPDATE CTS_DataCenter.MatchMonitor AS mm
		SET mm.ClassifyStatusBySport = 1
		WHERE mm.MatchID = ip_MatchID;
        
        UPDATE CTS_DataCenter.SystemParameter AS s
        SET s.ParameterValue = 0
        WHERE s.ParameterID = 199;   
	END IF;    
END$$
DELIMITER ;