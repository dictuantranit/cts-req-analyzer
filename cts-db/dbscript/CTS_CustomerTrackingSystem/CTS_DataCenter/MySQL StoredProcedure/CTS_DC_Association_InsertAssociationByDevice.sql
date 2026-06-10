/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_InsertAssociationByDevice`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_InsertAssociationByDevice`(
    IN ip_AssociationList JSON
)
    SQL SECURITY INVOKER
BEGIN
/*
		Created:	20191115@Terry.Nguyen
		Task:		Transform Association By Device from DCS.Assocation
		DB:			CTS_DataCenter
		Original:

		Revisions:
            - 20200506@CaseyHuynh: Retry Transform If > -4 [RedmineID: #133486]
            - 20200518@CaseyHuynh: Remove  code update IsCTSTransformed = -2 ELSE -1 [RedmineID: #133486]
            - 20201018@CaseyHuynh: LOG INSSUE
		    - 20200518@CaseyHuynh: Remove Log Issue
            - 20201112@CaseyHuynh: GET Lastest Code Move Server P3, update Permission and Add Meta data. Change Log table to DB Log. Enhance  Transform Retry [RedmineID: #145271]
            - 20201130@CaseyHuynh: add more condition when update Association.IsCTSTransformed = -1."WHEN asd.CTSCustID IS NULL AND  tmp_ass.CTSCustID IS NULL THEN -1 END)"
            - 20210510@Aries.Nguyen: Remove insert log dba_SP_PerformanceStats [Redmine ID: #154792]
            - 20210622@Aries.Nguyen: Update coding convention and improve locking [Redmine ID: #157203]
			- 20211026@Aries.Nguyen: Archive inactive association [Redmine ID: #163087]

		Param's Explanation (filtered by):
                
	*/    

    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
	CREATE TEMPORARY TABLE Temp_Association (	
			AssociationID		BIGINT	UNSIGNED
		,	AccountID			BIGINT	UNSIGNED
        ,	DeviceID			BIGINT	UNSIGNED
        ,	SubscriberID		INT
        ,	CreatedTime			TIMESTAMP(4)
        ,	CTSCustID			BIGINT	UNSIGNED
    ); 

	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustID;
	CREATE TEMPORARY TABLE Temp_CTSCustID (	
			AccountID	BIGINT	UNSIGNED
        ,	CTSCustID	BIGINT	UNSIGNED
		,	INDEX		IX_Temp_CustID_AccountID(AccountID)		
    ); 

	DROP TEMPORARY TABLE IF EXISTS Temp_Transformed;
	CREATE TEMPORARY TABLE Temp_Transformed (	
			AccountID			BIGINT	UNSIGNED
        ,	DeviceID			BIGINT	UNSIGNED
		,	IsCTSTransformed	TINYINT
		,	INDEX				IX_Temp_CustID_AccountID(AccountID)		
    ); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustArchived;
	CREATE TEMPORARY TABLE Temp_CustArchived (	
        CTSCustID			BIGINT	UNSIGNED PRIMARY KEY
    );
	
    INSERT INTO Temp_Association (AssociationID, AccountID, DeviceID, SubscriberID, CreatedTime)                
	SELECT 	tmpTable.AssociationID
		,	tmpTable.AccountID
		,	tmpTable.DeviceID
		,	tmpTable.SubscriberID
        ,   tmpTable.CreatedTime
	FROM JSON_TABLE(ip_AssociationList,
		 "$[*]" COLUMNS(
			  AssociationID 			BIGINT 			PATH "$.AssociationId"
			, AccountID 				BIGINT 			PATH "$.AccountId"
			, DeviceID					BIGINT			PATH "$.DeviceId" 
			, SubscriberID				INT				PATH "$.SubscriberId"
            , CreatedTime				TIMESTAMP(4)	PATH "$.CreatedTime"
		 )) as tmpTable;  
       
    #=========GET CTSCustID IF Existing  
	INSERT INTO Temp_CTSCustID(AccountID, CTSCustID)
	SELECT	ass.AccountID
		,	cus.CTSCustID
	FROM Temp_Association AS ass
		INNER JOIN	CTS_DataCenter.CustDCSAccount AS cus  ON ass.AccountID = cus.AccountID;

    UPDATE Temp_Association AS ass
		INNER JOIN	Temp_CTSCustID AS cus  ON ass.AccountID = cus.AccountID
	SET ass.CTSCustID = cus.CTSCustID;
   
    #=======IF CTSCustID Existing 
    INSERT IGNORE INTO Temp_CustArchived(CTSCustID)
    SELECT cus.CTSCustID
    FROM CTS_Archive.CTSCustomerAssociationStatus AS cus
    WHERE EXISTS (SELECT 1 FROM Temp_Association AS tmp WHERE tmp.CTSCustID =  cus.CTSCustID AND cus.IsArchived = 1);
    
	INSERT IGNORE INTO 	CTS_DataCenter.AssociationByDevice(CTSCustID, DCSDeviceID, SubscriberID, CreatedTime, InsertTime)
	SELECT	tmp_ass.CTSCustID 
		,	tmp_ass.DeviceID
		,	tmp_ass.SubscriberID
		,	MIN(tmp_ass.CreatedTime)	
		,	CURRENT_TIMESTAMP()	AS InsertTime
	FROM Temp_Association 	AS tmp_ass
    WHERE tmp_ass.CTSCustID IS NOT NULL
		AND NOT EXISTS (SELECT 1 FROM Temp_CustArchived AS arc WHERE arc.CTSCustID = tmp_ass.CTSCustID)
    GROUP BY tmp_ass.CTSCustID
		,	 tmp_ass.DeviceID
		,	 tmp_ass.SubscriberID; 
        
	INSERT IGNORE INTO 	CTS_Archive.AssociationByDevice_Arc(CTSCustID, DCSDeviceID, SubscriberID, AssociationDate, Created)
	SELECT	tmp_ass.CTSCustID 
		,	tmp_ass.DeviceID
		,	tmp_ass.SubscriberID
		,	MIN(tmp_ass.CreatedTime)	
		,	CURRENT_TIMESTAMP()	AS Created
	FROM Temp_Association 	AS tmp_ass
    WHERE tmp_ass.CTSCustID IS NOT NULL
		AND EXISTS (SELECT 1 FROM Temp_CustArchived AS arc WHERE arc.CTSCustID = tmp_ass.CTSCustID)
    GROUP BY tmp_ass.CTSCustID
		,	 tmp_ass.DeviceID
		,	 tmp_ass.SubscriberID; 
	
	INSERT IGNORE INTO Temp_Transformed(AccountID, DeviceID, IsCTSTransformed)
	SELECT	tmp_ass.AccountID
		,	tmp_ass.DeviceID
		,	(CASE WHEN asd.CTSCustID IS NOT NULL THEN 1
				  WHEN asd.CTSCustID IS NULL AND  tmp_ass.CTSCustID IS NULL THEN -1 
			 END)
	FROM Temp_Association AS tmp_ass
		LEFT JOIN CTS_DataCenter.AssociationByDevice AS asd ON asd.CTSCustID = tmp_ass.CTSCustID AND asd.DCSDeviceID = tmp_ass.DeviceID
	WHERE NOT EXISTS (SELECT 1 FROM Temp_CustArchived AS arc WHERE arc.CTSCustID = tmp_ass.CTSCustID);
	
    INSERT IGNORE INTO Temp_Transformed(AccountID, DeviceID, IsCTSTransformed)
	SELECT	tmp_ass.AccountID
		,	tmp_ass.DeviceID
		,	(CASE WHEN asd.CTSCustID IS NOT NULL THEN 1
				  WHEN asd.CTSCustID IS NULL AND  tmp_ass.CTSCustID IS NULL THEN -1 
			 END)
	FROM Temp_Association AS tmp_ass
		LEFT JOIN CTS_Archive.AssociationByDevice_Arc AS asd ON asd.CTSCustID = tmp_ass.CTSCustID AND asd.DCSDeviceID = tmp_ass.DeviceID
	WHERE  EXISTS (SELECT 1 FROM Temp_CustArchived AS arc WHERE arc.CTSCustID = tmp_ass.CTSCustID);
    
    UPDATE DCS_DataCenter.Association AS ass
		INNER JOIN	Temp_Transformed AS tr ON ass.AccountID = tr.AccountID AND ass.DeviceID = tr.DeviceID
	SET ass.IsCTSTransformed = tr.IsCTSTransformed;
                         
END$$

DELIMITER ;
