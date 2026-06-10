CREATE DEFINER=`fps`@`%` PROCEDURE `CTS_DC_RemoveException`(IN ip_UserID INT, IN ip_FromSubscriberID INT, IN ip_FromCTSCustID BIGINT, IN ip_ToCTSCustID BIGINT)
BEGIN
	/*
		Created:	20200123@Casey.Huynh	
		Task :		Remove Exception
		DB:			CTS_DataCenter
		Original: 
		Revisions:
		Param's Explanation (filtered by):
	*/ 
	DECLARE		vr_LeastCTSCustID 	BIGINT;
    DECLARE		vr_GreatestCTSCustID 		BIGINT;
    DECLARE		vr_CreatedDate	DATETIME;
    DECLARE		vr_SPName 	VARCHAR(100) 	DEFAULT 'CTS_DC_RemoveException';
    
    SET	vr_CreatedDate = CURRENT_TIME();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustDevice;
    CREATE TEMPORARY TABLE Temp_CustDevice
    (	CTSCustID		BIGINT
		, DCSDeviceID	BIGINT
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustAssociation;
    CREATE TEMPORARY TABLE Temp_CustAssociation
    (	FromCTSCustID		BIGINT
		, ToCTSCustID		BIGINT
	);
    
    SET vr_LeastCTSCustID = LEAST(ip_FromCTSCustID,ip_ToCTSCustID);
    SET	vr_GreatestCTSCustID = GREATEST(ip_FromCTSCustID,ip_ToCTSCustID);  

    #===Remove Exception
    DELETE	ce
    FROM	CTS_DataCenter.CustException AS ce
    WHERE	ce.LeastCTSCustID_Order 		= vr_LeastCTSCustID
			AND ce.GreatestCTSCustID_Order	= vr_GreatestCTSCustID;
    
    INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	VALUES(2,vr_SPName, CONCAT('Remove Exception: ip_FromCTSCustID_', ip_FromCTSCustID, ';ip_ToCTSCustID', ip_ToCTSCustID), vr_CreatedDate, ip_UserID);
    
    #=====Insert Affected Evidence: GET Device And Association into Temp Table    
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    INSERT INTO Temp_CustDevice(CTSCustID, DCSDeviceID)
    SELECT 		ad.CTSCustID
				, ad.DCSDeviceID
	FROM		CTS_DataCenter.AssociationByDevice AS ad
    WHERE		(ad.CTSCustID 	= ip_FromCTSCustID
				OR ad.CTSCustID = ip_ToCTSCustID)
                AND ad.SubscriberID = ip_FromSubscriberID;    
    
    # If exist any device association with The removed exception Customers
    IF EXISTS (SELECT 1 FROM Temp_CustDevice LIMIT 1) THEN
    
		INSERT	INTO Temp_CustAssociation(FromCTSCustID, ToCTSCustID)
		SELECT  	DISTINCT tcd.CTSCustID
					, ad.CTSCustID
		FROM		Temp_CustDevice 		AS tcd
		INNER JOIN	CTS_DataCenter.AssociationByDevice 	AS ad
					ON	tcd.DCSDeviceID			= ad.DCSDeviceID
						AND ad.SubscriberID		= ip_FromSubscriberID
		WHERE		ad.CTSCustID IN (ip_FromCTSCustID,ip_ToCTSCustID);
		
		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
		
		DELETE	tca
		FROM	Temp_CustAssociation AS tca
		WHERE	tca.FromCTSCustID = tca.ToCTSCustID;
		
		# If ip_FromCTSCustID Association with ip_ToCTSCustID
		IF EXISTS (SELECT 1 FROM Temp_CustAssociation LIMIT 1) THEN 
        
			#=====Insert Affected Evidence: GET Device And Association into Temp Table
			SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;           
            
			INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, SubscriberID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy, IsCreatedByMaster)
			SELECT	tca.ToCTSCustID
					, ce.SubscriberID
					, EvidenceID
					, 'Auto RemoveException' AS Remark	# Auto by RemoveException
					, 2 				AS Level
					, ip_FromCTSCustID	AS FromCustID
					, vr_CreatedDate	AS CreatedDate
					, ce.CreatedBy 		AS CreatedBy
                    , ce.IsCreatedByMaster	AS IsCreatedByMaster
			FROM		CTS_DataCenter.CustEvidence	AS ce
			INNER JOIN	Temp_CustAssociation AS tca
						ON ce.CTSCustID = tca.FromCTSCustID
							AND ce.SubscriberID = ip_FromSubscriberID
			WHERE		ce.CTSCustID	= ip_FromCTSCustID
						AND ce.Level	= 0;	
			
			INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, SubscriberID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy, IsCreatedByMaster)
			SELECT	ip_FromCTSCustID
					, ce.SubscriberID
					, EvidenceID
					, 'Auto RemoveException' AS Remark
					, 2 				AS Level
					, ip_ToCTSCustID	AS FromCustID
					, vr_CreatedDate	AS CreatedDate
					, ce.CreatedBy 		AS CreatedBy
                    , ce.IsCreatedByMaster	AS IsCreatedByMaster
			FROM		CTS_DataCenter.CustEvidence	AS ce
			INNER JOIN	Temp_CustAssociation AS tca
						ON ce.CTSCustID = tca.FromCTSCustID
							AND ce.SubscriberID = ip_FromSubscriberID
			WHERE		ce.CTSCustID	= ip_ToCTSCustID			
						AND ce.Level = 0;
						
			SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
			
			INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
			VALUES(3, vr_SPName, CONCAT('Auto Add by Remove Exception Function: ip_FromCTSCustID_ ', ip_FromCTSCustID, ';ip_ToCTSCustID', ip_ToCTSCustID) , vr_CreatedDate, ip_UserID);
			
			SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
        END IF;
	END IF;
END