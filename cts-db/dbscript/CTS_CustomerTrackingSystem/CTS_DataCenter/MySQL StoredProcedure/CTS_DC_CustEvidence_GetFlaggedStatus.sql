/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustEvidence_GetFlaggedStatus`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_GetFlaggedStatus`(
		IN ip_CTSCustJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20191225@Casey.Huynh	
		Task :		Return flagged tag associated account list
		DB:			CTS_DataCenter
		Original:	
		Revisions:
			- 20200619@Harvey: remove BLACKFLAGGED for evidence 100
            - 20200707@Lex: fix wrong tagged info return [Redmine ID: #137055]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210622@Aries.Nguyen: Update coding convention and improve locking [Redmine ID: #157203]
		Param's Explanation (filtered by):
		Example:
			- CALL CTS_DC_CustEvidence_GetFlaggedStatus('[{"CTSCustId":47265619,"SubscriberId":162},{"CTSCustId":47606477,"SubscriberId":4423},{"CTSCustId":48923081,"SubscriberId":4423}]');
	*/
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomer;
    CREATE TEMPORARY TABLE Temp_CTSCustomer(
			CTSCustID		BIGINT UNSIGNED
		,	SubscriberID	INT
        ,	INDEX 			IX_Temp_CTSCustomer_CTSCustID(CTSCustID)
    );
     
    INSERT INTO Temp_CTSCustomer(CTSCustID, SubscriberID)
	SELECT	tmpCust.CTSCustID
		,	tmpCust.SubscriberID
	FROM JSON_TABLE(ip_CTSCustJson, 
		"$[*]" COLUMNS(
				CTSCustID		BIGINT UNSIGNED		PATH "$.CTSCustId"         
			,	SubscriberID	INT					PATH "$.SubscriberId"
		)
	) AS  tmpCust;
    
	SELECT 	CTSCustID
		,	SubscriberID
        ,	IFNULL((SELECT 1 
				   FROM CTS_DataCenter.CustEvidence AS ev USE INDEX (IX_CustEvidence_Level_CTSCustID)
				   WHERE ev.CTSCustID = cus.CTSCustID AND ev.Level = 0
						AND NOT EXISTS (SELECT 1 
										FROM CTS_DataCenter.CustRetractEvidence AS re 
										WHERE re.CTSCustID = ev.CTSCustID 
											AND re.EvidenceID = ev.EvidenceID) 
										LIMIT 1),0) AS IsFlagged
		,	IFNULL((SELECT 1 
				    FROM CTS_DataCenter.CustEvidence AS ev USE INDEX (IX_CustEvidence_Level_CTSCustID)
				    WHERE ev.CTSCustID = cus.CTSCustID AND ev.Level = 2
						AND NOT EXISTS (SELECT 1 
										FROM CTS_DataCenter.CustRetractEvidence AS re 
										WHERE re.CTSCustID = ev.CTSCustID 
											AND re.EvidenceID = ev.EvidenceID) 
										LIMIT 1),0) AS IsAffected
    FROM Temp_CTSCustomer AS cus;
 
END$$

DELIMITER ;

