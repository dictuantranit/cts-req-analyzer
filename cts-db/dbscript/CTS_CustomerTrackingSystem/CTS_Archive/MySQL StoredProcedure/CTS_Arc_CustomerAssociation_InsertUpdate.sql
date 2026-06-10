/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsServiceAdmin,ctsWebAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_Arc_CustomerAssociation_InsertUpdate`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_Arc_CustomerAssociation_InsertUpdate`(
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
			- 20211026@Aries.Nguyen: Created [Redmine ID: #163087]         
			- 20230207@Long.Luu: Get exact lastticketdate [Redmine ID: #183281]
            - 20240927@Casey.Huynh: Insert New Agent to CTSCustomerAssociationStatus [Redmine ID: #185799]
        Param's Explanation (filtered by):
        
        Example:
			- CALL CTS_Arc_CustomerAssociation_InsertUpdate('[
						{"CTSCustID": 1,"CustID": 11, "RoleID:4"}
					,	{"CTSCustID": 2,"CustID": 12, "RoleID:3"}
					,	{"CTSCustID": 3,"CustID": 13, "RoleID:2"}
                    , 	{"CTSCustID": 4,"CustID": 14, "RoleID:1"}]');
	*/   
    DECLARE	CONST_ROLEID_MEMBER TINYINT DEFAULT 1;
    DECLARE	CONST_ROLEID_AGENT TINYINT DEFAULT 2;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;    
	CREATE TEMPORARY TABLE Temp_Cust( 	  
			CTSCustID 	BIGINT UNSIGNED	
		,	CustID		BIGINT UNSIGNED
        ,	RoleID		TINYINT
        
        ,	PRIMARY	KEY (CTSCustID)
	);
    
	INSERT IGNORE INTO Temp_Cust(CTSCustID, CustID, RoleID)
	SELECT	info.CTSCustID
		, 	info.CustID
        ,	info.RoleID
	FROM JSON_TABLE(ip_CustInfo,
		 "$[*]" COLUMNS(
				CTSCustID	BIGINT UNSIGNED	PATH "$.CTSCustID" 
			, 	CustID		BIGINT UNSIGNED	PATH "$.CustID" 
			, 	CustSubID	BIGINT UNSIGNED	PATH "$.CustSubID" 
			, 	RoleID		TINYINT			PATH "$.RoleID" )
	) AS info
	WHERE info.RoleID IN (CONST_ROLEID_MEMBER,CONST_ROLEID_AGENT) AND info.CustSubID = 0;
    
	INSERT INTO CTS_Archive.CTSCustomerAssociationStatus(CTSCustID, CustID, LastTicketDate)
	SELECT	tmp.CTSCustID
		,	tmp.CustID
		,	NULL
	FROM Temp_Cust AS tmp
	WHERE NOT EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationStatus AS arc  WHERE arc.CTSCustID = tmp.CTSCustID);
    
END$$
DELIMITER ;
