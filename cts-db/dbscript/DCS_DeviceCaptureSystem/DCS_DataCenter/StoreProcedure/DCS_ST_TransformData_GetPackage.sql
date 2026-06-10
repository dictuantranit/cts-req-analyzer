/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ST_TransformData_GetPackage`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ST_TransformData_GetPackage` (
        IN ip_IsProcessed   TINYINT
    ,   IN ip_NoOfTickets   INT
    ,   IN ip_NoOfBatch     INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20190730@Casey.Huynh
	    Task : GET Transaction To Transform
	    DB: DCS_RawTransaction(Staging)
	    Original:

	    Revisions:
		    - 20201006@CaseyHuynh: Move New Server Phase 1, Move table RawTransaction from DB "DCS_RawTransaction" to "DCS_DataCenter" [Redmine ID: #143011]
		    - 20201006@Bobby:Move New Server Phase 2, Enhance Performance [Redmine ID: #143011]
			- 20210510@Aries.Nguyen: Remove insert log dba_SP_PerformanceStats [Redmine ID: #154792]
            - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
            
	    Param's Explanation (filtered by):
	*/

	DECLARE		lv_TotalRecord		        INT UNSIGNED DEFAULT 0;
    DECLARE 	lv_FromTransID		        BIGINT UNSIGNED;
    DECLARE		lv_GroupLookup		        VARCHAR(128);
    DECLARE		lv_KeyLookup			    VARCHAR(128);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Transaction; 
    
    CREATE TEMPORARY TABLE Temp_Transaction(		
		    MinTransID			BIGINT UNSIGNED
        ,   MaxTransID			BIGINT UNSIGNED
        ,   BatchCount		    INT
    ) ENGINE = MEMORY; 
	

    SET lv_TotalRecord 	= ip_NoOfTickets*ip_NoOfBatch;
    SET lv_GroupLookup 	= 'DCS_RawTrans_Transform';
    SET lv_KeyLookup	= 'MinRawTransId';
    SET lv_FromTransID 	= IFNULL((SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE VGroup=lv_GroupLookup AND VName=lv_KeyLookup	), 0);

    SET lv_TotalRecord = ip_NoOfTickets * ip_NoOfBatch;
	set @RowId = 0;
    
    INSERT INTO Temp_Transaction (MinTransID, MaxTransID, BatchCount)
    SELECT  MIN(TransID) AS MinTransID
        ,   MAX(TransID) AS MaxTransID
        ,   SUM(1) AS BatchCount
	FROM (
		SELECT	@RowId := @RowId+1
			,   rt.TransID	
			,   CEIL(@RowId/ip_NoOfTickets) as batchID
		FROM 	DCS_DataCenter.RawTransaction AS rt
		WHERE	rt.TransID >= lv_FromTransID
		    AND rt.IsProcessed = ip_IsProcessed
		LIMIT	 lv_TotalRecord
	) AS t
	GROUP BY batchID;
    

    SET lv_FromTransID = IFNULL((SELECT MIN(MinTransID) FROM Temp_Transaction), lv_FromTransID);
    INSERT INTO DCS_DataCenter.SystemSetting (VGroup, VName, VValue, UpdatedTime)
    SELECT  VGroup
        ,   VName
        ,   VValue
        ,   UpdatedTime
    FROM (
        SELECT lv_GroupLookup AS VGroup
		    ,   lv_KeyLookup AS VName
		    ,   CONCAT('', lv_FromTransID) AS VValue
            ,   CURRENT_TIMESTAMP() AS UpdatedTime
	) AS t
	ON DUPLICATE KEY UPDATE  VValue = t.VValue
		                    ,UpdatedTime = t.UpdatedTime;

    
	#RETURN OUTPUT
    SELECT	tmpTT.MinTransID
	    ,   tmpTT.MaxTransID
	FROM Temp_Transaction AS tmpTT;


END$$
DELIMITER ;
