/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_Device_GetPackage`;

DELIMITER $$
CREATE DEFINER=`dcsService`@`%` PROCEDURE `DCS_DC_Transform_Device_GetPackage`(
        IN ip_NoOfTickets INT
    ,   IN ip_NoOfBatch INT
)
     SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20200908@Bobby.Nguyen
	    Task : Get List TransID to process Device Transform
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
            - 20201012@Casey.Huynh: Add Trace Performance log
            - 20210510@Aries.Nguyen: Remove insert log dba_SP_PerformanceStats [Redmine ID: #154792]
            - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]  
            - 20240403@Jonathan.Doan: The same AccountID must be in the same batch [Redmine ID: #202878]
            - 20240503@Jonathan.Doan: HF Division by 0 [Redmine ID: #204757]
			- 20240806@Jonathan.Doan: Change data flow v6 [Redmine ID: #206403]
            - 20250909@Jonathan.Doan: Remove FP code [Redmine ID: #236716]

	    Param's Explanation (filtered by):
			CALL DCS_DC_Transform_Device_GetPackage(100, 2);
	*/
    DECLARE 	CONST_SYSTEMSETTINGID_MINTRANSID 			INT 		DEFAULT 1;
    DECLARE 	CONST_SYSTEMSETTINGID_MINCREATEDDATE 		INT 		DEFAULT 2;
	
	DECLARE		lv_TotalRecord			INT UNSIGNED DEFAULT 0;
	DECLARE		lv_RateBatch			DECIMAL(4,2);
    DECLARE 	lv_FromTransID			BIGINT UNSIGNED;
    DECLARE		lv_FromCreatedDate		DATE;
    DECLARE		lv_CountAccountID		INT;
    DECLARE		lv_NoOfBatchOfAccountID	INT;

    DROP TEMPORARY TABLE IF EXISTS Temp_Trans;
    DROP TEMPORARY TABLE IF EXISTS Temp_Account;
    
    CREATE TEMPORARY TABLE Temp_Trans(	
		    TransID		BIGINT	UNSIGNED PRIMARY KEY
		,   RawTransID	BIGINT	UNSIGNED
		,   AccountID	BIGINT	UNSIGNED
		,   BatchID		INT
        ,   CreatedDate	DATE
    );
    
    CREATE TEMPORARY TABLE Temp_Account(	
		    AccountID	BIGINT	UNSIGNED PRIMARY KEY
		,   BatchID		INT
    );
    
	SET lv_TotalRecord 	    	= ip_NoOfTickets*ip_NoOfBatch;
    SET lv_FromTransID 	    	= (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_SYSTEMSETTINGID_MINTRANSID);

    INSERT INTO Temp_Trans(TransID, RawTransID, AccountID, CreatedDate)
	SELECT	TransID
		,   RawTransID
		,   AccountID
		,   CreatedDate
	FROM DCS_DataCenter.Transaction
	WHERE TransID >= lv_FromTransID
	ORDER BY TransID ASC
	LIMIT lv_TotalRecord;
    
    ALTER TABLE Temp_Trans
    ADD KEY IX_Temp_Trans_AccountID (AccountID),
    ADD KEY IX_Temp_Trans_RawTransID (RawTransID);
    
	SET lv_FromTransID = IFNULL((SELECT MIN(TransID) FROM Temp_Trans), lv_FromTransID); 
	SET lv_FromCreatedDate = IFNULL((SELECT MIN(CreatedDate) FROM Temp_Trans), DATE_ADD(CURRENT_TIMESTAMP(), INTERVAL -2 WEEK));
    
    INSERT INTO Temp_Account(AccountID)
	SELECT DISTINCT AccountID
	FROM Temp_Trans;
    
    SET lv_CountAccountID = (SELECT COUNT(1) FROM Temp_Account);
    
	SET @RowId = 0;
    IF(lv_CountAccountID IS NOT NULL AND lv_CountAccountID > 0) THEN
		SET lv_NoOfBatchOfAccountID = CEIL(lv_CountAccountID / ip_NoOfBatch);
    
		UPDATE Temp_Account
		SET BatchID = CEIL(@RowId := @RowId + 1 / lv_NoOfBatchOfAccountID)
		ORDER BY AccountID;
        
        UPDATE Temp_Trans AS tmpT
			INNER JOIN Temp_Account AS tmpA ON tmpA.AccountID = tmpT.AccountID
		SET tmpT.BatchID = tmpA.BatchID;

		IF(lv_FromTransID IS NOT NULL AND lv_FromTransID > 0) THEN
			UPDATE DCS_DataCenter.SystemSetting
			SET VValue = CONCAT('', lv_FromTransID),
				UpdatedTime = CURRENT_TIMESTAMP()
			WHERE ID = CONST_SYSTEMSETTINGID_MINTRANSID;
		END IF;

		IF(lv_FromCreatedDate IS NOT NULL) THEN
			UPDATE DCS_DataCenter.SystemSetting
			SET VValue = CONCAT('', lv_FromCreatedDate),
				UpdatedTime = CURRENT_TIMESTAMP()
			WHERE ID = CONST_SYSTEMSETTINGID_MINCREATEDDATE;
		END IF;
		
		#RETURN OUTPUT
		SELECT  TransID
			,   BatchID
		FROM Temp_Trans;
    END IF;
    
END$$
DELIMITER ;
