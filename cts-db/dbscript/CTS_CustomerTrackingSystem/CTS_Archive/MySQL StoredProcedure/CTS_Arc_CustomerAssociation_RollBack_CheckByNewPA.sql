/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsServiceAdmin,ctsWebAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_Arc_CustomerAssociation_RollBack_CheckByNewPA`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_Arc_CustomerAssociation_RollBack_CheckByNewPA`(
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
			- 20220301@Aries.Nguyen: Change datatype of the CustID column [Redmine ID: #169264]
            
        Param's Explanation (filtered by):

        Example: 
			- CALL CTS_Arc_CustomerAssociation_RollBack_CheckByNewPA('[{"CTSCustID":1, "CustID": 1}]');
*/   
	DECLARE	CONST_90Days	INT DEFAULT 90; 

	DECLARE lv_DateValid	DATETIME DEFAULT DATE_SUB(NOW(), INTERVAL CONST_90Days DAY); 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;    
	CREATE TEMPORARY TABLE Temp_Cust( 	  
			CTSCustID 	BIGINT UNSIGNED	
		,	CustID		BIGINT UNSIGNED	
        ,	PRIMARY	KEY (CustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustRollBack;    
	CREATE TEMPORARY TABLE Temp_CustRollBack( 	  
			CTSCustID 		BIGINT UNSIGNED
        ,	PRIMARY	KEY (CTSCustID)
	);

    
	INSERT IGNORE INTO Temp_Cust(CTSCustID, CustID)
	SELECT	info.CTSCustID
		, 	info.CustID
	FROM JSON_TABLE(ip_CustInfo,
		 "$[*]" COLUMNS(
				CTSCustID	BIGINT UNSIGNED	PATH "$.CTSCustID" 
			, 	CustID		BIGINT UNSIGNED	PATH "$.CustID"  )
	) AS info;
    
    INSERT INTO Temp_CustRollBack(CTSCustID)
    SELECT cus.CTSCustID
    FROM CTS_Archive.CTSCustomerAssociationStatus AS cus
    WHERE cus.IsArchived = 1 
		AND cus.LastTicketDate > lv_DateValid
        AND EXISTS (SELECT 1 FROM Temp_Cust AS tmp WHERE tmp.CTSCustID = cus.CTSCustID);
    
    DELETE
    FROM  CTS_Archive.CTSCustomerAssociationArchive_Process AS pro
    WHERE  EXISTS (SELECT 1 FROM Temp_CustRollBack AS tmp WHERE tmp.CTSCustID = pro.CTSCustID);
    
    UPDATE CTS_Archive.CTSCustomerAssociationStatus AS cust
    SET 	cust.IsRollBack = 1
		,	cust.RollBackDate = NOW()
		,	cust.IsArchived = 0
	WHERE EXISTS (SELECT 1 FROM Temp_CustRollBack AS tmp WHERE tmp.CTSCustID = cust.CTSCustID);
    
    
END$$
DELIMITER ;