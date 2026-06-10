/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_Details_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_Details_Get`(
		IN ip_MatchID 			BIGINT UNSIGNED   
	,	IN ip_LiveIndicator		BOOLEAN   
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetIDList			TEXT
       
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210526@Long.Luu
		Task :		Get Match Monitor Details report
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20210526@Long.Luu: Created [Redmine ID: 152883]
			-	20211213@Casey.Huynh: Enhance MM, Return more data 'Verified Trans List', Remove input Parameter ip_EventDate [Redmine ID: 165606]
            -	20220110@Casey.Huynh: Enhance MM, BetID, Reason [Redmine ID: 166986]
            -	20221027@Casey.Huynh: Update Verify By Reason and Betteam [RedmineID: 179439]
            - 	20221122@Casey.Huynh: Update TotalScore to ScoreDiff [Redmine ID: #179499]
			-	20230109@Casey.Huynh: UpdateSoreDiff [Redmine ID: #182637]
			-	20230105@Casey.Huynh: Enhance Report, Seperate CustID List and TransID List [Redmine ID: #181995]
            - 	20230222@Casey.Huynh: For Merge Reason Group, Return All Trans [Redmine ID: 181995]
            - 	20240829@Casey.Huynh: Handle TicketType Single [Redmine ID: #152883]
            -	20250317@Thomas.Nguyen: Handle list ip_BetID [Redmine ID: #219681]

		Param's Explanation (filtered by):
		
		Example:
			CALL CTS_DC_MatchMonitor_Details_Get(@ip_MatchID:=62357347,@ip_LiveIndicator:=1,@ip_BettypeID:=3,@ip_BetID:=0);

	*/   
    
    DECLARE CONST_TICKETTYPE_SINGLE SMALLINT DEFAULT 1;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_BetID;    
	CREATE TEMPORARY TABLE Temp_BetID( 	  
		BetID		BIGINT PRIMARY KEY
	);

    SET @sql = CONCAT("INSERT INTO Temp_BetID (BetID) VALUES ('", REPLACE(ip_BetIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;

	SELECT 	DISTINCT cus.CTSCustID
        ,	cus.CustID
	FROM   CTS_DataCenter.MatchMonitorDetails AS mmd
		INNER JOIN JSON_TABLE(REPLACE(JSON_ARRAY(mmd.ListCustID), ',', '","'), 
						'$[*]' COLUMNS (CustID BIGINT UNSIGNED PATH '$')
						) js
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON js.CustID = cus.CustID
		INNER JOIN Temp_BetID AS tmpbet ON tmpbet.BetID = mmd.BetID
	WHERE 	mmd.BettypeID = ip_BettypeID
		AND mmd.MatchID = ip_MatchID
		AND mmd.LiveIndicator = ip_LiveIndicator
        AND mmd.TicketType = CONST_TICKETTYPE_SINGLE
	ORDER BY cus.CustID;
	
	SELECT 	js.TransID
		,	mmd.Reason		
        ,	mmd.ID AS GroupID
        ,	mmd.ScoreDiff
	FROM   CTS_DataCenter.MatchMonitorDetails AS mmd
		INNER JOIN JSON_TABLE(REPLACE(JSON_ARRAY(mmd.ListTransID), ',', '","'), 
						'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
						) js
		INNER JOIN Temp_BetID AS tmpbet ON tmpbet.BetID = mmd.BetID
	WHERE 	mmd.BettypeID = ip_BettypeID
		AND mmd.MatchID = ip_MatchID
		AND mmd.LiveIndicator = ip_LiveIndicator
        AND mmd.TicketType = CONST_TICKETTYPE_SINGLE;
    
	SELECT	js.TransID AS VerifiedTransID
	FROM CTS_DataCenter.MatchMonitorDetailsVerifiedTrans AS mdv
		INNER JOIN JSON_TABLE(REPLACE(JSON_ARRAY(mdv.ListTransID), ',', '","'), 
						'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
						) js
		INNER JOIN Temp_BetID AS tmpbet ON tmpbet.BetID = mdv.BetID
	WHERE  	mdv.MatchID = ip_MatchID
		AND mdv.LiveIndicator = ip_LiveIndicator
        AND	mdv.BettypeID = ip_BettypeID
        AND mdv.TicketType = CONST_TICKETTYPE_SINGLE;          
	
END$$
DELIMITER ;
