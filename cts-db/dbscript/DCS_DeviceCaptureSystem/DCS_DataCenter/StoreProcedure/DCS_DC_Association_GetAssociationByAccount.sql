/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Association_GetAssociationByAccount`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Association_GetAssociationByAccount`(
		IN	ip_SubscriberID	INT	    
    ,	IN	ip_AccountName	VARCHAR(100)
    )
    SQL SECURITY INVOKER
proc_label: BEGIN
	/*
		Created:	20240611@Terry.Nguyen
		Task:		Get association by Account and Subscriber [Redmine ID: 206262]
		DB:			DCS_DataCenter
		Original:

		Revisions:
		- 20240611@Terry.Nguyen: 		Initial [Redmine ID: #206262]	
		- 20240702@Terry.Nguyen:		Get Min Create Time for First Seen Date	[Redmine ID: #206262]
		
        Param's Explanation (filtered by):

		Example:
			CALL DCS_DC_Association_GetAssociationByAccount(@ip_SubscriberID:=2,@ip_AccountName:='xxxx'); 			
            
	*/ 	   
     
	DROP TEMPORARY TABLE IF EXISTS Temp_Association;
	CREATE TEMPORARY TABLE Temp_Association(					
			AccountID	BIGINT UNSIGNED
        ,	DeviceID	BIGINT 
        ,	CreatedTime	DATETIME(4)
        ,	AssociationID BIGINT UNSIGNED
        
        ,	PRIMARY KEY PK_Temp_Association(DeviceID, AccountID)        
        ,	INDEX IX_Temp_Association_AssociationID(AssociationID)
    ); 
    
    INSERT INTO Temp_Association(AccountID, DeviceID, CreatedTime, AssociationID)
    SELECT	acc.AccountID
        ,	ass.DeviceID
        ,	ass.CreatedTime
        ,	ass.AssociationID
	FROM DCS_DataCenter.Account AS acc 
        INNER JOIN DCS_DataCenter.Association AS ass ON acc.AccountID = ass.AccountID 
    WHERE acc.SubscriberID = ip_SubscriberID AND acc.LoginName = ip_AccountName; 
     
     SELECT tmpAss.DeviceID
		,	dv.FirstDeviceCode AS Device
        , 	MIN(dv.CreatedTime) AS FirstSeenDate
	FROM Temp_Association tmpAss 
		INNER JOIN DCS_DataCenter.Device AS dv ON dv.DeviceID = tmpAss.DeviceID
	GROUP BY 	tmpAss.DeviceID
			,	dv.FirstDeviceCode 
    ORDER BY FirstSeenDate ASC;

	SELECT acc.AccountID
		, 	acc.LoginName AS Account
        , 	MIN(ass.CreatedTime) AS FirstAssociationDate
	FROM Temp_Association tmpAss
		INNER JOIN DCS_DataCenter.Association AS ass ON tmpAss.DeviceID = ass.DeviceID AND ass.AccountID <> tmpAss.AccountID AND ass.SubscriberID = ip_SubscriberID
		INNER JOIN DCS_DataCenter.Account AS acc ON acc.AccountID = ass.AccountID
	GROUP BY	acc.AccountID
			,	acc.LoginName
    ORDER BY FirstAssociationDate ASC;    
     
    
END$$

DELIMITER ;
