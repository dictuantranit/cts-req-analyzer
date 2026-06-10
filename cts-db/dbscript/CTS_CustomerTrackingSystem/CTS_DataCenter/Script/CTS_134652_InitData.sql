
/*
	Created:	20200706@Long.Luu
	Task:		Init Data [Redmine ID: #134652]
	DB:			CTS_DataCenter
	Original:

	Revisions:
		- 20200706@Long.Luu: Created [Redmine ID: #134652]
	
	Param's Explanation (filtered by):
*/

INSERT INTO CTS_Admin.LogType(LogTypeName, LogTypeDescription)
VALUES ('Insert Associated Account Monitor','Insert Associated Account Monitor');

INSERT INTO CTS_Admin.LogType(LogTypeName, LogTypeDescription)
VALUES ('Delete Associated Account Monitor','Delete Associated Account Monitor');

INSERT INTO CTS_DataCenter.SystemParameter(ParameterID, ParameterName, ParameterDesc, ParameterDataType, ParameterValue)
SELECT 1, 'LastScannedNewAssociation', 'Keep the last scanned AssociationID from AssociationByDevice table', 'BIGINT UNSIGNED', CAST(MAX(a.CTSAssDevID) AS CHAR)
FROM CTS_DataCenter.AssociationByDevice AS a;

INSERT INTO CTS_DataCenter.SystemParameter(ParameterID, ParameterName, ParameterDesc, ParameterDataType, ParameterValue)
VALUES (2, 'LastScannedProblemAccount', 'Keep the last scanned time of getting problem accounts', 'DATETIME', CAST(NOW() AS CHAR));
/*
INSERT INTO CTS_DataCenter.CTSUserNotificationParameter(UserID,FromNewAssID,ToNewAssID)
SELECT 229, MAX(a.CTSAssDevID), MAX(a.CTSAssDevID)
FROM CTS_DataCenter.AssociationByDevice AS a;
*/