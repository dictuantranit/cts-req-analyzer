/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBRawTransaction_GetPackage`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBRawTransaction_GetPackage` (
        IN ip_NoOfTickets   INT
    ,   IN ip_NoOfBatch     INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20241121@Jonathan.Doan
	    Task : GET MBRawTransactionID By Batch
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20241121@Jonathan.Doan: Transform to MBTransaction [Redmine ID: #213401]
            
	    Param's Explanation (filtered by):
			CALL DCS_DC_Transform_MBRawTransaction_GetPackage(2,2);
	*/
	DECLARE	lv_TotalRecord	INT UNSIGNED DEFAULT 0;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Transaction; 
    
    CREATE TEMPORARY TABLE Temp_Transaction(
		    MinTransID			BIGINT UNSIGNED
        ,   MaxTransID			BIGINT UNSIGNED
    );
	
    SET lv_TotalRecord = ip_NoOfTickets * ip_NoOfBatch;
	SET @RowId = 0;
    
    INSERT INTO Temp_Transaction (MinTransID, MaxTransID)
    SELECT  MIN(ID) AS MinTransID
        ,   MAX(ID) AS MaxTransID
	FROM (
		SELECT	@RowId := @RowId+1
			,   ID	
			,   CEIL(@RowId/ip_NoOfTickets) as batchID
		FROM DCS_DataCenter.MBRawTransaction
        ORDER BY ID ASC
		LIMIT lv_TotalRecord
	) AS t
	GROUP BY batchID;
    
    /*****RETURN OUTPUT****************************************************/
    SELECT	MinTransID
	    ,   MaxTransID
	FROM Temp_Transaction;

END$$
DELIMITER ;
