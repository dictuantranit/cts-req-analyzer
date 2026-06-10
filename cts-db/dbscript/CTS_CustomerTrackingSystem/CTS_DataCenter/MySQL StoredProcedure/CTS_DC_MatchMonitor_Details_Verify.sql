/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_Details_Verify`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_Details_Verify`(
		IN ip_MatchID 		BIGINT UNSIGNED   
    ,	IN ip_LiveIndicator	BOOLEAN      
    ,	IN ip_BettypeID		INT UNSIGNED
    ,	IN ip_BetID			BIGINT
	,	IN ip_VerifiedBy	INT
    ,	IN ip_ListTransID	LONGTEXT
    ,	IN ip_TicketType	SMALLINT
)
    SQL SECURITY INVOKER
BEGIN
	/*Created:	20211213@Casey.Huynh
	Task :		Match Monitor Insert trans ticket to Staging table
	DB:			CTS_DataCenter
	Original:

	Revisions:
		- 	20211213@Casey.Huynh: Created [Redmine ID: 165606]
        -	20220110@Casey.Huynh: Enhance MM, Add BetID [RedmineID: 166986]
        -	20221027@Casey.Huynh: Update Verify By Reason and Betteam [RedmineID: 179427]
        -	20221027@Casey.Huynh: Seperate pool Staging [RedmineID: 179439]
        -	20230105@Casey.Huynh: Remove Reason [Redmine ID: #181995]
		- 	20240829@Casey.Huynh: Handle TicketType (Single or Parlay) [Redmine ID: #152883]
        
	Param's Explanation (filtered by):	

	Example: 
		CALL CTS_DC_MatchMonitor_Details_Verify(48995415,1,1,0,8,'114438088476,114438095417,114438086185,114438086589,114438089247,114438086605,114438088231,114438099765,114438099145,114438100783,114438100789');
	*/ 
	
    INSERT INTO CTS_DataCenter.MatchMonitorDetailsVerifiedTrans(MatchID, LiveIndicator, BettypeID, BetID, ListTransID, VerifiedBy, VerifiedDate, TicketType)
    VALUES (ip_MatchID, ip_LiveIndicator, ip_BettypeID, ip_BetID, ip_ListTransID, ip_VerifiedBy, CURRENT_TIME(), ip_TicketType);	   
	
END$$
DELIMITER ;