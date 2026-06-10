/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsServiceAdmin,ctsWebAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_Arc_CustomerAssociation_RollBack_CheckByCustStatus`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_Arc_CustomerAssociation_RollBack_CheckByCustStatus`(
	IN ip_CustInfo 	JSON
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
            
        Param's Explanation (filtered by):

        Example:  
			- CALL CTS_Arc_CustomerAssociation_RollBack_CheckByCustStatus('[{"CustID": 1,"CustStatusID": 2}]');
*/   
	DECLARE	CONST_30Days	INT DEFAULT 30; 

	DECLARE lv_DateValid	DATETIME DEFAULT DATE_SUB(NOW(), INTERVAL CONST_30Days DAY); 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;    
	CREATE TEMPORARY TABLE Temp_Cust( 	  
			CustID 			BIGINT UNSIGNED	
		,	CustStatusID	SMALLINT
        ,	PRIMARY	KEY (CustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustRollBack;    
	CREATE TEMPORARY TABLE Temp_CustRollBack( 	  
			CTSCustID 		BIGINT UNSIGNED
        ,	PRIMARY	KEY (CTSCustID)
	);

    
	INSERT IGNORE INTO Temp_Cust(CustID, CustStatusID)
	SELECT	info.CustID
		, 	info.CustStatusID
	FROM JSON_TABLE(ip_CustInfo,
		 "$[*]" COLUMNS(
				CustID			BIGINT UNSIGNED	PATH "$.CustID" 
			, 	CustStatusID	SMALLINT		PATH "$.CustStatusID"  )
	) AS info;
    
	DELETE 
    FROM Temp_Cust
    WHERE CustStatusID NOT IN (1,11);
    
    INSERT INTO Temp_CustRollBack(CTSCustID)
    SELECT cus.CTSCustID
    FROM CTS_Archive.CTSCustomerAssociationStatus AS cus
    WHERE cus.IsArchived = 1 
		AND cus.LastTicketDate > lv_DateValid
        AND EXISTS (SELECT 1 FROM Temp_Cust AS tmp WHERE tmp.CustID = cus.CustID);
    
    DELETE
    FROM  CTS_Archive.CTSCustomerAssociationArchive_Process AS pro
    WHERE  EXISTS (SELECT 1 FROM Temp_CustRollBack AS tmp WHERE tmp.CTSCustID = pro.CTSCustID);
    
    UPDATE CTS_Archive.CTSCustomerAssociationStatus AS cus
    SET 	cus.IsRollBack = 1 
		,	cus.RollBackDate = NOW()  
		,	cus.IsArchived = 0     
	WHERE EXISTS (SELECT 1 FROM Temp_CustRollBack AS tmp WHERE tmp.CTSCustID = cus.CTSCustID);
    
END$$
DELIMITER ;