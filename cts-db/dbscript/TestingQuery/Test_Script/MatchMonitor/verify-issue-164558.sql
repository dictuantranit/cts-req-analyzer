update CTS_DataCenter.SystemParameter set ParameterValue = 0 where ParameterID in (20,29,47,48);
-- Live: BETWEEN s.KickOffTime <= NOW() <= TIMESTAMPADD(MINUTE, 150, s.KickOffTime ) AND LiveIndicator = 1 
-- Today: s.EventDate = CURDATE() AND s.KickOffTime > NOW()
-- Early: s.EventDate > CURDATE()
-- Closed: ...
USE CTS_DataCenter;
delete from MatchMonitor;
delete from MatchMonitorDetails;
delete from MatchMonitorStagingLive;

#==PACK01====================================== PASS
#==Expected: Trans01, Trans02 are generated to Group Betting 1 
CALL CTS_DC_MatchMonitor_Staging_Insert(1,'[
	{	"TransDate" : "2021-11-09 20:57:56.000",
		"CustID" : 37144067,
		"TransID" : 111880559250,
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"Bettype" : 1,
		"Stake" : 250
	},
	{
		"TransDate" : "2021-11-09 20:59:18.700",
		"CustID" : 37144068,
        "TransID" : 111880559251,
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"Bettype" : 1,
		"Stake" : 250
	}
]
');
CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144067,37144068');
SELECT  * FROM CTS_DataCenter.Temp_Group;
CALL CTS_DC_MatchMonitor_Rule_Get(1,50,@orr); select @orr; -- 111880559251
CALL CTS_DC_MatchMonitor_Rule_Process(1,111880559251,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(1,111880559251,22081995,1,1,'[{"GroupID":1,"IsHedging":0,"TransIDList":"111880559250,111880559251","CustIDList":"37144067,37144068","OldGroupIDList":"0"}]');
CALL CTS_DC_MatchMonitor_Staging_Clean(1,111880559251);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingLive;
SELECT * FROM CTS_DataCenter.MatchMonitor;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails;

#==PACK02================================== PASS
#==Expected: Trans01, Trans02, Trans03 are generated to Group Betting 1 
CALL CTS_DC_MatchMonitor_Staging_Insert(1,'[
	{	
		"TransDate" : "2021-11-09 21:00:40.500",
		"CustID" : 37144068,
        "TransID" : 111880559252,
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"Stake" : 250
	}
]
');
CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144067,37144068');
SELECT  * FROM CTS_DataCenter.Temp_Group;
CALL CTS_DC_MatchMonitor_Rule_Get(1,50,@orr); select @orr; -- 111880559252
CALL CTS_DC_MatchMonitor_Rule_Process(1,111880559252,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(1,111880559252,22081995,1,1,'[{"GroupID":1,"IsHedging":0,"TransIDList":"111880559250,111880559251,111880559252","CustIDList":"37144067,37144068","OldGroupIDList":"0,1"}]');
CALL CTS_DC_MatchMonitor_Staging_Clean(1,111880559252);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingLive;
SELECT * FROM CTS_DataCenter.MatchMonitor;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails;

#==PACK03================================== PASS
#==Expected: Trans01, Trans02, Trans03, Trans04, Trans05 are generated to Group Betting 1 
CALL CTS_DC_MatchMonitor_Staging_Insert(1,'[
	{	
		"TransDate" : "2021-11-09 21:03:16.800",
		"CustID" : 37144068,
        "TransID" : 111880559253,
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"Stake" : 250
	},
	{	
		"TransDate" : "2021-11-09 21:03:21.900",
		"CustID" : 37144068,
        "TransID" : 111880559254,
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"Stake" : 250
	},
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559255,
		"CustID" : 37144068,
		"TransDate" : "2021-11-09 21:03:34.900",
		"Stake" : 250
	}
]');
CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144067,37144068');
SELECT  * FROM CTS_DataCenter.Temp_Group;
CALL CTS_DC_MatchMonitor_Rule_Get(1,50,@orr); select @orr; -- 111880559255
CALL CTS_DC_MatchMonitor_Rule_Process(1,111880559255,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(1,111880559255,22081995,1,1,'[{"GroupID":1,"IsHedging":0,"TransIDList":"111880559250,111880559251,111880559252,111880559253,111880559254,111880559255","CustIDList":"37144067,37144068","OldGroupIDList":"0,1"}]');
CALL CTS_DC_MatchMonitor_Staging_Clean(1,111880559255);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingLive;
SELECT * FROM CTS_DataCenter.MatchMonitor;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails;

#==PACK04================================== PASS
#==Expected: Trans01, Trans02, Trans03, Trans04, Trans05, Trans06, Trans07, Trans08, Trans09, Trans10 are generated to Group Betting 1 
CALL CTS_DC_MatchMonitor_Staging_Insert(1,'[
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559256,
		"CustID" : 37144068,
		"TransDate" : "2021-11-09 21:04:02.800",
		"Stake" : 250
	},
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559257,
		"CustID" : 37144068,
		"TransDate" : "2021-11-09 21:04:03.900",
		"Stake" : 250
	},
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559258,
		"CustID" : 37144068,
		"TransDate" : "2021-11-09 21:04:19.900",
		"Stake" : 250
	},
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559259,
		"CustID" : 37144068,
		"TransDate" : "2021-11-09 21:04:56.900",
		"Stake" : 250
	},
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559260,
		"CustID" : 37144068,
		"TransDate" : "2021-11-09 21:04:57.900",
		"Stake" : 250
	}
]');
CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144067,37144068');
SELECT  * FROM CTS_DataCenter.Temp_Group;
CALL CTS_DC_MatchMonitor_Rule_Get(1,50,@orr); select @orr; -- 111880559260
CALL CTS_DC_MatchMonitor_Rule_Process(1,111880559260,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(1,111880559260,22081995,1,1,'[{"GroupID":1,"IsHedging":0,"TransIDList":"111880559250,111880559251,111880559252,111880559253,111880559254,111880559255,111880559256,111880559257,111880559258,111880559259,111880559260","CustIDList":"37144067,37144068","OldGroupIDList":"1"}]');
CALL CTS_DC_MatchMonitor_Staging_Clean(1,111880559260);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingLive;
SELECT * FROM CTS_DataCenter.MatchMonitor;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails;

#==PACK05================================== PASS
#==Expected: Trans01, Trans02, Trans03, Trans04, Trans05 are generated to Group Betting 1 
CALL CTS_DC_MatchMonitor_Staging_Insert(1,'[
	{
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559261,
		"CustID" : 37144068,
		"TransDate" : "2021-11-09 21:06:09.900",
		"Stake" : 250
	},
    {
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559262,
		"CustID" : 37144068,
		"TransDate" : "2021-11-09 21:06:12.900",
		"Stake" : 250
	},
    {
		"MatchID" : 22081995,
		"HomeID" : 5,
		"AwayID" : 8,
		"EventStatus" : "running",
		"KickOffTime" : "2021-11-09 00:00:00",
		"LeagueID" : 86835,
		"EventDate" : "2021-11-09",
		"LiveIndicator" : "1",
		"LiveHomeScore" : 1,
		"LiveAwayScore" : 0,
		"TotalScore" : 1,
		"Bettype" : 1,
		"TransID" : 111880559263,
		"CustID" : 37144070,
		"TransDate" : "2021-11-09 21:06:22.900",
		"Stake" : 250
	}
]');
CALL CTS_DataCenter.CTS_DC_Association_GetGroup('37144068,37144070');
SELECT  * FROM CTS_DataCenter.Temp_Group;
CALL CTS_DC_MatchMonitor_Rule_Get(1,50,@orr); select @orr; -- 111880559263
CALL CTS_DC_MatchMonitor_Rule_Process(1,111880559263,22081995,1,1);
CALL CTS_DC_MatchMonitor_Rule_Complete(1,111880559263,22081995,1,1,'[{"GroupID":1,"IsHedging":0,"TransIDList":"111880559250,111880559251,111880559252,111880559253,111880559254,111880559255,111880559256,111880559257,111880559258,111880559259,111880559260,111880559261,111880559262,111880559263","CustIDList":"37144067,37144068,37144070","OldGroupIDList":"0,1"}]');
CALL CTS_DC_MatchMonitor_Staging_Clean(1,111880559263);

SELECT * FROM CTS_DataCenter.MatchMonitorStagingLive;
SELECT * FROM CTS_DataCenter.MatchMonitor;
SELECT * FROM CTS_DataCenter.MatchMonitorDetails;