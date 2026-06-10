/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_ValidateManualMultipleInput`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_ValidateManualMultipleInput`(IN ip_UsernameList varchar(2600),IN ip_RootCTSCustID bigint)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200622@Harvey
		Task :		Validation for add manual association muptiple
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20200416@Harvey.Nguyen: Initial [Redmine ID: #136212]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
            
		Param's Explanation:
        
        CALL CTS_DataCenter.CTS_DC_Association_ValidateManualMultipleInput ('',1);
	*/ 

	DROP TEMPORARY TABLE IF EXISTS TempItemTable;
	DROP TEMPORARY TABLE IF EXISTS TempValidateUsername;
	CREATE TEMPORARY TABLE TempValidateUsername( 	 
		UserName			VARCHAR(50)
	,	CTSCustID			BIGINT
    ,	SubscriberID		INT
    ,	IsDuplicated		BOOLEAN		DEFAULT FALSE);
    
    DROP TEMPORARY TABLE IF EXISTS TempUserStatistic;
    CREATE TEMPORARY TABLE TempUserStatistic( 	 
		CTSCustID			BIGINT
    ,	Quantity			INT);
 
    CALL CTS_DC_Sys_SplitStringToTempItemTable(ip_UsernameList,",",'VARCHAR(50)');
    
    INSERT INTO TempValidateUsername(UserName)
    SELECT item FROM TempItemTable;
    
    UPDATE TempValidateUsername tvu
		INNER JOIN CTS_DataCenter.CTSCustomer cust ON tvu.UserName = cust.UserName
    SET tvu.CTSCustID = cust.CTSCustID
	,	tvu.SubscriberID = cust.SubscriberID;
    
    UPDATE TempValidateUsername tvu
		INNER JOIN CTS_DataCenter.AssociationByManual abm 
			ON ((abm.FromCTSCustID = ip_RootCTSCustID AND abm.ToCTSCustID = tvu.CTSCustID)
				OR (abm.FromCTSCustID = tvu.CTSCustID AND abm.ToCTSCustID = ip_RootCTSCustID))
    SET tvu.IsDuplicated = TRUE;    

    INSERT INTO TempUserStatistic (CTSCustID,Quantity)
	SELECT CTSCustID,count(CTSCustID)
		FROM TempValidateUsername
	GROUP BY CTSCustID;

	UPDATE TempValidateUsername tvu
		INNER JOIN TempUserStatistic tus ON tvu.CTSCustID = tus.CTSCustID
	SET tvu.IsDuplicated = TRUE
	WHERE tus.Quantity > 1;
    
    SELECT 	UserName
		,	CTSCustID
		,	SubscriberID
		,	IsDuplicated 
	FROM TempValidateUsername;

END$$	

DELIMITER ;