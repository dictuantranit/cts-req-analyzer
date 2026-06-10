SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

#***Step08********************************
CALL CTS_Adhoc.CTMAX_GetDeviceFingerprint();

#***Step07********************************
CALL CTS_Adhoc.CTMAX_GetDeviceCode();

#***Step06********************************
CALL CTS_Adhoc.CTMAX_GetDevice();

#***Step05********************************
INSERT INTO CTS_Adhoc.csCTMax_CTSCustomer_bk
SELECT 	*
FROM 	CTS_DataCenter.CTSCustomer
WHERE	SubscriberID IN (2328, 2367);

#***Step04********************************
CALL CTS_Adhoc.CTMAX_GetDCSAssociationByDevice();

#***Step03********************************
CALL CTS_Adhoc.CTMAX_GetWrongMappingSub();

INSERT INTO CTS_Adhoc.csCTMax_CustDCSAccount_bk
SELECT 	*, NULL AS cusSubscriberID, NULL AS IssueType
FROM 	CTS_DataCenter.CustDCSAccount
WHERE	SubscriberID IN (2328, 2367);

#***Step02********************************
CALL  CTS_Adhoc.CTMAX_GetDCSAssociation();

#***Step01********************************
INSERT INTO CTS_Adhoc.csCTMax_Account_bk
SELECT 	*, 0 AS IssueType
FROM 	DCS_DataCenter.Account
WHERE	SubscriberID IN (2328, 2367); 