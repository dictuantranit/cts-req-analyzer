/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transform_Device_GetPackage`;

DELIMITER $$
CREATE DEFINER=`dcsService`@`%` PROCEDURE `DCS_ET_Transform_Device_GetPackage`(
        IN ip_NoOfTickets INT
    ,   IN ip_NoOfBatch INT
)
     SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20200908@Bobby.Nguyen
	    Task : Get List TransID to process Device Transform
	    DB: DCS_Extra
	    Original:

	    Revisions:
            - 20201012@Casey.Huynh: Add Trace Performance log
            - 20210510@Aries.Nguyen: Remove insert log dba_SP_PerformanceStats [Redmine ID: #154792]
            - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]  
			- 2023292023@Casey.Huynh: CTMAX, Velki [RedmineID: #190118]
            
	    Param's Explanation (filtered by):
	*/
	
	DECLARE		lv_TotalRecord		INT UNSIGNED DEFAULT 0;
	DECLARE		lv_RateBatch		DECIMAL(4,2);
    DECLARE 	lv_FromTransID		BIGINT UNSIGNED;
    DECLARE		lv_FromCreatedDate	DATE;
    DECLARE		lv_GroupLookup	    VARCHAR(128);
    DECLARE		lv_KeyLookup		VARCHAR(128);
    DECLARE		lv_Now				DATETIME(3);

    SET lv_Now = CURRENT_TIMESTAMP(3);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Trans;
    CREATE TEMPORARY TABLE Temp_Trans(	
		    TransID		BIGINT	UNSIGNED PRIMARY KEY
		,   BatchID		INT
        ,   CreatedDate	DATE
    ) ENGINE=MEMORY; 
    
	SET lv_RateBatch 		= 1;#MonDB.DCS_f_GetRateBatch();	
    SET ip_NoOfTickets 	    = CEIL(ip_NoOfTickets*lv_RateBatch);
	SET lv_TotalRecord 	    = ip_NoOfTickets*ip_NoOfBatch;
    SET lv_GroupLookup 	    = 'DCS_Device_Transform';
    SET lv_KeyLookup 		= 'MinTransId';
    SET lv_FromTransID 	    = IFNULL((SELECT CAST(VValue AS UNSIGNED) FROM DCS_Extra.SystemSetting WHERE VGroup=lv_GroupLookup AND VName=lv_KeyLookup), 0);
   
	SET @RowId = 0;
    INSERT INTO Temp_Trans (TransID, CreatedDate, BatchID)
    SELECT  TransID
        ,   CreatedDate
        ,   BatchID
    FROM (
		SELECT	@RowId := @RowId + 1
		    ,   ts.TransID
            ,   ts.CreatedDate
		    ,   ceil(@RowId/ip_NoOfTickets) AS BatchID
		FROM DCS_Extra.Transaction AS ts
		WHERE ts.TransId >= lv_FromTransID
		LIMIT lv_TotalRecord
    ) AS t;
	
    SET lv_FromCreatedDate = (SELECT MIN(CreatedDate) FROM Temp_Trans);
    SET lv_FromTransID = (SELECT MIN(TransID) FROM Temp_Trans);
    
    IF EXISTS(SELECT 1 FROM Temp_Trans) THEN 
		# Udpate DCS_Device_Transfor > MinTransId
		UPDATE DCS_Extra.SystemSetting
        SET VValue = lv_FromTransID
			, UpdatedTime = lv_Now
        WHERE ID = 1;
        
        # Udpate DCS_Device_Transfor > MinCreatedDate
		UPDATE DCS_Extra.SystemSetting
        SET VValue = lv_FromCreatedDate
			, UpdatedTime = lv_Now
        WHERE ID = 2; 
    END IF;
    /*
    SET lv_FromTransID = IFNULL((SELECT MIN(TransID) FROM Temp_Trans), lv_FromTransID); 
    SET lv_FromCreatedDate = IFNULL((SELECT MIN(CreatedDate) FROM Temp_Trans), date_add(CURRENT_TIMESTAMP(), INTERVAL -2 WEEK));

    INSERT INTO DCS_Extra.SystemSetting (VGroup, VName, VValue, UpdatedTime)
    SELECT VGroup, VName, VValue, UpdatedTime
    FROM (
        SELECT lv_GroupLookup AS VGroup
		    , lv_KeyLookup AS VName
		    , CONCAT('', lv_FromTransID) AS VValue
            , CURRENT_TIMESTAMP() AS UpdatedTime
	    UNION ALL 

        SELECT  lv_GroupLookup
		    ,   'MinCreatedDate'
		    ,   CONCAT('', lv_FromCreatedDate)
            ,   CURRENT_TIMESTAMP() AS UpdatedTime
	) AS t
	ON DUPLICATE KEY UPDATE  VValue = t.VValue
                           , UpdatedTime = t.UpdatedTime;

    */
    #RETURN OUTPUT
    SELECT  TransID
        ,   BatchID
    FROM Temp_Trans;
    
END$$
DELIMITER ;
