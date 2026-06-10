/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsServiceAdmin,ctsWebAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_Arc_CustomerAssociation_Rollback`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_Arc_CustomerAssociation_Rollback`()
    SQL SECURITY INVOKER
sp : BEGIN
/*
		Created:	20211026@Aries.Nguyen
		Task:		Archive Inactive Association
		DB:			CTS_Archive
		Original:
		Revisions:
			- 20211026@Aries.Nguyen 	[Redmine ID: #163087]: Created
			- 20220408@Casey.Huynh: 	Add AssociationGroupByAI [Redmine ID: #171222]
			- 20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
			- 20230421@Casey.Huynh: 	Add AssType to AssociationByIP [Redmine ID: #185783]
            
        Param's Explanation (filtered by):

        Example:  
			- CALL CTS_Arc_CustomerAssociation_Rollback();
*/   
	DECLARE lv_BatchSize_Cust 		INT;
    DECLARE lv_BatchSize_AssData 	INT;
    DECLARE lv_Table 				VARCHAR(100);
    DECLARE lv_Count				INT DEFAULT 0;
    
    SELECT ParameterValue
    INTO lv_BatchSize_Cust
    FROM CTS_Archive.SystemParameter
    WHERE ParameterID = 5;
    
    SELECT ParameterValue
    INTO lv_BatchSize_AssData
    FROM CTS_Archive.SystemParameter
    WHERE ParameterID = 6;
    
    SELECT ParameterValue
    INTO lv_Table
    FROM CTS_Archive.SystemParameter
    WHERE ParameterID = 7;
    
    IF NOT EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process) THEN
        INSERT INTO CTS_Archive.CTSCustomerAssociationRollBack_Process(CTSCustID, CustID)
        SELECT  cus.CTSCustID
			,	cus.CustID
        FROM CTS_Archive.CTSCustomerAssociationStatus AS cus 
        WHERE cus.IsRollBack = 1
        ORDER BY cus.RollBackDate ASC
        LIMIT lv_BatchSize_Cust;
        
        IF NOT EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process) THEN
            UPDATE CTS_Archive.SystemParameter
			SET ParameterValue = 'AssociationByAI-From'
			WHERE ParameterID = 7; 
            
			LEAVE sp;
        END IF;
        
		UPDATE CTS_Archive.SystemParameter
		SET ParameterValue = 'AssociationByAI-From'
		WHERE ParameterID = 7; 
        
        SET lv_Table = 'AssociationByAI-From';
    END IF;
	
	IF (lv_Table = 'AssociationByAI-From') THEN  
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByAI_Arc AS ai WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ai.FromCustID = pro.CustID )) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByAI_Clean(
					AssID			BIGINT		UNSIGNED
				,	AssType			SMALLINT	UNSIGNED
				,	FromCustID   	BIGINT 		UNSIGNED  
				,	ToCustID		BIGINT 		UNSIGNED
                ,	AssociationDate	DATETIME
                ,	PRIMARY KEY(AssID)
			);
            
            INSERT IGNORE INTO Temp_AssociationByAI_Clean(AssID, AssType, FromCustID, ToCustID, AssociationDate)
            SELECT 	ai.ID
				,	ai.AssType
				,	ai.FromCustID
				,	ai.ToCustID
                ,	ai.AssociationDate
			FROM CTS_Archive.AssociationByAI_Arc  AS ai
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ai.FromCustID = pro.CustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_DataCenter.AssociationByAI(AssType, FromCustID, ToCustID, CreatedDate)
            SELECT	AssType
				,	FromCustID
				,	ToCustID
                ,	AssociationDate
			FROM Temp_AssociationByAI_Clean;
            
            DELETE ass
			FROM CTS_Archive.AssociationByAI_Arc AS ass
				INNER JOIN Temp_AssociationByAI_Clean AS tmp ON tmp.AssID = ass.ID;
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByAI-From'
			WHERE ParameterID = 7;
			
            SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByAI_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
            
        END IF;
        
		SET lv_Table = 'AssociationByAI-To';
    END IF;
    
    IF (lv_Table = 'AssociationByAI-To') THEN  
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByAI_Arc AS ai WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ai.ToCustID = pro.CustID )) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByAI_Clean(
					AssID			BIGINT		UNSIGNED
				,	AssType			SMALLINT	UNSIGNED
				,	FromCustID   	BIGINT 		UNSIGNED  
				,	ToCustID		BIGINT 		UNSIGNED
                ,	AssociationDate	DATETIME
                ,	PRIMARY KEY(AssID)
			);
            
            INSERT IGNORE INTO Temp_AssociationByAI_Clean(AssID, AssType, FromCustID, ToCustID, AssociationDate)
            SELECT 	ai.ID
				,	ai.AssType
				,	ai.FromCustID
				,	ai.ToCustID
                ,	ai.AssociationDate
			FROM CTS_Archive.AssociationByAI_Arc  AS ai
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ai.ToCustID = pro.CustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_DataCenter.AssociationByAI(AssType, FromCustID, ToCustID, CreatedDate)
            SELECT	AssType
				,	FromCustID
				,	ToCustID
                ,	AssociationDate
			FROM Temp_AssociationByAI_Clean;
            
            DELETE ass
			FROM CTS_Archive.AssociationByAI_Arc AS ass
				INNER JOIN Temp_AssociationByAI_Clean AS tmp ON tmp.AssID = ass.ID;
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByAI-To'
			WHERE ParameterID = 7;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByAI_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'AssociationGroupByAI';
    END IF;
    
    IF (lv_Table = 'AssociationGroupByAI') THEN  
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationGroupByAI_Arc AS asg WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE asg.CustID = pro.CustID )) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationGroupByAI_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationGroupByAI_Clean(
					ID				BIGINT UNSIGNED DEFAULT NULL
				,	GroupID 		BIGINT UNSIGNED NOT NULL
				,	OriginGroupID 	BIGINT UNSIGNED NOT NULL
				,	CustID 			BIGINT UNSIGNED NOT NULL
				,	CreatedDate 	DATETIME DEFAULT NULL
                
                ,	PRIMARY KEY (CustID,GroupID)
			) ENGINE=InnoDB;
            
            INSERT IGNORE INTO Temp_AssociationGroupByAI_Clean(ID, GroupID, OriginGroupID, CustID, CreatedDate)
            SELECT 	asg.ID
				,	asg.GroupID
                ,	asg.OriginGroupID
                ,	asg.CustID
                ,	asg.CreatedDate
			FROM CTS_Archive.AssociationGroupByAI_Arc  AS asg
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE asg.CustID = pro.CustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_DataCenter.AssociationGroupByAI(GroupID, OriginGroupID, CustID, CreatedDate)
            SELECT	tmpCl.GroupID
                ,	tmpCl.OriginGroupID
                ,	tmpCl.CustID
                ,	tmpCl.CreatedDate
			FROM Temp_AssociationGroupByAI_Clean AS tmpCl;
            SELECT 1;
            DELETE ass
			FROM CTS_Archive.AssociationGroupByAI_Arc AS ass
				INNER JOIN Temp_AssociationGroupByAI_Clean AS tmpCl ON ass.CustID = tmpCl.CustID AND ass.GroupID = tmpCl.GroupID;
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationGroupByAI'
			WHERE ParameterID = 7;

			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationGroupByAI_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'AssociationByDevice';
    END IF;
    
	IF (lv_Table = 'AssociationByDevice') THEN
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByDevice_Arc AS dv WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE dv.CTSCustID = pro.CTSCustID)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByDevice_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByDevice_Clean(
					ID   			BIGINT UNSIGNED PRIMARY KEY
				,	CTSCustID		BIGINT UNSIGNED
                ,	DCSDeviceID		BIGINT UNSIGNED
                ,	SubscriberID	INT
                ,	AssociationDate	DATETIME
			);
            
            INSERT IGNORE INTO Temp_AssociationByDevice_Clean(ID, CTSCustID, DCSDeviceID, SubscriberID, AssociationDate)
            SELECT 	dv.ID
				, 	dv.CTSCustID
                , 	dv.DCSDeviceID
                , 	dv.SubscriberID
                ,	dv.AssociationDate
			FROM CTS_Archive.AssociationByDevice_Arc AS dv
			WHERE  EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE dv.CTSCustID = pro.CTSCustID)
			LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_DataCenter.AssociationByDevice(CTSCustID, DCSDeviceID, SubscriberID, CreatedTime)
            SELECT	CTSCustID
                , 	DCSDeviceID
                , 	SubscriberID
                , 	AssociationDate
			FROM Temp_AssociationByDevice_Clean;
            
            DELETE 
			FROM CTS_Archive.AssociationByDevice_Arc AS dv
			WHERE  EXISTS (SELECT 1 FROM Temp_AssociationByDevice_Clean AS cln WHERE cln.ID = dv.ID);
        
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByDevice'
			WHERE ParameterID = 7;
        
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByDevice_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'AssociationByIP-From';
	END IF; 
    
	IF (lv_Table = 'AssociationByIP-From') THEN
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByIP_Arc AS ip WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ip.FromCustID = pro.CustID)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByIP_Clean(
					ID   			BIGINT UNSIGNED PRIMARY KEY
				,	AssType			SMALLINT UNSIGNED
				,	FromCustID		BIGINT UNSIGNED
                ,	ToCustID		BIGINT UNSIGNED
                ,	AssociationDate	DATETIME
			);
            
            INSERT IGNORE INTO Temp_AssociationByIP_Clean(ID, AssType, FromCustID, ToCustID, AssociationDate)
            SELECT 	ip.ID
				,	ip.AssType
				,	ip.FromCustID
                ,	ip.ToCustID
                ,	ip.AssociationDate
			FROM CTS_Archive.AssociationByIP_Arc AS ip
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ip.FromCustID = pro.CustID)
			LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_DataCenter.AssociationByIP(AssType, FromCustID, ToCustID, CreatedDate)
            SELECT 	tmp.AssType
				,	tmp.FromCustID
				,	tmp.ToCustID
                ,	tmp.AssociationDate
            FROM Temp_AssociationByIP_Clean AS tmp;
            
            DELETE ip
			FROM CTS_Archive.AssociationByIP_Arc AS ip
			WHERE  EXISTS (SELECT 1 FROM Temp_AssociationByIP_Clean AS cln WHERE cln.ID = ip.ID);
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByIP-From'
			WHERE ParameterID = 7;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByIP_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'AssociationByIP-To';
	 END IF; 
     
	IF (lv_Table = 'AssociationByIP-To') THEN
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByIP_Arc AS ip WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ip.ToCustID = pro.CustID)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByIP_Clean(
					ID   			BIGINT UNSIGNED PRIMARY KEY
				,	AssType			SMALLINT UNSIGNED
				,	FromCustID		BIGINT UNSIGNED
                ,	ToCustID		BIGINT UNSIGNED
                ,	AssociationDate	DATETIME
			);
            
            INSERT IGNORE INTO Temp_AssociationByIP_Clean(ID, AssType, FromCustID, ToCustID, AssociationDate)
            SELECT 	ip.ID
				,	ip.AssType
				,	ip.FromCustID
                ,	ip.ToCustID
                ,	ip.AssociationDate
			FROM CTS_Archive.AssociationByIP_Arc AS ip
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ip.ToCustID = pro.CustID)
			LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_DataCenter.AssociationByIP(AssType, FromCustID, ToCustID, CreatedDate)
            SELECT 	tmp.AssType
				,	tmp.FromCustID
				,	tmp.ToCustID
                ,	tmp.AssociationDate
            FROM Temp_AssociationByIP_Clean AS tmp;
            
            DELETE ip
			FROM CTS_Archive.AssociationByIP_Arc AS ip
			WHERE  EXISTS (SELECT 1 FROM Temp_AssociationByIP_Clean AS cln WHERE cln.ID = ip.ID);
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByIP-To'
			WHERE ParameterID = 7;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByIP_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'AssociationByManual-From';
	 END IF;   
     
	IF (lv_Table = 'AssociationByManual-From') THEN
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByManual_Arc AS ma WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ma.FromCTSCustID = pro.CTSCustID)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByManual_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByManual_Clean(
					ID 					BIGINT UNSIGNED 
				,	FromCTSCustID   	BIGINT UNSIGNED  
				,	ToCTSCustID			BIGINT UNSIGNED
                ,	FromSubscriberID	INT UNSIGNED
                ,	ToSubscriberID		INT UNSIGNED
                ,	Remark				VARCHAR(500)
                ,	AssociationDate		DATETIME
                ,	CreatedBy			BIGINT UNSIGNED
                ,	PRIMARY KEY(FromCTSCustID, ToCTSCustID)
			);
            
            INSERT IGNORE INTO Temp_AssociationByManual_Clean(ID, FromCTSCustID, ToCTSCustID, FromSubscriberID, ToSubscriberID, Remark, AssociationDate, CreatedBy)
            SELECT 	ma.ID
				,	ma.FromCTSCustID
				,	ma.ToCTSCustID
                ,	ma.FromSubscriberID
                ,	ma.ToSubscriberID
                ,	ma.Remark
                ,	ma.AssociationDate
                ,	ma.CreatedBy
			FROM CTS_Archive.AssociationByManual_Arc AS ma
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ma.FromCTSCustID = pro.CTSCustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_DataCenter.AssociationByManual(FromCTSCustID, ToCTSCustID, FromSubscriberID, ToSubscriberID, Remark, CreatedDate, CreatedBy)
			SELECT 	FromCTSCustID
				,	ToCTSCustID
                ,	FromSubscriberID
                ,	ToSubscriberID
                ,	Remark
                ,	AssociationDate
                ,	CreatedBy
			FROM Temp_AssociationByManual_Clean;
            
			DELETE ass
			FROM CTS_Archive.AssociationByManual_Arc AS ass
            WHERE EXISTS (SELECT 1 FROM Temp_AssociationByManual_Clean AS cln WHERE cln.ID = ass.ID);
		
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByManual-From'
			WHERE ParameterID = 7;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM AssociationByManual_Arc;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'AssociationByManual-To';
	 END IF;  
     
    IF (lv_Table = 'AssociationByManual-To') THEN
		IF EXISTS (SELECT 1  FROM CTS_Archive.AssociationByManual_Arc AS ma WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ma.ToCTSCustID = pro.CTSCustID)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByManual_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByManual_Clean(
					FromCTSCustID   	BIGINT UNSIGNED  
				,	ToCTSCustID			BIGINT UNSIGNED
                ,	FromSubscriberID	INT UNSIGNED
                ,	ToSubscriberID		INT UNSIGNED
                ,	Remark				VARCHAR(500)
                ,	AssociationDate		DATETIME
                ,	CreatedBy			BIGINT UNSIGNED
                ,	PRIMARY KEY(FromCTSCustID, ToCTSCustID)
			);
            
            INSERT IGNORE INTO Temp_AssociationByManual_Clean(FromCTSCustID, ToCTSCustID, FromSubscriberID, ToSubscriberID, Remark, AssociationDate, CreatedBy)
            SELECT 	ma.FromCTSCustID
				,	ma.ToCTSCustID
                ,	ma.FromSubscriberID
                ,	ma.ToSubscriberID
                ,	ma.Remark
                ,	ma.AssociationDate
                ,	ma.CreatedBy
			FROM CTS_Archive.AssociationByManual_Arc AS ma
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE ma.ToCTSCustID = pro.CTSCustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_DataCenter.AssociationByManual(FromCTSCustID, ToCTSCustID, FromSubscriberID, ToSubscriberID, Remark, CreatedDate, CreatedBy)
			SELECT 	FromCTSCustID
				,	ToCTSCustID
                ,	FromSubscriberID
                ,	ToSubscriberID
                ,	Remark
                ,	AssociationDate
                ,	CreatedBy
			FROM Temp_AssociationByManual_Clean;
            
			DELETE ass
			FROM CTS_Archive.AssociationByManual_Arc AS ass
				INNER JOIN Temp_AssociationByManual_Clean AS tmp ON tmp.FromCTSCustID = ass.FromCTSCustID AND tmp.ToCTSCustID = ass.ToCTSCustID;
        
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByManual-To'
			WHERE ParameterID = 7;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByManual_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'CustEvidence-From';
	 END IF;    
	
    UPDATE CTS_Archive.CTSCustomerAssociationStatus AS cus
    SET 	cus.IsRollBack = 0
		,	cus.RollBackDate = NULL
        ,	cus.IsArchived = 0
    WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationRollBack_Process AS pro WHERE pro.CTSCustID = cus.CTSCustID);
            
	UPDATE CTS_Archive.SystemParameter
	SET ParameterValue = 'AssociationByAI-From'
	WHERE ParameterID = 7; 
    
	DELETE 
    FROM CTS_Archive.CTSCustomerAssociationRollBack_Process;
END$$
DELIMITER ;