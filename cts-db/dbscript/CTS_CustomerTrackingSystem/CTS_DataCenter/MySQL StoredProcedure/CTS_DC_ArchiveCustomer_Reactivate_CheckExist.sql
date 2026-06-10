/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_ArchiveCustomer_Reactivate_CheckExist`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_ArchiveCustomer_Reactivate_CheckExist`(
        IN ip_CustJson  JSON
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20220713@Aries.Nguyen
		Task :		HotFix Customer NULL CC 
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20220713@Aries.Nguyen: Created [Redmine ID: #175406]
            - 	20230929@Jonas.Huynh: Fix issue reactive customer with wrong category [Redmine ID: #193050]
            - 	20240328@Casey.huynh: Enhance Customer Insert flow [Redmine ID: #198000]
		Param's Explanation (filtered by):	

		Example:
			CALL CTS_DataCenter.CTS_DC_ArchiveCustomer_Reactivate_CheckExist('[{"CustID":98456422,"LogTime":"2023-10-05T03:23:36.293"}]');
	*/
    DECLARE lv_LastArchiveID 	BIGINT UNSIGNED;
    DECLARE lv_CurrentTime 		DATETIME DEFAULT CURRENT_TIMESTAMP();
        
    DROP TEMPORARY TABLE IF EXISTS Temp_Customer;    
	CREATE TEMPORARY TABLE Temp_Customer(	  	
			CustID				BIGINT UNSIGNED PRIMARY KEY
        , 	ReactiveTime		DATETIME
	); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustReactivate;
    CREATE TEMPORARY TABLE 		Temp_CustReactivate (
        	CustID				BIGINT UNSIGNED 
		,	ArchiveID			BIGINT UNSIGNED PRIMARY KEY
        , 	IsProcessDone		BIT DEFAULT(0)
        , 	INDEX IX_Temp_CustReactivate_IsProcessDone(IsProcessDone)
    );        
     
    INSERT IGNORE INTO Temp_Customer(CustID, ReactiveTime)
	SELECT DISTINCT temp.CustID
				, 	temp.ReactiveTime			
	 FROM JSON_TABLE(ip_CustJson,
		"$[*]" COLUMNS(
				CustID 					BIGINT UNSIGNED		PATH "$.CustID"
			, 	ReactiveTime			DATETIME			PATH "$.LogTime"		
		 )) AS 	temp;

	SELECT ParameterValue
	INTO lv_LastArchiveID
	FROM CTS_DataCenter.SystemParameter
	WHERE ParameterID = 45;
    
    INSERT INTO Temp_CustReactivate(ArchiveID, CustID, IsProcessDone)
	SELECT 	arc.ID AS ArchiveID
		,	arc.CustID
        , 	FALSE
	FROM Temp_Customer AS tmp
		INNER JOIN CTS_DataCenter.ArchiveCustomer_CTSCustomer AS arc ON arc.CustID = tmp.CustID AND arc.ID > lv_LastArchiveID AND arc.IsReactivated = 0;
	
    INSERT IGNORE INTO Temp_CustReactivate(ArchiveID, CustID, IsProcessDone)
	SELECT 	DISTINCT r.ID
		, 	r.CustID
        , 	TRUE
	FROM	Temp_Customer AS tmp
		,	LATERAL 
			(
			   SELECT arc.ID, arc.CustID
			   FROM   CTS_DataCenter.ArchiveCustomer_CTSCustomer AS arc
			   WHERE  arc.CustID = tmp.CustID AND arc.CustSubID = 0
			   ORDER BY arc.ID DESC
			   LIMIT  1
			) AS r;
            
	UPDATE CTS_DataCenter.ArchiveCustomer_CTSCustomer AS ar 
		INNER JOIN Temp_Customer AS c ON c.CustID = ar.CustID 
	SET		ar.IsReactivated = 1
		,	ar.ReactivateDate = c.ReactiveTime
    WHERE EXISTS (SELECT 1 FROM Temp_CustReactivate AS tmp WHERE ar.ID = tmp.ArchiveID);
    
    INSERT INTO CTS_DataCenter.ArchiveCustomer_CTSCustomer (ArchivedDate, CustID, CTSCustID, CustSubID, IsReactivated, ReactivateDate, InsertTime)
    SELECT  temp.ReactiveTime
		, 	temp.CustID
		, 	0 AS CTSCustID
		, 	0 AS CustSub
		, 	1 AS IsReactivated
		, 	temp.ReactiveTime
		, 	lv_CurrentTime
    FROM  Temp_Customer AS temp
		LEFT JOIN Temp_CustReactivate AS cr ON cr.CustID = temp.CustID
    WHERE cr.CustID IS NULL;
    
    SELECT 	DISTINCT 
			CustID
    FROM Temp_CustReactivate
    WHERE IsProcessDone = FALSE;
END$$
DELIMITER ;

