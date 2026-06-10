/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_ArchiveCustomer`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_ArchiveCustomer`(
		IN ip_CustomerList  JSON
	,	IN ip_CustType      TINYINT
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20210804@Casey.Huynh
		Task :		Archive Customer
		DB:			CTS_DataCenter, DCS_DataCenter
		Original:

		Revisions:
			- 	20210804@Casey.Huynh: Created [Redmine ID: #152883]
			-	20210719@Casey.Huynh: Fix Issue Rule Trans.StepTime and AssGroup [Redmine ID: #158946]
            -	20210929@Aries.Nguyen: Enhance performance [Redmine ID: #162277]
            -	20250905@Thomas.Nguyen: Enhance flow for Reactivating Customer [Redmine ID: #237406]
            -	20251003@Thomas.Nguyen: Enhance flow for Reactivating Customer - Phase 2 [Redmine ID: #240593]
            
		Param's Explanation (filtered by):	

		Example:
            CALL CTS_DataCenter.CTS_DC_ArchiveCustomer('[{"CustID":98456422,"ArchivedDate":"2023-10-05 03:23:36.293"}]', 0);
			
	*/
    DECLARE lv_MaxArchiveTime 	DATETIME(3);
    DECLARE lv_MaxCustID 		INT UNSIGNED;
    DECLARE lv_MinArchiveDate 	DATETIME(3);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_InputCustomer;
    CREATE TEMPORARY TABLE Temp_InputCustomer(
			CustID			INT UNSIGNED
        ,	ArchivedDate	DATETIME(3)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ArchiveCustDCSAccount;
    CREATE TEMPORARY TABLE Temp_ArchiveCustDCSAccount(		
			AccountID BIGINT UNSIGNED
        ,	CTSCustID BIGINT UNSIGNED
    ); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ArchiveCTSCustomer;
    CREATE TEMPORARY TABLE Temp_ArchiveCTSCustomer(		
        	ArchivedDate	DATETIME(3)
		,	CTSCustID		BIGINT UNSIGNED
		, 	CustID			BIGINT UNSIGNED
        , 	AccountID		BIGINT UNSIGNED
        ,	CustSubID		BIGINT UNSIGNED
        ,	UserName		VARCHAR(50)
        ,	UserName2		VARCHAR(50)
        ,	SubscriberID	INT
        ,	RoleID			TINYINT
        
        ,	PRIMARY KEY Temp_ArchiveCustomer(CTSCustID, ArchivedDate)
        ,	INDEX Temp_ArchiveCustomer(CustID, CustSubID)
    ); 	

	/***********************GET ARCHIVE DATA TO TEMPTABLE*************************************************************/
    INSERT INTO Temp_InputCustomer(CustID, ArchivedDate)
	SELECT		CustID	
			,	ArchivedDate
	FROM JSON_TABLE(ip_CustomerList,
		 "$[*]" COLUMNS(
						CustID			INT	 UNSIGNED		PATH "$.CustID" 
					,	ArchivedDate	DATETIME(3)			PATH "$.ArchivedDate"
				)
	) AS js;
    
    INSERT INTO Temp_ArchiveCTSCustomer(ArchivedDate, CTSCustID, CustID, CustSubID, UserName, UserName2, SubscriberID, RoleID)
    SELECT tmpCus.ArchivedDate
		,	cus.CTSCustID
        ,	cus.CustID
        ,	cus.CustSubID
        ,	cus.UserName
        ,	cus.UserName2
        ,	cus.SubscriberID
        ,	cus.RoleID
    FROM Temp_InputCustomer AS tmpCus
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpCus.CustID = cus.CustID;
        
    INSERT IGNORE INTO Temp_ArchiveCustDCSAccount(AccountID, CTSCustID)
    SELECT 	ac.AccountID
        ,	cus.CTSCustID		
	FROM	Temp_ArchiveCTSCustomer AS cus
		INNER JOIN CTS_DataCenter.CustDCSAccount AS ac ON cus.CTSCustID = ac.CTSCustID;
   
   UPDATE Temp_ArchiveCTSCustomer AS cust
   INNER JOIN Temp_ArchiveCustDCSAccount AS ac ON ac.CTSCustID = cust.CTSCustID
   SET cust.AccountID =  ac.AccountID;
   
    INSERT IGNORE INTO CTS_DataCenter.ArchiveCustomer_CTSCustomer(ArchivedDate, CTSCustID, AccountID, SubscriberID, CustID, CustSubID, UserName, UserName2, RoleID, InsertTime, IsReactivated, ReactivateDate, ProcessedDate)
    SELECT	cus.ArchivedDate
		,	cus.CTSCustID
        ,	cus.AccountID
        ,	cus.SubscriberID
        ,	cus.CustID
        ,	cus.CustSubID
        ,	cus.UserName
        ,	cus.UserName2
        ,	cus.RoleID
        ,	CURRENT_TIMESTAMP(3)
        ,	CASE WHEN arc.CustID IS NOT NULL THEN 1 ELSE 0 END AS IsReactivated
        ,	CASE WHEN arc.CustID IS NOT NULL THEN arc.ReactivateDate ELSE NULL END AS ReactivateDate
        ,	CASE WHEN arc.CustID IS NOT NULL THEN arc.ReactivateDate ELSE NULL END AS ProcessedDate
    FROM Temp_ArchiveCTSCustomer AS cus
        LEFT JOIN LATERAL (
                SELECT ar.CustID, ar.ReactivateDate
                FROM CTS_DataCenter.ArchiveCustomer_CTSCustomer AS ar
                WHERE ar.CustID = cus.CustID AND ar.IsReactivated = 1 AND ar.ReactivateDate > cus.ArchivedDate
                ORDER BY ar.ID DESC
                LIMIT 1) AS arc ON TRUE;
	
    IF EXISTS(SELECT 1 FROM  Temp_InputCustomer)
    THEN
		SELECT MAX(ArchivedDate) 
		INTO lv_MaxArchiveTime
		FROM Temp_InputCustomer;
        
		SELECT MAX(CustID) 
		INTO lv_MaxCustID
		FROM Temp_InputCustomer
		WHERE ArchivedDate = lv_MaxArchiveTime;
		
        IF (ip_CustType = 0) THEN
			UPDATE CTS_DataCenter.SystemParameter
			SET ParameterValue = lv_MaxArchiveTime
			WHERE ParameterID = 24;
			
			UPDATE CTS_DataCenter.SystemParameter
			SET ParameterValue = lv_MaxCustID
			WHERE ParameterID = 25;
		END IF;
        
        IF (ip_CustType = 1) THEN
			UPDATE CTS_DataCenter.SystemParameter
			SET ParameterValue = lv_MaxArchiveTime
			WHERE ParameterID = 26;
			
			UPDATE CTS_DataCenter.SystemParameter
			SET ParameterValue = lv_MaxCustID
			WHERE ParameterID = 27;
		END IF;
    END IF;
END$$
DELIMITER ;

