/*SELECT GroupID, TransID, TransDate, MatchID, SportType, TotalScore,  BettypeID, BetID, CustID, Stake, Betteam, LiveHomeScore, LiveAwayScore, EventDate, EventStatus, KickOffTime, HomeID, AwayID, LeagueID, LeagueName, InsertTime 
FROM CTS_DataCenter.MatchMonitorStagingLive;*/
Init data SportType Column for MatchMonitor on Realease Date
Init data FOR New SportType (Baseketball, E-Sport) Column for MatchMonitor on Realease Date
	--E-posrt
--> Lasttiket --> 


TRUNCATE TABLE MatchMonitor_Log;
TRUNCATE TABLE MatchMonitorStagingLive;
TRUNCATE TABLE MatchMonitorStagingNonLive;
TRUNCATE TABLE MatchMonitor;
TRUNCATE TABLE MatchMonitorDetails;
TRUNCATE TABLE MatchMonitorDetailsVerifiedTrans;

TRUNCATE TABLE MatchMonitor;
TRUNCATE TABLE MatchMonitorDetails;
TRUNCATE TABLE MatchMonitorDetailsVerifiedTrans;

UPDATE CTS_DataCenter.SystemParameter
SET ParameterValue = 0
WHERE ParameterID IN (20,29);

UPDATE CTS_DataCenter.SystemParameter
SET ParameterValue = 0
WHERE ParameterID IN (47,48);

INSERT INTO MatchMonitorStagingLive SELECT * FROM MatchMonitorStagingLive_DevBKData;
INSERT INTO MatchMonitorStagingNonLive SELECT * FROM MatchMonitorStagingNonLive_DevBKData;

SELECT * FROM  MatchMonitor_Log;
SELECT * FROM CTS_DataCenter.SystemParameter WHERE ParameterID IN (20,29,47,48);
;

SELECT * FROM  MatchMonitorStagingLive;
SELECT * FROM  MatchMonitorStagingNonLive;
SELECT * FROM  MatchMonitor WHERE MatchID = 48540999;
SELECT * FROM  MatchMonitorDetails WHERE ListTransID LIKE '%114113780809%';ORDER BY MatchID, LiveIndicator, BettypeID, ;
SELECT * FROM  MatchMonitorDetailsVerifiedTrans; #114113780809
SELECT * FROM  MatchMonitorStagingLive_DevBKData;


SELECT mmd.* FROM  MatchMonitorDetails mmd
INNER JOIN MatchMonitorDetailsVerifiedTrans mmv on mmd.MatchID = mmv.MatchID AND mmd.BettypeID = mmv.BettypeID AND  mmd.BetID = mmv.BetID;
SELECT * FROM  MatchMonitor_Log;
#========================================================================
CALL CTS_DC_MatchMonitor_Rule_Get(1,500,@op_MaxTransID); Select @op_MaxTransID; 114089818550;
CALL CTS_DC_MatchMonitor_Get('2021-12-05','2021-12-05',NULL,'1,2,43', '1','1,2,3,4',NULL,'[{"BettypeID":1,"BetID":0},{"BettypeID":3,"BetID":0},{"BettypeID":7,"BetID":0}]');
CALL CTS_DC_MatchMonitor_Get('2021-12-05','2021-12-08',NULL,'1,2,43', '1','1,2,3,4',NULL,'[{"BettypeID":1,"BetID":0},{"BettypeID":3,"BetID":0},{"BettypeID":7,"BetID":0},{"BettypeID":610,"BetID":801}]');
CALL CTS_DC_MatchMonitor_Get('2021-12-05','2021-12-08',NULL,'1,2,43', '1','1,2,3,4',NULL,'[{"BettypeID":1,"BetID":0},{"BettypeID":3,"BetID":0},{"BettypeID":7,"BetID":0},{"BettypeID":610,"BetID":801}]');

call CTS_DataCenter.CTS_DC_MatchMonitor_Details_Get(48310358, 1, 0, true, 2, '0', '2,3,4');

call CTS_DataCenter.CTS_DC_MatchMonitor_Details_Get(48540999, 610, 801, true, 2, '0', '2,3,4');
SELECT * FROM MatchMonitorDetails WHERE MatchID = 48310358 AND BettypeID = 1 AND BetID = 0 AND LiveIndicator = 1 AND Reason = 2 AND TotalScore = 0 AND GroupID IN (2,3,4);

SELECT * FROM CTS_DataCenter.CTSCustomer WHERE CustID IN (45269436,46460108,45501155,45993745,53793541,55706032,55895790);


CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_Details_Get`(
		IN ip_MatchID 			BIGINT UNSIGNED    
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetID				TINYINT
    ,	IN ip_LiveIndicator		BOOLEAN     
    ,	IN ip_Reason			TINYINT  
    ,	IN ip_ScoreList			VARCHAR(500)     
    ,	IN ip_GroupIDList		VARCHAR(2000)
    
CALL CTS_DC_MatchMonitor_Rule_Process(1,114089818550,48310358,0,1,0);
CALL CTS_DC_MatchMonitor_Rule_Process(1,114089818550,48310358,0,3,0);
CALL CTS_DC_MatchMonitor_Rule_Process(1,114089818550,48310358,0,7,0);
CALL CTS_DC_MatchMonitor_Rule_Process(1,114089818550,48310358,0,8,0);
SET @ip_TransGroup = '[
	{
		"GroupID" : 1,
		"Reason" : 0,
		"TransList" : "114089580761,114089580125,114089579028,114089578459",
		"CustIDList" : "38532149,50849324,58025219,58331619",
		"OldGroupIDList" : "0"
	},
	{
		"GroupID" : 4,
		"Reason" : 2,
		"TransList" : "114089577451,114089577333,114089576830",
		"CustIDList" : "53793541,55706032,55895790",
		"OldGroupIDList" : "0,1"
	}
]
';
CALL CTS_DC_MatchMonitor_Rule_Complete(1,114089818852,48310358,0,1,0,@ip_TransGroup);






#CREATE TABLE MatchMonitorStagingLive_DevBKData SELECT * FROM MatchMonitorStagingLive;
#CREATE TABLE MatchMonitorStagingNonLive_DevBKData SELECT * FROM MatchMonitorStagingNonLive;

/*******1.INSERT STAGING*********************************************************
********************************************************************************/
#-------1.1 INSERT LIVE TICKET
TRUNCATE TABLE MatchMonitorStagingLive;
TRUNCATE TABLE MatchMonitorStagingNonLive;
CALL CTS_DC_MatchMonitor_Staging_Insert(1,'[
	{"GroupID" : 0,"TransID" : 1001,"TransDate" : "2022-01-17 00:00:00.000","MatchID" : 1,"SportType" : 1,"TotalScore" : 1,"Bettype" : 1,"BetID" : 0,"CustID" : 1,"Stake" : 250.0000,"Betteam" : "a","LiveHomeScore" : 1,"LiveAwayScore" : 0,"EventDate" : "2022-01-17","KickOffTime" : "2022-01-17 01:00:00","HomeID" : 5,"AwayID" : 8,"LeagueID" : 8,"LeagueName" : "ABC","EventStatus": "running"}
,	{"GroupID" : 0,"TransID" : 1002,"TransDate" : "2022-01-17 00:25:00.200","MatchID" : 1,"SportType" : 2,"TotalScore" : 1,"Bettype" : 1,"BetID" : 0,"CustID" : 2,"Stake" : 250.0000,"Betteam" : "a","LiveHomeScore" : 1,"LiveAwayScore" : 0,"EventDate" : "2022-01-17","KickOffTime" : "2022-01-17 01:00:00","HomeID" : 5,"AwayID" : 8,"LeagueID" : 8,"LeagueName" : "ABC","EventStatus": "running"}
,	{"GroupID" : 0,"TransID" : 1003,"TransDate" : "2022-01-17 00:26:00.200","MatchID" : 1,"SportType" : 1,"TotalScore" : 1,"Bettype" : 1,"BetID" : 0,"CustID" : 3,"Stake" : 250.0000,"Betteam" : "a","LiveHomeScore" : 1,"LiveAwayScore" : 0,"EventDate" : "2022-01-17","KickOffTime" : "2022-01-17 01:00:00","HomeID" : 5,"AwayID" : 8,"LeagueID" : 8,"LeagueName" : "ABC","EventStatus": "running"}
]');
CALL CTS_DC_MatchMonitor_Staging_Insert(0,'[
	{"GroupID" : 0,"TransID" : 2001,"TransDate" : "2022-01-17 00:00:00.000","MatchID" : 2,"SportType" : 1,"TotalScore" : 1,"Bettype" : 1,"BetID" : 0,"CustID" : 1,"Stake" : 250.0000,"Betteam" : "a","LiveHomeScore" : 1,"LiveAwayScore" : 0,"EventDate" : "2022-01-17","KickOffTime" : "2022-01-17 01:00:00","HomeID" : 5,"AwayID" : 8,"LeagueID" : 8,"LeagueName" : "ABC","EventStatus": "running"}
,	{"GroupID" : 0,"TransID" : 2002,"TransDate" : "2022-01-17 00:25:00.200","MatchID" : 2,"SportType" : 1,"TotalScore" : 1,"Bettype" : 1,"BetID" : 0,"CustID" : 2,"Stake" : 250.0000,"Betteam" : "a","LiveHomeScore" : 1,"LiveAwayScore" : 0,"EventDate" : "2022-01-17","KickOffTime" : "2022-01-17 01:00:00","HomeID" : 5,"AwayID" : 8,"LeagueID" : 8,"LeagueName" : "ABC","EventStatus": "running"}
,	{"GroupID" : 0,"TransID" : 2003,"TransDate" : "2022-01-17 00:26:00.200","MatchID" : 2,"SportType" : 1,"TotalScore" : 1,"Bettype" : 1,"BetID" : 0,"CustID" : 3,"Stake" : 250.0000,"Betteam" : "a","LiveHomeScore" : 1,"LiveAwayScore" : 0,"EventDate" : "2022-01-17","KickOffTime" : "2022-01-17 01:00:00","HomeID" : 5,"AwayID" : 8,"LeagueID" : 8,"LeagueName" : "ABC","EventStatus": "running"}
]');
#-------1.2 INSERT NON-LIVE TICKET
SELECT * FROM  MatchMonitorStagingLive ORDER BY TransDate;
SELECT * FROM  MatchMonitorStagingLive ORDER BY TransID;
SELECT * FROM  MatchMonitorStagingNonLive;

/*******2.MATCH MONITOR RULE****************************************************
********************************************************************************/
UPDATE MatchMonitorStagingLive
SET GroupID = 0;
CALL CTS_DC_MatchMonitor_Rule_Get(1,2,@op_MaxTransID); Select @op_MaxTransID;#114089577333;
CALL CTS_DC_MatchMonitor_Rule_Process(1,114089577333,48310358,0,1,0);
SET @ip_TransGroup = '[
	{
		"GroupID" : 4,
		"Reason" : 0,
		"TransList" : "114089577333,114089576830",
		"CustIDList" : "55706032,55895790",
		"OldGroupIDList" : "0"
	}
]
';
CALL CTS_DC_MatchMonitor_Rule_Complete(1,114089577333,48310358,0,1,0,@ip_TransGroup);
SELECT * FROM  MatchMonitor;
SELECT * FROM  MatchMonitorDetails;
SELECT * FROM  MatchMonitorDetailsVerifiedTrans;
SELECT * FROM MatchMonitorStagingLive WHERE MatchID = 48310358 AND TotalScore= 0 AND BettypeID = 1 AND BETID = 0 ;#AND TransID  114089577333; #55895790,55706032,53793541,14045772
CALL CTS_DC_MatchMonitor_Staging_Clean(1,114089577333);
#>>>>>
CALL CTS_DC_MatchMonitor_Rule_Get(1,500,@op_MaxTransID); Select @op_MaxTransID;#114089818852;
CALL CTS_DC_MatchMonitor_Rule_Process(1,114089818852,48310358,0,1,0);
SET @ip_TransGroup = '[
	{
		"GroupID" : 1,
		"Reason" : 2,
		"TransList" : "114089577451,114089577333,114089576830",
		"CustIDList" : "53793541,55706032,55895790",
		"OldGroupIDList" : "0,1"
	}
]
';
CALL CTS_DC_MatchMonitor_Rule_Complete(1,114089577333,48310358,0,1,0,@ip_TransGroup);
CALL CTS_DC_MatchMonitor_Staging_Clean(1,114089577333);
SELECT * FROM  MatchMonitor;
SELECT * FROM  MatchMonitorDetails;
SELECT * FROM  MatchMonitorDetailsVerifiedTrans;
SELECT * FROM MatchMonitorStagingLive WHERE MatchID = 48310358 AND TotalScore= 0 AND BettypeID = 1 AND BETID = 0 ;#AND TransID  114089577333; #55895790,55706032,53793541,14045772
#----------------------------------------------------------------
CALL CTS_DC_MatchMonitor_Rule_Get(1,500,@op_MaxTransID); Select @op_MaxTransID; 114089818852;
CALL CTS_DC_MatchMonitor_Rule_Process(1,114089818852,48310358,0,1,0);
SET @ip_TransGroup = '[
	{
		"GroupID" : 1,
		"Reason" : 0,
		"TransList" : "114089580761,114089580125,114089579028,114089578459",
		"CustIDList" : "38532149,50849324,58025219,58331619",
		"OldGroupIDList" : "0"
	},
	{
		"GroupID" : 4,
		"Reason" : 2,
		"TransList" : "114089577451,114089577333,114089576830",
		"CustIDList" : "53793541,55706032,55895790",
		"OldGroupIDList" : "0,1"
	}
]
';
CALL CTS_DC_MatchMonitor_Rule_Complete(1,114089818852,48310358,0,1,0,@ip_TransGroup);

TRUNCATE TABLE MatchMonitor;
TRUNCATE TABLE MatchMonitorDetails;
TRUNCATE TABLE MatchMonitorDetailsVerifiedTrans;
SET @ip_TransGroup = '[
	{
		"GroupID" : 1,
		"Reason" : 0,
		"TransList" : "114089580761,114089580125,114089579028,114089578459",
		"CustIDList" : "38532149,50849324,58025219,58331619",
		"OldGroupIDList" : "0"
	},
	{
		"GroupID" : 4,
		"Reason" : 2,
		"TransList" : "114089577451,114089577333,114089576830",
		"CustIDList" : "53793541,55706032,55895790",
		"OldGroupIDList" : "0"
	}
]
';
CALL CTS_DC_MatchMonitor_Rule_Complete(1,114089815538,48310358,0,1,0,@ip_TransGroup);
SELECT * FROM  MatchMonitor;
SELECT * FROM  MatchMonitorDetails;
SELECT * FROM  MatchMonitorDetailsVerifiedTrans;

CALL CTS_DC_MatchMonitor_Staging_Clean(1,114089815538);
SELECT * FROM MatchMonitorStagingLive WHERE TransID <= 114089577333;
SELECT * FROM MatchMonitorStagingLive_DevTest WHERE TransID <= 114089577333;
CALL CTS_DC_MatchMonitor_Staging_Clean(
		IN ip_LiveIndicator BOOLEAN
	,	IN ip_MaxTransID 	BIGINT UNSIGNED
	, 	IN ip_MatchID		INT
    , 	IN ip_TotalScore	TINYINT
    , 	IN ip_BettypeID		INT
    ,	IN ip_BetID			BIGINT
    , 	IN ip_TransGroup	JSON
)
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_Rule_Process`(
		IN ip_LiveIndicator		BOOLEAN
	,	IN ip_MaxTransID		BIGINT UNSIGNED
	,	IN ip_MatchID			INT UNSIGNED
    ,	IN ip_TotalScore		INT UNSIGNED
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetID				BIGINT
	MatchID	TotalScore	BettypeID	BetID
	48310358	0	1	0
	48310358	0	3	0
	48310358	0	7	0
	48310358	0	8	0
/*******3.CLEAN DATA AND UPDATE PARAMETERs**************************************
********************************************************************************/