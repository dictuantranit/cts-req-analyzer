/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_GetByCTSCustIDs`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetByCTSCustIDs`(
		IN ip_CTSCustIDList TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200820@Long.Luu
		Task :		Get Associated Customers from CustIDList
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20200820@Long.Luu: Created [Redmine ID: #139701]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: #148723]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
			- 20210823@Aries.Nguyen: Enhannce  Affected Evidence flow [Redmine ID: #160470]
		
		Param's Explanation (filtered by):
	*/
    
    DROP TEMPORARY TABLE IF EXISTS   Temp_AssociatedException;
    CREATE TEMPORARY TABLE Temp_AssociatedException(
			FromCTSCustID 	BIGINT UNSIGNED
        ,	ToCTSCustID 	BIGINT UNSIGNED
        , 	PRIMARY KEY		PK_Temp_AssociatedException_FromCTSCustID_ToCTSCustID(FromCTSCustID,ToCTSCustID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_Association;
    CREATE TEMPORARY TABLE Temp_Association(
			CTSCustID 		BIGINT UNSIGNED
		,	CTSCustID_Aff	BIGINT UNSIGNED
		,	PRIMARY KEY(CTSCustID,CTSCustID_Aff)
	);
 
	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustIDs;
    CREATE TEMPORARY TABLE Temp_CTSCustIDs (
			CTSCustID 		BIGINT UNSIGNED PRIMARY KEY
    );
    
	SET @sql = CONCAT("INSERT INTO Temp_CTSCustIDs (CTSCustID) VALUES ('", REPLACE(ip_CTSCustIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    

	INSERT IGNORE INTO Temp_Association(CTSCustID, CTSCustID_Aff)
	SELECT cust.CTSCustID, ass.CTSCustID AS CTSCustID_Aff
	FROM Temp_CTSCustIDs AS cust
		INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON  cust.CTSCustID = dv.CTSCustID
		INNER JOIN CTS_DataCenter.AssociationByDevice AS ass ON ass.DCSDeviceID = dv.DCSDeviceID AND ass.CTSCustID <> dv.CTSCustID;
	
	INSERT INTO Temp_AssociatedException(FromCTSCustID, ToCTSCustID)
    SELECT	ex.FromCTSCustID
		,	ex.ToCTSCustID
    FROM CTS_DataCenter.AssociationRemove AS ex
		INNER JOIN Temp_Association AS aff ON ex.FromCTSCustID = aff.CTSCustID_Aff AND ex.ToCTSCustID = aff.CTSCustID;
    
    INSERT INTO Temp_AssociatedException(FromCTSCustID, ToCTSCustID)
    SELECT	ex.FromCTSCustID
		,	ex.ToCTSCustID
    FROM CTS_DataCenter.AssociationRemove AS ex
		INNER JOIN Temp_Association AS aff ON ex.FromCTSCustID = aff.CTSCustID AND ex.ToCTSCustID = aff.CTSCustID_Aff;
    
    DELETE 
    FROM Temp_Association AS aff
    WHERE EXISTS (SELECT 1 FROM Temp_AssociatedException AS ex WHERE ex.FromCTSCustID = aff.CTSCustID AND ex.ToCTSCustID = aff.CTSCustID_Aff);
    
    DELETE 
    FROM Temp_Association AS aff
    WHERE EXISTS (SELECT 1 FROM Temp_AssociatedException AS ex WHERE ex.FromCTSCustID = aff.CTSCustID_Aff AND ex.ToCTSCustID = aff.CTSCustID);


	# Get associated accounts
    SELECT DISTINCT cust.CustID
	FROM Temp_Association AS ass      
        INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON ass.CTSCustID_Aff = cust.CTSCustID;
 
    
END$$
DELIMITER ;