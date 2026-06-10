/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsServiceAdmin,ctsWebAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_Arc_CustomerAssociation_LastTicketDate_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_Arc_CustomerAssociation_LastTicketDate_Update`(
		IN ip_CustInfo 		JSON
)
    SQL SECURITY INVOKER
BEGIN
/*
		Created:	20211026@Aries.Nguyen
		Task:		Archive Inactive Association
		DB:			CTS_Archive
		Original:
		Revisions:
			- 20211026@Aries.Nguyen [Redmine ID: #163087]: Created
            - 20230425@Jonas.Huynh	[Redmine ID: #186678]: Normal Classification Renovation
            - 20240805@Jonas.Huynh	[RedmineID: #205317]: Renovate CC 
            
        Param's Explanation (filtered by):

        Example: 
			- CALL CTS_Arc_CustomerAssociation_LastTicketDate_Update('[{"CustId":7681925, "LastTicketDate": '2023-04-25 00:00:00'}]');
*/   
	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;    
	CREATE TEMPORARY TABLE Temp_Cust( 	  
			CustID			INT UNSIGNED
		,	LastTicketDate	DATETIME NOT NULL
        ,	PRIMARY	KEY (CustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustArchived;    
	CREATE TEMPORARY TABLE Temp_CustArchived( 	  
			CTSCustID 		BIGINT 	 UNSIGNED
		,	CustID			INT 	 UNSIGNED
        ,	PRIMARY	KEY (CTSCustID)
	);
	   
    INSERT INTO Temp_Cust(CustID, LastTicketDate)
	SELECT 	temp.CustID, temp.LastTicketDate
	FROM JSON_TABLE(ip_CustInfo,
		 "$[*]" COLUMNS(
			CustID 				BIGINT UNSIGNED		PATH "$.CustId",
            LastTicketDate 		DATETIME 			PATH "$.LastTicketDate"
		 )) AS temp;       
         
         
    INSERT INTO Temp_CustArchived(CTSCustID, CustID)
    SELECT 	cus.CTSCustID
		,	cus.CustID
    FROM CTS_Archive.CTSCustomerAssociationStatus AS cus
    WHERE cus.IsArchived = 1 
		AND EXISTS (SELECT 1 FROM Temp_Cust AS tmp WHERE tmp.CustID = cus.CustID);
        
    DELETE 
    FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro
    WHERE EXISTS (SELECT 1 FROM Temp_CustArchived AS tmp WHERE tmp.CTSCustID = pro.CTSCustID);
    
    UPDATE CTS_Archive.CTSCustomerAssociationStatus AS cus
    SET 	cus.IsRollBack = 1
        ,	cus.RollBackDate = NOW()
        ,	cus.IsArchived = 0
    WHERE EXISTS (SELECT 1 FROM Temp_CustArchived AS arc WHERE arc.CTSCustID = cus.CTSCustID);

    UPDATE CTS_Archive.CTSCustomerAssociationStatus AS cus
		INNER JOIN Temp_Cust AS tmp ON tmp.CustID = cus.CustID
    SET cus.LastTicketDate = tmp.LastTicketDate
    WHERE cus.LastTicketDate < tmp.LastTicketDate
		OR cus.LastTicketDate IS NULL;
    
END$$
DELIMITER ;