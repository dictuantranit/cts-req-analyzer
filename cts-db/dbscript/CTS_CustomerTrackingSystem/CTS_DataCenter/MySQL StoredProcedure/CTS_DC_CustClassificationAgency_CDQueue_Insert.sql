/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_CDQueue_Insert`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_CDQueue_Insert`(		
		IN 	ip_ScanType 	TINYINT
    ,	IN 	ip_Cust		        LONGTEXT
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250725@Winfred.Pham
		Task:	 	Insert Customer into Latency Queue for Customer Latency Insert
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250725@Winfred.Pham: 	Created [Redmine ID: #219679]
                
		Param's Explanation (filtered by): 
			@ip_ScanType: '1: Total Member Change , 2: Only Scan WL, PA Member change'
        
		Example:
			CALL CTS_DC_CustClassificationAgency_CDQueue_Insert(@ip_ScanType:=1, @ip_Cust:='1,2,3,4,5,6,9,10,11,12]');
            CALL CTS_DC_CustClassificationAgency_CDQueue_Insert(@ip_ScanType:=2, @ip_Cust:='1,2,3,4,5,6,9,10,11,12]');
	*/
    DECLARE lv_MinQueueID	BIGINT UNSIGNED DEFAULT 0;

    SELECT sys.ParameterValue
    INTO lv_MinQueueID
    FROM CTS_DataCenter.SystemParameter AS sys
    WHERE ParameterID = 192;  

    DROP TEMPORARY TABLE IF EXISTS Temp_AgentCredit;
    CREATE TEMPORARY TABLE Temp_AgentCredit(
			CustID	BIGINT UNSIGNED PRIMARY KEY
    ); 
    
	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_AgentCredit (CustID) VALUES ('", REPLACE(ip_Cust, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1; 	

	INSERT IGNORE INTO CTS_DataCenter.CustomerConsiderableDangerQueue(CustID, ScanType, InsertedTime)
    SELECT DISTINCT js.CustID
		,	ip_ScanType	
		,	CURRENT_TIMESTAMP(3) AS InsertedTime
	FROM Temp_AgentCredit AS js 
     WHERE NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CustomerConsiderableDangerQueue AS clss WHERE clss.ID > lv_MinQueueID AND clss.CustID = js.CustID AND clss.ScanType = ip_ScanType)
	   AND js.CustID IS NOT NULL
	   AND js.CustID > 0;

END$$
DELIMITER ;