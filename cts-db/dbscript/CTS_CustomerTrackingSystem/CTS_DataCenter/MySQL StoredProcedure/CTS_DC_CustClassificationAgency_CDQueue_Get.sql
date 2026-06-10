/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_CDQueue_Get`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_CDQueue_Get`(		
		IN ip_BatchSize INT 
	,	OUT op_LastID BIGINT
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250725@Winfred.Pham
		Task:	 Get Agent cust List and scan Type from Customer Considerable Danger Queue    
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250725@Winfred.Pham: 	Created [Redmine ID: #219679]
                
		Param's Explanation :
        
		Example:
			CALL CTS_DC_CustClassificationAgency_CDQueue_Get(100,@op_LastID);
	*/
    DECLARE	CONST_AGENCY_CATEID_CD_LOW INT DEFAULT 130100;
    DECLARE lv_MaxScanQueueID	BIGINT UNSIGNED DEFAULT 0;

    SELECT sys.ParameterValue
    INTO lv_MaxScanQueueID
    FROM CTS_DataCenter.SystemParameter AS sys
    WHERE ParameterID = 192;  

    DROP TEMPORARY TABLE IF EXISTS Temp_AgentQueue;
    CREATE TEMPORARY TABLE Temp_AgentQueue(
			ID 			BIGINT 
		,	CustID		BIGINT
		,	ScanType	TINYINT 
		,	INDEX	IX_Temp_AgentQueue_CustID(CustID)   
    ); 
            
	INSERT IGNORE INTO Temp_AgentQueue (ID, CustID, ScanType) 
	SELECT ID, CustID, ScanType 
	FROM CTS_DataCenter.CustomerConsiderableDangerQueue
	WHERE ID <= lv_MaxScanQueueID
	ORDER BY ID
	LIMIT ip_BatchSize;   

	SELECT MAX(ID)
    INTO op_LastID
    FROM Temp_AgentQueue AS tAq;

    IF op_LastID IS NULL THEN
        SET op_LastID = 0;
    END IF;

	SELECT DISTINCT tAq.CustID, cus.CTSCustID, cus.RoleID, cus.SubscriberID, CONST_AGENCY_CATEID_CD_LOW AS CategoryID, cus.IsLicensee, clss.ScanType AS ScanType
    FROM Temp_AgentQueue AS tAq
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tAq.CustID
		,   LATERAL (
            SELECT cdq.CustID, MIN(cdq.ScanType) AS ScanType
            FROM CTS_DataCenter.CustomerConsiderableDangerQueue AS cdq
            WHERE cdq.CustID = tAq.CustID AND cdq.ID <= lv_MaxScanQueueID
            GROUP BY cdq.CustID
			HAVING MIN(cdq.ScanType) = 1
        ) AS clss
	WHERE cus.RoleID = 2 AND cus.CustSubID = 0 AND cus.IsLicensee = 0;
		
	SELECT DISTINCT tAq.CustID, cus.CTSCustID, cus.RoleID, cus.SubscriberID, CONST_AGENCY_CATEID_CD_LOW AS CategoryID, cus.IsLicensee, clss.ScanType AS ScanType
    FROM Temp_AgentQueue AS tAq
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tAq.CustID
		,   LATERAL (
            SELECT cdq.CustID, MIN(cdq.ScanType) AS ScanType
            FROM CTS_DataCenter.CustomerConsiderableDangerQueue AS cdq
            WHERE cdq.CustID = tAq.CustID AND cdq.ID <= lv_MaxScanQueueID
            GROUP BY cdq.CustID
			HAVING MIN(cdq.ScanType) = 2
        ) AS clss
	WHERE cus.RoleID = 2 AND cus.CustSubID = 0 AND cus.IsLicensee = 0;

END$$
DELIMITER ;