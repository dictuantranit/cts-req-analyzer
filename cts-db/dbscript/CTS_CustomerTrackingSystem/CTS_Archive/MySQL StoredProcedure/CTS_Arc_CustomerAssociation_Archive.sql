/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsServiceAdmin,ctsWebAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_Arc_CustomerAssociation_Archive`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_Arc_CustomerAssociation_Archive`()
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
			- 20230207@Long.Luu: 		Get exact lastticketdate [Redmine ID: #183281]
			- 20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
			- 20230421@Casey.Huynh: 	Add AssType to AssociationByIP [Redmine ID: #185783]
            - 20240426@Thomas.Nguyen:	Classify Initial Group Betting - Add ParentID = 150 [Redmine ID: #200854]
			- 20240923@Jonas.Huynh:		Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]	
            
        Param's Explanation (filtered by):

        Example:  
			- CALL CTS_Arc_CustomerAssociation_Archive();
*/   
 DECLARE	CONST_15Days 			    INT DEFAULT 15; 
    DECLARE	CONST_30Days 				INT DEFAULT 30;
    DECLARE	CONST_60Days 				INT DEFAULT 60;
    DECLARE	CONST_90Days 				INT DEFAULT 90;

    DECLARE	CONST_Tagging_Normal 		INT DEFAULT 0;
    DECLARE	CONST_Tagging_WithPA 		INT DEFAULT 1;
    DECLARE	CONST_Tagging_TW 			INT DEFAULT 2;

	DECLARE CONST_PARENTID_PA					INT;
	DECLARE CONST_PARENTID_NORMAL				INT;
	DECLARE CONST_PARENTID_POTENTIALPA			INT;
	DECLARE	CONST_BIZCATEGROUPID_NORMAL 		INT;

	DECLARE lv_DateValid 			    DATETIME DEFAULT DATE_SUB(NOW(), INTERVAL CONST_15Days DAY); 
    DECLARE lv_NowToDays 			    INT DEFAULT TO_DAYS(NOW());
	DECLARE lv_BatchSize_Cust 		    INT;
    DECLARE lv_LastCTSCust 			    BIGINT UNSIGNED;
    DECLARE lv_BatchSize_AssData 	    INT;
    DECLARE lv_Table 				    VARCHAR(100);
    DECLARE lv_Count				    INT DEFAULT 0;
    DECLARE lv_DayProcessing		    INT DEFAULT TO_DAYS(NOW());

	SET CONST_PARENTID_PA 				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
    SET CONST_PARENTID_NORMAL 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');    
    SET CONST_PARENTID_POTENTIALPA 		= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_POTENTIALPA');    
	SET CONST_BIZCATEGROUPID_NORMAL 	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_NORMAL');
        
    SELECT ParameterValue
    INTO lv_BatchSize_Cust
    FROM CTS_Archive.SystemParameter
    WHERE ParameterID = 1;
    
    SELECT ParameterValue
    INTO lv_LastCTSCust
    FROM CTS_Archive.SystemParameter
    WHERE ParameterID = 2;
    
    SELECT ParameterValue
    INTO lv_BatchSize_AssData
    FROM CTS_Archive.SystemParameter
    WHERE ParameterID = 3;
    
    SELECT ParameterValue
    INTO lv_Table
    FROM CTS_Archive.SystemParameter
    WHERE ParameterID = 4;
    
    SELECT ParameterValue
    INTO lv_DayProcessing
    FROM CTS_Archive.SystemParameter
    WHERE ParameterID = 8;
    
    IF lv_DayProcessing > lv_NowToDays THEN
		LEAVE sp;
	END IF;
    
    IF NOT EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process) THEN
		DROP TEMPORARY TABLE IF EXISTS Temp_CustNoBet;    
		CREATE TEMPORARY TABLE Temp_CustNoBet( 	
				CTSCustID	BIGINT UNSIGNED	
			,	CustID		BIGINT UNSIGNED	
            ,	Days		INT
			,	PRIMARY	KEY (CTSCustID)
		);
        
        INSERT INTO Temp_CustNoBet(CTSCustID, CustID, Days)
        SELECT  cus.CTSCustID
			,	cus.CustID
            ,	lv_NowToDays - TO_DAYS(IFNULL(cus.LastTicketDate, cus.Created)) 
        FROM CTS_Archive.CTSCustomerAssociationStatus AS cus 
        WHERE IFNULL(cus.LastTicketDate, cus.Created) <= lv_DateValid
			AND cus.CTSCustID > lv_LastCTSCust
            AND cus.IsArchived = 0
        ORDER BY cus.CTSCustID ASC
        LIMIT lv_BatchSize_Cust;
        
        IF NOT EXISTS (SELECT 1 FROM Temp_CustNoBet) THEN
			UPDATE CTS_Archive.SystemParameter
			SET ParameterValue = '0'
			WHERE ParameterID = 2;
            
            UPDATE CTS_Archive.SystemParameter
			SET ParameterValue = 'AssociationByAI-From'
			WHERE ParameterID = 4; 
            
			UPDATE CTS_Archive.SystemParameter
			SET ParameterValue = lv_NowToDays + 1
			WHERE ParameterID = 8; 
            
			LEAVE sp;
        END IF;
        
        INSERT IGNORE INTO CTS_Archive.CTSCustomerAssociationArchive_Process(CTSCustID, CustID)
        SELECT 	DISTINCT
				tmp.CTSCustID
			,	tmp.CustID
        FROM Temp_CustNoBet AS tmp
			INNER JOIN  CTS_DataCenter.CTSCustomer AS cus ON tmp.CTSCustID = cus.CTSCustID
		,	LATERAL (
				SELECT cate.ParentID, cate.TaggingType, cate.BusinessCategoryGroupID
                FROM CTS_DataCenter.CTSCustomerClassification AS cls
					INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cls.CategoryID = cate.CategoryID
				WHERE tmp.CTSCustID = cls.CTSCustID
				ORDER BY CategoryPriority ASC
                LIMIT 1
            ) AS ltc
        WHERE  (cus.CustStatusID IN (2,3,4,12,13,14) AND (ltc.ParentID = CONST_PARENTID_NORMAL AND ltc.TaggingType = CONST_Tagging_Normal) AND tmp.Days >= CONST_15Days)
			OR (cus.CustStatusID NOT IN (2,3,4,12,13,14) AND (ltc.ParentID = CONST_PARENTID_NORMAL AND ltc.TaggingType = CONST_Tagging_Normal) AND tmp.Days >= CONST_30Days)
            OR (((ltc.ParentID = CONST_PARENTID_NORMAL AND ltc.TaggingType IN (CONST_Tagging_WithPA,CONST_Tagging_TW)) OR (ltc.ParentID = CONST_PARENTID_PA AND ltc.BusinessCategoryGroupID = CONST_BIZCATEGROUPID_NORMAL)) AND tmp.Days >= CONST_60Days)
            OR (ltc.ParentID = CONST_PARENTID_PA AND ltc.BusinessCategoryGroupID <> CONST_BIZCATEGROUPID_NORMAL AND tmp.Days >= CONST_90Days);
        
        IF NOT EXISTS (SELECT 1 FROM  CTS_Archive.CTSCustomerAssociationArchive_Process) THEN
			
            SELECT MAX(CTSCustID)
			INTO lv_LastCTSCust
			FROM Temp_CustNoBet;
            
			UPDATE CTS_Archive.SystemParameter
			SET ParameterValue = lv_LastCTSCust
			WHERE ParameterID = 2;
            
            UPDATE CTS_Archive.SystemParameter
			SET ParameterValue = 'AssociationByAI-From'
			WHERE ParameterID = 4; 
            
			LEAVE sp;
        END IF;
        
		UPDATE CTS_Archive.SystemParameter
		SET ParameterValue = 'AssociationByAI-From'
		WHERE ParameterID = 4; 
        
        SET lv_Table = 'AssociationByAI-From';
    END IF;
	
	IF (lv_Table = 'AssociationByAI-From') THEN  
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByAI AS ai WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ai.FromCustID = pro.CustID)) THEN
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
            SELECT 	ai.AssID
				,	ai.AssType
				,	ai.FromCustID
				,	ai.ToCustID
                ,	ai.CreatedDate
			FROM CTS_DataCenter.AssociationByAI  AS ai
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ai.FromCustID = pro.CustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_Archive.AssociationByAI_Arc(AssType, FromCustID, ToCustID, AssociationDate)
            SELECT	AssType
				,	FromCustID
				,	ToCustID
                ,	AssociationDate
			FROM Temp_AssociationByAI_Clean;
            
            DELETE ass
			FROM CTS_DataCenter.AssociationByAI AS ass
				INNER JOIN Temp_AssociationByAI_Clean AS tmp ON tmp.AssID = ass.AssID;
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByAI-From'
			WHERE ParameterID = 4;
			
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
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByAI AS ai WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ai.ToCustID = pro.CustID)) THEN
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
            SELECT 	ai.AssID
				,	ai.AssType
				,	ai.FromCustID
				,	ai.ToCustID
                ,	ai.CreatedDate
			FROM CTS_DataCenter.AssociationByAI  AS ai
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ai.ToCustID = pro.CustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_Archive.AssociationByAI_Arc(AssType, FromCustID, ToCustID, AssociationDate)
            SELECT	AssType
				,	FromCustID
				,	ToCustID
                ,	AssociationDate
			FROM Temp_AssociationByAI_Clean;
            
            DELETE ass
			FROM CTS_DataCenter.AssociationByAI AS ass
				INNER JOIN Temp_AssociationByAI_Clean AS tmp ON tmp.AssID = ass.AssID;
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByAI-To'
			WHERE ParameterID = 4;

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
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationGroupByAI AS asg WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE asg.CustID = pro.CustID)) THEN
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
			FROM CTS_DataCenter.AssociationGroupByAI  AS asg
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE asg.CustID = pro.CustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_Archive.AssociationGroupByAI_Arc(ID, GroupID, OriginGroupID, CustID, CreatedDate)
			SELECT 	tmpCl.ID
				,	tmpCl.GroupID
                ,	tmpCl.OriginGroupID
                ,	tmpCl.CustID
                ,	tmpCl.CreatedDate
			FROM Temp_AssociationGroupByAI_Clean  AS tmpCl;
            
            DELETE asg
			FROM CTS_DataCenter.AssociationGroupByAI AS asg
				INNER JOIN Temp_AssociationGroupByAI_Clean AS tmpCl ON tmpCl.CustID = asg.CustID AND tmpCl.GroupID = asg.GroupID;
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationGroupByAI'
			WHERE ParameterID = 4;

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
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByDevice AS dv WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE dv.CTSCustID = pro.CTSCustID)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByDevice_Clean;
			CREATE TEMPORARY TABLE Temp_AssociationByDevice_Clean(
					CTSAssDevID   	BIGINT UNSIGNED PRIMARY KEY
				,	CTSCustID		BIGINT UNSIGNED
                ,	DCSDeviceID		BIGINT UNSIGNED
                ,	SubscriberID	INT
                ,	AssociationDate	DATETIME
			);
            
            INSERT IGNORE INTO Temp_AssociationByDevice_Clean(CTSAssDevID, CTSCustID, DCSDeviceID, SubscriberID, AssociationDate)
            SELECT 	dv.CTSAssDevID
				, 	dv.CTSCustID
                , 	dv.DCSDeviceID
                , 	dv.SubscriberID
                ,	dv.CreatedTime
			FROM CTS_DataCenter.AssociationByDevice AS dv
			WHERE  EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE dv.CTSCustID = pro.CTSCustID)
			LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_Archive.AssociationByDevice_Arc(CTSCustID, DCSDeviceID, SubscriberID, AssociationDate)
            SELECT	CTSCustID
                , 	DCSDeviceID
                , 	SubscriberID
                , 	AssociationDate
			FROM Temp_AssociationByDevice_Clean;
            
            DELETE 
			FROM CTS_DataCenter.AssociationByDevice AS dv
			WHERE  EXISTS (SELECT 1 FROM Temp_AssociationByDevice_Clean AS cln WHERE cln.CTSAssDevID = dv.CTSAssDevID);
        
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByDevice'
			WHERE ParameterID = 4;
        
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
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByIP AS ip WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ip.FromCustID = pro.CustID)) THEN
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
                ,	ip.CreatedDate
			FROM CTS_DataCenter.AssociationByIP AS ip
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ip.FromCustID = pro.CustID)
			LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_Archive.AssociationByIP_Arc(AssType, FromCustID, ToCustID, AssociationDate)
            SELECT 	tmp.AssType
				,	tmp.FromCustID
				,	tmp.ToCustID
                ,	tmp.AssociationDate
            FROM Temp_AssociationByIP_Clean AS tmp;
            
            DELETE ip
			FROM CTS_DataCenter.AssociationByIP AS ip
			WHERE  EXISTS (SELECT 1 FROM Temp_AssociationByIP_Clean AS cln WHERE cln.ID = ip.ID);
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByIP-From'
			WHERE ParameterID = 4;
			
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
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByIP AS ip WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ip.ToCustID = pro.CustID)) THEN
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
                ,	ip.CreatedDate
			FROM CTS_DataCenter.AssociationByIP AS ip
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ip.ToCustID = pro.CustID)
			LIMIT lv_BatchSize_AssData;
                  
            INSERT IGNORE INTO CTS_Archive.AssociationByIP_Arc(AssType, FromCustID, ToCustID, AssociationDate)
            SELECT 	tmp.AssType
				,	tmp.FromCustID
				,	tmp.ToCustID
                ,	tmp.AssociationDate
            FROM Temp_AssociationByIP_Clean AS tmp;
            
            DELETE ip
			FROM CTS_DataCenter.AssociationByIP AS ip
			WHERE  EXISTS (SELECT 1 FROM Temp_AssociationByIP_Clean AS cln WHERE cln.ID = ip.ID);
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByIP-To'
			WHERE ParameterID = 4;
			
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
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByManual AS ma WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ma.FromCTSCustID = pro.CTSCustID)) THEN
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
                ,	ma.CreatedDate
                ,	ma.CreatedBy
			FROM CTS_DataCenter.AssociationByManual AS ma
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ma.FromCTSCustID = pro.CTSCustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_Archive.AssociationByManual_Arc(FromCTSCustID, ToCTSCustID, FromSubscriberID, ToSubscriberID, Remark, AssociationDate, CreatedBy)
			SELECT 	FromCTSCustID
				,	ToCTSCustID
                ,	FromSubscriberID
                ,	ToSubscriberID
                ,	Remark
                ,	AssociationDate
                ,	CreatedBy
			FROM Temp_AssociationByManual_Clean;
            
			DELETE ass
			FROM CTS_DataCenter.AssociationByManual AS ass
				INNER JOIN Temp_AssociationByManual_Clean AS tmp ON tmp.FromCTSCustID = ass.FromCTSCustID AND tmp.ToCTSCustID = ass.ToCTSCustID;
        
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByManual-From'
			WHERE ParameterID = 4;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_AssociationByManual_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'AssociationByManual-To';
	 END IF;  
     
    IF (lv_Table = 'AssociationByManual-To') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.AssociationByManual AS ma WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ma.ToCTSCustID = pro.CTSCustID)) THEN
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
                ,	ma.CreatedDate
                ,	ma.CreatedBy
			FROM CTS_DataCenter.AssociationByManual AS ma
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ma.ToCTSCustID = pro.CTSCustID)
            LIMIT lv_BatchSize_AssData;
            
            INSERT IGNORE INTO CTS_Archive.AssociationByManual_Arc(FromCTSCustID, ToCTSCustID, FromSubscriberID, ToSubscriberID, Remark, AssociationDate, CreatedBy)
			SELECT 	FromCTSCustID
				,	ToCTSCustID
                ,	FromSubscriberID
                ,	ToSubscriberID
                ,	Remark
                ,	AssociationDate
                ,	CreatedBy
			FROM Temp_AssociationByManual_Clean;
            
			DELETE ass
			FROM CTS_DataCenter.AssociationByManual AS ass
				INNER JOIN Temp_AssociationByManual_Clean AS tmp ON tmp.FromCTSCustID = ass.FromCTSCustID AND tmp.ToCTSCustID = ass.ToCTSCustID;
        
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'AssociationByManual-To'
			WHERE ParameterID = 4;
			
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
	 
	IF (lv_Table = 'CustEvidence-From') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CustEvidence AS ev WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ev.FromCustID = pro.CTSCustID AND ev.Level = 2)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CustEvidence_Clean;
			CREATE TEMPORARY TABLE Temp_CustEvidence_Clean(
					CustEvidID		BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_CustEvidence_Clean(CustEvidID)
            SELECT 	ev.CustEvidID
			FROM CTS_DataCenter.CustEvidence AS ev
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ev.FromCustID = pro.CTSCustID AND  ev.Level = 2)
			LIMIT lv_BatchSize_AssData;
          
			DELETE 
			FROM CTS_DataCenter.CustEvidence AS  ev
			WHERE  EXISTS (SELECT 1 FROM Temp_CustEvidence_Clean AS tmp WHERE ev.CustEvidID = tmp.CustEvidID);
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'CustEvidence-From'
			WHERE ParameterID = 4;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CustEvidence_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'CustEvidence-To';
	 END IF;
     
	IF (lv_Table = 'CustEvidence-To') THEN
		IF EXISTS (SELECT 1  FROM CTS_DataCenter.CustEvidence AS ev WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ev.CTSCustID = pro.CTSCustID AND ev.Level = 2)) THEN
			DROP TEMPORARY TABLE IF EXISTS Temp_CustEvidence_Clean;
			CREATE TEMPORARY TABLE Temp_CustEvidence_Clean(
					CustEvidID		BIGINT UNSIGNED PRIMARY KEY
			);
            
            INSERT IGNORE INTO Temp_CustEvidence_Clean(CustEvidID)
            SELECT 	ev.CustEvidID
			FROM CTS_DataCenter.CustEvidence AS ev
			WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE ev.CTSCustID = pro.CTSCustID AND  ev.Level = 2)
			LIMIT lv_BatchSize_AssData;
          
			DELETE 
			FROM CTS_DataCenter.CustEvidence AS  ev
			WHERE  EXISTS (SELECT 1 FROM Temp_CustEvidence_Clean AS tmp WHERE ev.CustEvidID = tmp.CustEvidID);
			
			UPDATE  CTS_Archive.SystemParameter 
			SET ParameterValue = 'CustEvidence-To'
			WHERE ParameterID = 4;
			
			SELECT COUNT(1)
            INTO lv_Count
            FROM Temp_CustEvidence_Clean;
            
            IF lv_Count >= lv_BatchSize_AssData THEN
				LEAVE sp;
            END IF;
			
            SET lv_BatchSize_AssData = lv_BatchSize_AssData - lv_Count;
        END IF;
        
        SET lv_Table = 'CustEvidence-To';
	 END IF; 
	
    SELECT MAX(CTSCustID)
    INTO lv_LastCTSCust
    FROM CTS_Archive.CTSCustomerAssociationArchive_Process;
            
	UPDATE CTS_Archive.SystemParameter
	SET ParameterValue = 'AssociationByAI-From'
	WHERE ParameterID = 4; 
    
    UPDATE CTS_Archive.CTSCustomerAssociationStatus AS cus
    SET cus.IsArchived = 1
    WHERE EXISTS (SELECT 1 FROM CTS_Archive.CTSCustomerAssociationArchive_Process AS pro WHERE pro.CTSCustID = cus.CTSCustID);
    
	DELETE 
    FROM CTS_Archive.CTSCustomerAssociationArchive_Process;
    
	UPDATE CTS_Archive.SystemParameter
	SET ParameterValue = lv_LastCTSCust
	WHERE ParameterID = 2;
    
END$$
DELIMITER ;