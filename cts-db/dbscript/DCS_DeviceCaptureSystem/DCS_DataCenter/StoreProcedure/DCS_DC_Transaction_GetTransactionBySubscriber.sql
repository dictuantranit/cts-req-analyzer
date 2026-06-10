/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transaction_GetTransactionBySubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transaction_GetTransactionBySubscriber`(
		IN	ip_SubscriberID	INT	
    ,	IN	ip_TransID		BIGINT
    ,	IN	ip_BatchSize 	INT
    )
    SQL SECURITY INVOKER
proc_label: BEGIN
	/*
		Created:	20240611@Terry.Nguyen
		Task:		Get history transaction by date and subscriber [Redmine ID: 206262]
		DB:			DCS_DataCenter
		Original:

		Revisions:
		- 20240611@Terry.Nguyen: 		Initial [Redmine ID: #206262]	           
		- 20240820@Lando.Vu: 			Add Output AccountID [RedmineID: #209435]
        
        Param's Explanation (filtered by):

		Example:
			CALL DCS_DC_Transaction_GetTransactionBySubscriber(@ip_SubscriberID:=2,@ip_TransID:=1234,@ip_BatchSize:=100); 			
            
	*/ 
	
    #================================================================
	DROP TEMPORARY TABLE IF EXISTS Temp_Flagged;
	CREATE TEMPORARY TABLE Temp_Flagged(
			Flagged 	SMALLINT PRIMARY KEY
        ,	DisplayName VARCHAR(200)
	);
    
    INSERT INTO Temp_Flagged(Flagged, DisplayName)
    SELECT	stl.ItemID
		,	stl.ItemName
    FROM DCS_DataCenter.StaticList AS stl
    WHERE stl.ListID = 1;
	#================================================================
     
    SELECT 		tmp.TransID			AS TransID
			,	tmp.TransTime		AS TransTime			
			,	ip_SubscriberID		AS SubscriberID						
			,	tmp.LoginName		AS UserName
            , 	tmp.AccountID		AS AccountID
			,	tmp.FirstDeviceCode	AS FirstDeviceCode
			,	tmp.Action			AS Action
			,	tmp.ActionResult	AS ActionResult
			,	tmp.OS				AS OS
			,	tmp.Browser			AS Browser
			,	tmp.URLDetails		AS URLDetails
			,	tmp.IP				AS IP
            ,	tmp.DisplayName		AS RobotTracking            
		FROM	(
				SELECT 	trs.TransTime                   
					,	trs.TransID
					,	trs.LoginName                   
                    ,	trs.AccountID
					,	trs.FirstDeviceCode
					,	ar.Action
					,	ar.ActionResult
					,	uag.OS
					,	uag.Browser
					,	ur.URLDetails
					,	trs.IP
                    ,	tmpFg.DisplayName                   
				FROM	DCS_DataCenter.Transaction07 AS trs 				
					LEFT JOIN DCS_DataCenter.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
					LEFT JOIN DCS_DataCenter.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
					LEFT JOIN DCS_DataCenter.URL AS ur ON trs.URLID = ur.URLID
                    LEFT JOIN Temp_Flagged AS tmpFg ON trs.Flagged = tmpFg.Flagged
				WHERE trs.TransID > ip_TransID
					AND trs.SubscriberID = ip_SubscriberID
				) AS tmp
			ORDER BY TransID ASC
            LIMIT ip_BatchSize;    
    
END$$

DELIMITER ;
