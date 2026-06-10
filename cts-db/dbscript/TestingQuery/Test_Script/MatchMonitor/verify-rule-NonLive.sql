-- Live: BETWEEN s.KickOffTime <= NOW() <= TIMESTAMPADD(MINUTE, 150, s.KickOffTime ) AND LiveIndicator = 1 
-- Today: s.EventDate = CURDATE() AND s.KickOffTime > NOW()
-- Early: s.EventDate > CURDATE()
-- Closed: ...
USE CTS_DataCenter;
delete from MatchMonitor where matchid = 22081995;
delete from MatchMonitorDetails where matchid = 22081995;
delete from MatchMonitorStagingNonLive where matchid = 22081995;
#==Precondition Data ==========================
select * from CTS_DataCenter.CTSCustomer  
WHERE CustID IN (37144067,37144068,37144070,37144071,37144072,37144073,37144074,37144076,37144077,37144079);
select * from CTS_DataCenter.CTSCustomerClassification  
WHERE CustID IN (37144067,37144068,37144070,37144071,37144072,37144073,37144074,37144076,37144077,37144079);
delete 
from CTS_DataCenter.CTSCustomerClassification  
WHERE CustID IN (37144067,37144068,37144070,37144071,37144072,37144073,37144074,37144076,37144077,37144079);

call CTS_DataCenter.CTS_DC_CustClassification_InsertNormalAccount
('[{"CustId": "37144067","CategoryId":"201","TaggingID":0,"TaggingType":1},
{"CustId": "37144068","CategoryId":"201","TaggingID":0,"TaggingType":1},
{"CustId": "37144070","CategoryId":"201","TaggingID":0,"TaggingType":1},
{"CustId": "37144071","CategoryId":"201","TaggingID":0,"TaggingType":1},
{"CustId": "37144072","CategoryId":"201","TaggingID":0,"TaggingType":1},
{"CustId": "37144073","CategoryId":"201","TaggingID":0,"TaggingType":1},
{"CustId": "37144074","CategoryId":"201","TaggingID":0,"TaggingType":1},
{"CustId": "37144076","CategoryId":"201","TaggingID":0,"TaggingType":1},
{"CustId": "37144077","CategoryId":"201","TaggingID":0,"TaggingType":1},
{"CustId": "37144079","CategoryId":"201","TaggingID":0,"TaggingType":1}
]',@opp);

#==PACK01====================================== PASS
#==Expected: 37144067,37144068 are generated to Group Betting 1 
CALL CTS_DC_MatchMonitor_Staging_Insert(0,'[
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"Bettype" : 1,
		"TransID" : 111880559250,
		"CustID" : 37144067,
		"TransDate" : "2021-11-11 00:00:00.600",
		"Stake" : 250
	},
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"Bettype" : 1,
		"TransID" : 111880559251,
		"CustID" : 37144068,
		"TransDate" : "2021-11-11 00:00:00.700",
		"Stake" : 250
	}
]
');
/*CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144067,37144068');
SELECT  * FROM CTS_DataCenter.Temp_Group;*/
CALL CTS_DC_MatchMonitor_Rule_Get(0,50,@orr); select @orr; -- 111880559251
CALL CTS_DC_MatchMonitor_Rule_Process(0,111880559251,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(0,111880559251,22081995,1,1,'[{"GroupID":1,"IsHedging":0,"TransIDList":"111880559250,111880559251","CustIDList":"37144067,37144068","OldGroupIDList":"0"}]');
CALL CTS_DC_MatchMonitor_Staging_Clean(0,111880559251);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingNonLive where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitor where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails where matchid = 22081995;

#==PACK02================================== PASS
#==Expected: 37144067,37144068,37144070 are generated to Hedging 1  
UPDATE CTS_DataCenter.CTSCustomerClassification  
SET SportGroupID = 0, CategoryID = 53 -- Hedging
WHERE CustID IN (37144068);

CALL CTS_DC_MatchMonitor_Staging_Insert(0,'[
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:03:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559252,
		"CustID" : 37144070,
		"TransDate" : "2021-11-11 00:03:00.500",
		"Stake" : 250
	}
]
');
/*CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144067,37144068,37144070');
SELECT  * FROM CTS_DataCenter.Temp_Group;*/
CALL CTS_DC_MatchMonitor_Rule_Get(0,50,@orr); select @orr; -- 111880559252
CALL CTS_DC_MatchMonitor_Rule_Process(0,111880559252,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(0,111880559252,22081995,1,1,'[{"GroupID":1,"IsHedging":1,"TransIDList":"111880559250,111880559251,111880559252","CustIDList":"37144067,37144068,37144070","OldGroupIDList":"0,1"}]');
CALL CTS_DC_MatchMonitor_Staging_Clean(0,111880559252);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingNonLive where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitor where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails where matchid = 22081995;

#==PACK03================================== PASS
#==Expected: 37144071,37144072 is generated to Group Betting 2
UPDATE CTS_DataCenter.CTSCustomerClassification  
SET SportGroupID = 200, CategoryID = 202 -- Normal Account
WHERE CustID IN (37144067);

CALL CTS_DC_MatchMonitor_Staging_Insert(0,'[
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:07:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559253,
		"CustID" : 37144071,
		"TransDate" : "2021-11-11 00:07:00.800",
		"Stake" : 250
	},
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:07:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559254,
		"CustID" : 37144072,
		"TransDate" : "2021-11-11 00:07:00.900",
		"Stake" : 250
	}
]');
/*CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144071,37144072');
SELECT  * FROM CTS_DataCenter.Temp_Group;*/
CALL CTS_DC_MatchMonitor_Rule_Get(0,50,@orr); select @orr; -- 111880559254
CALL CTS_DC_MatchMonitor_Rule_Process(0,111880559254,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(0,111880559254,22081995,1,1,
'[{"GroupID":1,"IsHedging":1,"TransIDList":"111880559250,111880559251,111880559252","CustIDList":"37144067,37144068,37144070","OldGroupIDList":"1"},
{"GroupID":2,"IsHedging":0,"TransIDList":"111880559253,111880559254","CustIDList":"37144071,37144072","OldGroupIDList":"0"}
]');
CALL CTS_DC_MatchMonitor_Staging_Clean(0,111880559254);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingNonLive where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitor where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails where matchid = 22081995;

#==PACK04================================== PASS
#==Expected: 37144071,37144072,37144073 is generated to Group Betting 2
UPDATE CTS_DataCenter.CTSCustomerClassification  
SET SportGroupID = 0, CategoryID = 53 -- Hedging
WHERE CustID IN (37144067);

CALL CTS_DC_MatchMonitor_Staging_Insert(0,'[
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:08:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559255,
		"CustID" : 37144073,
		"TransDate" : "2021-11-11 00:08:00.200",
		"Stake" : 250
	}
]
');
/*CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144071,37144072,37144073');
SELECT  * FROM CTS_DataCenter.Temp_Group;*/
CALL CTS_DC_MatchMonitor_Rule_Get(0,50,@orr); select @orr; -- 111880559255
CALL CTS_DC_MatchMonitor_Rule_Process(0,111880559255,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(0,111880559255,22081995,1,1,'[{"GroupID":1,"IsHedging":0,"TransIDList":"111880559253,111880559254,111880559255","CustIDList":"37144071,37144072,37144073","OldGroupIDList":"0,2"}]');
CALL CTS_DC_MatchMonitor_Staging_Clean(0,111880559255);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingNonLive where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitor where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails where matchid = 22081995;

#==PACK05================================== PASS 
#==Expected: 37144071,37144072,37144073,37144074 is generated to Hedging 2
UPDATE CTS_DataCenter.CTSCustomerClassification  
SET SportGroupID = 0,	CategoryID = 53 -- Hedging
WHERE CustID IN (37144071);

CALL CTS_DC_MatchMonitor_Staging_Insert(0,'[
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:10:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559256,
		"CustID" : 37144074,
		"TransDate" : "2021-11-11 00:10:00.100",
		"Stake" : 250
	}
]');
/*CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144071,37144072,37144073,37144074');
SELECT  * FROM CTS_DataCenter.Temp_Group;*/
CALL CTS_DC_MatchMonitor_Rule_Get(0,50,@orr); select @orr; -- 111880559256
CALL CTS_DC_MatchMonitor_Rule_Process(0,111880559256,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(0,111880559256,22081995,1,1,'[{"GroupID":1,"IsHedging":1,"TransIDList":"111880559253,111880559254,111880559255,111880559256","CustIDList":"37144071,37144072,37144073,37144074","OldGroupIDList":"0,2"}]');
CALL CTS_DC_MatchMonitor_Staging_Clean(0,111880559256);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingNonLive where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitor where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails where matchid = 22081995;

#==PACK06================================== PASS
#==Expected: 37144074,37144076 are generated to Group Betting 3 - 37144077 is not generated any group. (2 ticket with stake = 500)
CALL CTS_DC_MatchMonitor_Staging_Insert(0,'[
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:20:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559257,
		"CustID" : 37144074,
		"TransDate" : "2021-11-11 00:20:00.200",
		"Stake" : 250
	},
    {
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:20:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559258,
		"CustID" : 37144076,
		"TransDate" : "2021-11-11 00:20:00.200",
		"Stake" : 250
	},
    {
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:25:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559259,
		"CustID" : 37144077,
		"TransDate" : "2021-11-11 00:25:00.200",
		"Stake" : 250
	},
    {
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-11 00:26:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-11",
		"LiveIndicator" : "0",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559260,
		"CustID" : 37144077,
		"TransDate" : "2021-11-11 00:26:00.200",
		"Stake" : 250
	}
]');
/*CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144074,37144076,37144077');
SELECT  * FROM CTS_DataCenter.Temp_Group;*/
CALL CTS_DC_MatchMonitor_Rule_Get(0,50,@orr); select @orr; -- 111880559260
CALL CTS_DC_MatchMonitor_Rule_Process(0,111880559260,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(0,111880559260,22081995,1,1,'[
{"GroupID":1,"IsHedging":1,"TransIDList":"111880559253,111880559254,111880559255,111880559256","CustIDList":"37144071,37144072,37144073,37144074","OldGroupIDList":"2"},
{"GroupID":2,"IsHedging":0,"TransIDList":"111880559257,111880559258","CustIDList":"37144074,37144076","OldGroupIDList":"0"}
]');
CALL CTS_DC_MatchMonitor_Staging_Clean(0,111880559260);

SELECT * FROM CTS_DataCenter.SystemParameter where ParameterID IN (29, 48);
SELECT * FROM CTS_DataCenter.MatchMonitorStagingNonLive where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitor where matchid = 22081995;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails where matchid = 22081995;