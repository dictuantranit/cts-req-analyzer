/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_History_Archive_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_History_Archive_Complete`(
		IN 	ip_MaxArchiveID 	BIGINT UNSIGNED
	,	IN 	ip_ListArchiveID    LONGTEXT
)
    SQL SECURITY INVOKER
sp:BEGIN 
	/*
		Created:	20250725@Winfred.Pham	
		Task :		Clean-up Classification Agency History are not used. Only take 180 lastest days.
		DB:			CTS_DataCenter
		Original:
		
		Revisions:	
				- 20250725@Winfred.Pham: 	Created [Redmine ID: #219679]
            
		Param's Explanation (filtered by):

		Example:
			CALL CTS_DC_CustClassificationAgency_History_Archive_Complete(122, '1,2,3,4,5,6,9,10,11,12');
	*/

	DROP TEMPORARY TABLE IF EXISTS Temp_ArchiveHistory;
    CREATE TEMPORARY TABLE Temp_ArchiveHistory(
			ID	BIGINT UNSIGNED PRIMARY KEY
    ); 

	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_ArchiveHistory (ID) VALUES ('", REPLACE(ip_ListArchiveID, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1; 		     
			
	DELETE his  
	FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS his
		INNER JOIN Temp_ArchiveHistory AS arc ON arc.ID = his.ID
	;
	
	UPDATE CTS_DataCenter.SystemParameter
	SET ParameterValue = ip_MaxArchiveID
	WHERE ParameterID = 193;

END$$
DELIMITER ;