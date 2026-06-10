/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitorParlay_Details_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitorParlay_Details_Get`(
		IN ip_MatchID 			BIGINT UNSIGNED   
	,	IN ip_LiveIndicator		BOOLEAN   
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetID				BIGINT       
)
    SQL SECURITY INVOKER
BEGIN

		/*
		Created:	20240830@Casey.Huynh
		Task :		Match Monitor Parlay Details Get Supicious Ticket
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20240830@Casey.Huynh: Created [Redmine ID: 207397]
            
		Param's Explanation (filtered by):
		
		Example:
			CALL CTS_DC_MatchMonitorParlay_Details_Get_xtest(@ip_MatchID:=83679714,@ip_LiveIndicator:=0,@ip_BettypeID:=3,@ip_BetID:=0);

	*/   
    
    DECLARE CONST_TICKETTYPE_PARLAY SMALLINT DEFAULT 2;
    
	SELECT 	DISTINCT cus.CTSCustID
        ,	cus.CustID
	FROM   CTS_DataCenter.MatchMonitorDetails AS mmd
		JOIN JSON_TABLE(REPLACE(JSON_ARRAY(mmd.ListCustID), ',', '","'), 
						'$[*]' COLUMNS (CustID BIGINT UNSIGNED PATH '$')
						) js
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON js.CustID = cus.CustID
	WHERE 	mmd.BettypeID = ip_BettypeID
		AND mmd.BetID = ip_BetID
		AND mmd.MatchID = ip_MatchID
		AND mmd.LiveIndicator = ip_LiveIndicator
        AND mmd.TicketType = CONST_TICKETTYPE_PARLAY
	ORDER BY cus.CustID;
	
	SELECT 	js.Refno
		,	mmd.Reason		
        ,	mmd.ID AS GroupID
        ,	mmd.ScoreDiff
	FROM   CTS_DataCenter.MatchMonitorDetails AS mmd
		JOIN JSON_TABLE(REPLACE(JSON_ARRAY(mmd.ListRefno), ',', '","'), 
						'$[*]' COLUMNS (Refno BIGINT UNSIGNED PATH '$')
						) js
	WHERE 	mmd.BettypeID = ip_BettypeID
		AND mmd.BetID = ip_BetID
		AND mmd.MatchID = ip_MatchID
		AND mmd.LiveIndicator = ip_LiveIndicator
        AND mmd.TicketType = CONST_TICKETTYPE_PARLAY;

    WITH CTE_MainTrans AS(
    SELECT	js.TransID
	FROM   CTS_DataCenter.MatchMonitorDetails AS mmd
		JOIN JSON_TABLE(REPLACE(JSON_ARRAY(mmd.ListTransID), ',', '","'), 
						'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
						) js
	WHERE 	mmd.BettypeID = ip_BettypeID
		AND mmd.BetID = ip_BetID
		AND mmd.MatchID = ip_MatchID
		AND mmd.LiveIndicator = ip_LiveIndicator
        AND mmd.TicketType = CONST_TICKETTYPE_PARLAY) 
    SELECT cte.TransID AS VerifiedTransID
    FROM CTE_MainTrans AS cte 
    INNER JOIN (SELECT DISTINCT js.TransID
				FROM CTS_DataCenter.MatchMonitorDetailsVerifiedTrans AS mdv 
				JOIN JSON_TABLE(REPLACE(JSON_ARRAY(mdv.ListTransID), ',', '","'), 
						'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
						
					) js
				WHERE  mdv.TicketType = CONST_TICKETTYPE_PARLAY) AS vf ON vf.TransID = cte.TransID
	;   
	
END$$
DELIMITER ;