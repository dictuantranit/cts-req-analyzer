/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_Association_Profile_Get`;

DELIMITER $$ 
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_Profile_Get`(
		IN ip_CTSCustID 		BIGINT UNSIGNED
	,	IN ip_RoleIDList		VARCHAR(50)
	,	IN ip_AssociationType	INT
	,	IN ip_AssociationStatus INT 
    ,	IN ip_AccountStatusIDs	VARCHAR(100)
     ,	IN ip_CategoryIDs		TEXT
	, 	IN ip_SubscriberIDs		TEXT
    ,	IN ip_Skip 				INT
    ,	IN ip_Take 				INT
    
    ,	OUT op_TotalItems		INT
)
    SQL SECURITY INVOKER
sp : BEGIN
	/*
		Created:	20210202@Aries.Nguyen
		Task:		Get association account 
		DB:			CTS_DataCenter
		Revisions:
			- 20210202@Aries.Nguyen: 	Created [Redmine ID: #148908]
			- 20210221@Aries.Nguyen: 	Fix get wrong first association date by device [Redmine ID: #150223]
			- 20210316@Casey.Huynh: 	Get Customer Category Info [Redmine ID: #150457]
			- 20210317@Casey.Huynh: 	Count AssociationByIP to lv_TotalAccounts [Redmine ID: #131662]
			- 20210330@Jonas.Huynh: 	Replace Site filter by Subscriber [Redmine ID: #152252]
			- 20210415@Aries.Nguyen: 	Fix show duplicated records at Associated Accounts [Redmine ID: #153511]
			- 20210419@Irena.Vo: 		Ignore get CC on Associated Accounts tab [Redmine ID: #152250]
			- 20210420@Irena.Vo: 		Get data for Sub Account on Associated Accounts tab [Redmine ID: #152963]
			- 20210505@Irena.Vo: 		Get additional CustId [Redmine ID: #152963]
			- 20210506@Irena.Vo: 		Get additional CustSubId [Redmine ID: #154624]            
			- 20220328@Aries.Nguyen: 	Add new category/class for PA Probation [Redmine ID: #170468]
			- 20220408@Long.Luu: 		Get more data from AssociationGroupByAI [Redmine ID: #171222]
			- 20220705@Aries.Nguyen: 	Tuning SP [Redmine ID: #174430]
			- 20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
            - 20230313@Casey.Huynh:		Applied Betting Parten OTGB [Redmine ID: #184791]
            - 20230421@Casey.Huynh: 	Handle Fist Association Date [Redmine ID: #185783]
            - 20240319@Casey.Huynh: 	Classify Danger Score [Redmine ID: #201358]
            - 20240425@Thomas.Nguyen:	Classify Initial Group Betting - Add ParentID = 150 [Redmine ID: #200854]
			- 20240628@Thomas.Nguyen: 	Renovate CC phase 2 - Remove hardcode and return more IsPA, IsPotentialPA [Redmine ID: #205317]
			- 20240923@Jonas.Huynh: 	Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]
			- 20241024@Jonas.Huynh: 	HF Wrong category color order   [RedmineID: #209792]	
			- 20241002@Casey.Huynh: 	Return Agency Category [Redmine ID: #185799]
            
		Param's Explanation (filtered by):
			- ip_AssociationType: 0 - ALL, 1 - Device, 2 - AI, 3 - Manual, 4 - IP
            - ip_AssociationStatus: 0 - All, 1 - Linked, 2 - UnLinked
            - ip_AccountStatusIDs: 0,1,11,2,3,4,12,13,14 - All,    1,11 - Open(1:Open, 11:Active),  2,3,4,12,13,14 - Closed (2:Disabled, 3:Closed, 4:Suspended, 12:Inactive, 13:View Only, 14:Suspended), 0: Other (sub account)
            - ip_CategoryIDs: 0, 51,205,206,...-Selected CategoryIDs (0-'No Category' Option)
            
        Example:
			  CALL CTS_DC_Association_Profile_Get(
				@ip_CTSCustID:=114181
			,	@ip_AssociationType:=0
			,	@ip_AssociationStatus:=1
			,	@ip_AccountStatusIDs:='1,11'
			,	@ip_CategoryIDs:='20303,20302,20301,20300,120300,25300,25303,25302,25301,125300,20400,20401,20402,20403,120400,25403,25402,25401,25400,125400,20603,20602,20601,20600,120600,25600,25603,25602,25601,125600,20100,20103,20102,20101,120100,25103,25102,25101,25100,125100,20200,20201,20202,20203,120200,25200,25201,25202,25203,125200,20802,20801,20800,120800,25800,25802,25801,125800,20502,20500,20501,20503,120500,25500,25501,25502,25503,125500,21200,26200,121100,126100,21100,26100,20900,25900,21000,26000,140400,140200,40202,40203,40201,140100,40102,40103,40101,140300,40302,40303,40301,40402,40403,40401,140600,40602,40603,40601,140500,40502,40503,40501,101010,30100,35100,40200,140700,30300,35300,30200,35200,40100,40300,40404,40405,40400,40600,40604,40605,40500,40504,40505,1010,0,0,40700,40701'
			,	@ip_SubscriberIDs:='2339,2338,5733450,5733451,2,168,13659,13658,130,169,5733008,5733010,270,5733479,6,2309,5733357,5733237,5733320,5733744,3373,5733032,5732818,1277,5733245,190,146,5732982,5732817,5733011,255,5733591,5732859,5733703,125,5733020,5732988,5733247,4388,5732828,5733726,5733469,5733213,5733053,4389,5733652,5733634,5733684,4390,5732824,244,5733530,5733567,5733568,3388,127,5733596,13669,116,156,898209,5732858,1270,4408,1309,5733694,5733696,5732874,172,5733130,5733792,5733179,5733791,5733623,5732901,5733531,5733438,5733325,5733166,5733748,157,2320,5732922,4409,5733699,147,5733421,5733361,5733235,5733491,5733374,5733762,2368,5733101,5733119,5732894,3374,5732973,101,271,898219,2310,5733760,1302,2340,5733241,13687,121,5732940,5732915,1271,3375,5732868,5733252,5733752,5732882,898198,2362,173,5733332,5733329,5733335,5733606,4443,13662,13665,5733168,5733306,5733186,4593,2373,5733221,5732903,5733174,5733692,5732844,5732842,898215,5733128,5732879,5733512,5732855,5733416,5733417,104,266,2369,3376,5733302,5733486,4870492,5732822,5733422,142,5733184,5733001,5732998,5733496,5733222,5733620,5733159,5733264,1310,5733700,5733818,5733330,5733517,5733215,1280,5733074,5732968,5733654,5733037,225,5732833,5733598,5733240,5733611,5733649,5733595,5733436,5733087,898199,898200,2311,3389,245,5733397,5,3377,220,5733334,128,1292,5733697,3382,226,4630,241,13667,5733262,5732815,5732995,5733232,5732900,3379,5733088,5733091,5733170,5733508,5733777,2352,1303,5733163,5733253,5733746,5733369,5733446,5733562,5733172,5733354,5732873,5733642,5733643,5733724,1304,4391,5733466,2342,5733351,5732929,5733592,5733107,5733328,5732857,5733689,5733729,5733284,5733324,5733283,5733380,5733403,5733356,5733347,5732887,5733701,13686,4417,1294,3383,4392,212,5732970,5733080,175,5733162,5733537,5733062,5732941,2321,5733461,191,5733230,2343,5733246,5732969,5733076,5733126,5733127,4870491,5733270,2363,5732880,5732877,5733141,5733671,5733437,5733624,5732960,5733547,5733344,5733434,5733002,4410,5733687,5733601,1275,5732974,5733527,5732852,5732851,5732856,236,5733144,5733769,5733599,5733600,5733819,5733549,176,2370,1272,3390,5733404,5733487,5733073,5733580,5733183,1295,1282,5732992,5733673,5733282,5733650,5732866,5733014,5733260,5733381,2344,5733138,213,5733082,5733610,5733509,5733493,105,5733468,5733554,5733309,5732821,4393,5732904,898220,1296,177,193,5733506,2329,5732981,5733121,1312,5733725,2345,2330,4631,5733038,5733636,273,5732991,5733024,5732840,5732956,5732959,5732946,5733084,5733085,5733055,5733402,5733622,165,4399,243,5733431,5733217,5732972,5732865,5733413,5733414,5733177,5733812,5733392,5733518,5733665,5733662,5733501,5733584,5733585,5733393,5733780,5733031,5733543,5733472,5733189,5733146,149,3384,4628,5732937,13681,2312,247,179,4624,13688,2331,129,5733352,5733265,5732932,5733548,5733103,4404,1313,180,5733231,5733802,5733180,158,1314,1305,2346,181,5733153,1284,5732814,5733756,5733738,5733440,195,5733570,5733571,5733572,5733709,5733573,5733574,5733185,5732845,5733206,5733511,150,2347,162,2374,5733145,5733370,5733178,2313,5733773,5733771,898193,5732870,221,5732832,5733481,5733475,5733520,5732938,2375,196,5733492,197,5733471,122,223,5733341,5733243,898201,4394,5733480,5733075,5733100,5733670,5732947,4411,5733750,5732854,1293,3391,5733759,249,5733830,5732908,5732951,5733000,5733198,5733497,5733400,5733452,5733317,13664,5733094,5733619,5733109,5733605,5733587,5733465,4625,5733795,5733199,237,13685,5733060,5733061,5733426,160,5733736,5733036,5732838,5732849,198,5733470,3380,5733258,5733104,5733430,5733806,5733737,5733734,5733455,5732909,5732917,2322,5733086,5733173,5733660,5733794,5733761,2314,5733412,3385,898206,5733204,5733134,5732936,5732957,5733120,5733655,5733259,5733366,5733368,5733563,4094088,5733054,5732871,5732950,2353,5733345,5732983,5733195,5733478,184,5732914,5733147,13680,5732830,5732846,4418,5732891,5732905,5733443,4412,898202,5732979,5733371,5733656,5733156,1290,5733522,5733092,5733140,5733766,5733538,2364,5733815,5733192,102,138,13666,5733484,112,13670,898213,5732875,1297,263,199,898218,5732977,2316,5733046,5733411,5733817,5733251,5733618,5733273,5733789,5733717,5733398,13657,1273,5733006,5733303,5733743,1285,2371,5733739,2317,5733793,5732841,4395,5732967,4413,5733133,5733728,5733500,5733429,5733209,258,5732864,5732996,4400,5733096,4629,898212,5733439,4610,5733331,5733774,5733551,5733499,1298,185,13683,5733453,5733502,5733741,5733236,5733299,5732886,4401,3392,186,5733274,5733269,4521,5733039,5733007,5733388,5733105,5733041,5733295,5733829,898216,5732906,13691,5733188,4405,5732949,5733029,5733052,5733576,5733364,5733365,5733132,251,5732831,5733367,5733555,5733790,5733676,5733405,144,5732976,5733425,5733433,5732990,1307,2348,5733288,5733291,4419,5733663,1291,230,252,5733409,5733454,5733464,5732816,5733165,5733360,898197,5733118,5733401,5732883,5733495,235,4870488,5733211,5733212,5733813,5733716,5732902,5733415,5733805,5733804,2332,5733070,216,4396,5733807,5733575,5733319,5733321,5733386,5733698,5733745,13678,5733292,5733362,5733523,5733524,5733707,166,4600,5733597,5732920,2349,5733639,5733023,5732975,4406,5733682,5733712,898196,5733384,5733788,5732944,5733732,5733043,5733227,5733536,151,5733057,5733616,5733722,5733758,5733768,5733816,4870489,5733641,5733753,5732853,898195,126,5733339,5733528,5733529,4094066,2350,5733181,5733718,5733719,5732848,5732971,5733071,5733201,5733035,5733108,5733151,5733396,152,5733375,5733157,5733267,5733268,4397,2333,3386,5733828,2323,5733603,5733279,5733294,5733083,13684,5733553,1315,5732958,5733218,5732869,5733391,4414,5732997,5733445,5733535,3393,131,5733686,1300,5733525,5733544,5733801,5733787,2324,4402,5733482,5733810,5733009,4424,5733827,200,4425,108,5733690,231,253,5733003,2334,5733513,5733373,13663,5733049,5733379,232,5733106,5733193,209,1308,4603,5733382,5733383,5733318,5733407,4426,5733399,5733315,5733490,5733293,5733515,5733428,5733627,5733607,5733514,5733783,5733628,5733565,5733566,5733516,5733797,5733427,5733581,5733629,5733785,5733648,5733582,5733784,5733786,5733647,5733583,5733798,5733630,5733823,5733826,5733822,5733821,5733313,5733314,5733310,5733779,5733781,5733275,5733316,5733308,5733395,5733312,5733448,5733796,5733311,5733307,2355,5732892,5733016,5732931,5733485,5732942,217,187,5733233,5732923,5733098,5733541,5733540,5732913,5733326,5732881,4420,13682,5733604,5733017,4421,5732933,1316,5733546,107,5733740,2365,5732918,275,898207,5733079,5733255,5733256,5733463,5732963,898211,5733693,5733695,5733114,5733160,2325,5733142,5733343,2351,4626,5733093,5733171,5733059,5733089,5732872,898203,5733077,5733679,234,189,5732843,898194,5733065,2335,229,5732912,5733005,5733612,5733688,111,207,5733067,5733234,5733799,5732876,5733229,5733286,5733389,5732952,5732999,2318,5733137,5733442,5733363,5733346,5733102,5733651,5733803,1317,898210,5733202,5733751,5733435,5733327,120,5732980,5733519,898205,4398,3381,4403,3387,1286,5732965,5732966,5733820,5733278,204,2356,4632,5733296,5732826,5733353,5732834,2357,13677,5733187,5733763,1301,5733408,5733116,2372,5732889,5733358,2358,4415,2359,5733125,13673,5733113,5733542,5733276,5733661,5733115,5733004,5733710,5733281,5733051,4422,5732820,5733333,5732910,5733711,5732953,5733025,1287,5733372,5732955,5733027,5733123,5732964,5733238,5732847,2319,5733406,5733048,5733099,13690,161,4416,5732924,2360,5733545,5733609,2376,5732961,2337,1288,5733261,5733266,1289,5732986,5732943,269,5733483,5733034,5733033,3394,5733042,5733047,4423,5733560,5733561,5733040,5733677,5733664,2327,5733272,5733117,5733424,5732911,5732926,5732925,5733666,5733731,5733644,5733657,5733645,5733668,5733705,5733667,5733755,5733704,5733675,5733681,5733691,5733708,5733378,5733730,5733782,5733765,5733767,5733772,5732962,5733078,5733013,5733196,5733045,5733219,5733208,5733152,5733225,5733135,5733176,5733191,5733337,5733419,5733385,5733589,5733226,5733249,5733340,5733254,5733706,5733355,5733534,5733825,5733778,5733533,5732867,13689,13668,13672,5732907,5733458,5732835,898217,5732819,4870490,5732862,5732993,5732994,5732860,5732825,5732823,5732836,5732839,5732888,5732890,5732863,5732984,5732861,5733244,5733066,5732878,5733216,5733169,5732885,5733112,5733158,5732916,5732897,5732898,5732896,5733111,5732939,5733257,5732954,5732934,5733224,5732948,5732978,5732985,5733081,5733044,5733569,5733056,5733155,5733139,5733124,5733150,5733164,5733194,5733214,5733301,5733207,5733220,5733289,5733608,5733287,5733277,5733348,5733323,5733588,5733342,5733721,5733457,5733775,5733418,5733559,5733614,5733811,5733432,5733456,5733460,5733474,5733617,5733577,5733504,5733735,5733505,5733640,5733632,5733556,5733757,5733625,5733633,5733631,5733658,5733672,5733674,5733669,5733754,5733680,5733749,5733713,5733747,5733727,5733742,5733824,5733764,5733776,5733800,5733808,5733831,5733809,13661,13671,5733026,5733030,13679,5732927,5732850,4627,13656,13660,898204,5732827,5733182,898208,5733136,898214,5732895,5732919,5732837,5732893,5733012,5733376,5733131,5732928,5732884,5733021,5733304,5732987,5732899,5732921,5732989,5732930,5733090,5732935,5732945,5733420,5733028,5733019,5733167,5733015,5733018,5733022,5733058,5733068,5733063,5733064,5733072,5733095,5733110,5733097,5733149,5733242,5733122,5733129,5733143,5733148,5733239,5733154,5733161,5733175,5733190,5733197,5733200,5733205,5733203,5733210,5733300,5733223,5733715,5733228,5733578,5733733,5733248,5733250,5733263,5733271,5733280,5733285,5733615,5733297,5733579,5733290,5733305,5733298,5733447,5733359,5733477,5733770,5733336,5733462,5733322,5733338,5733377,5733467,5733714,5733503,5733507,5733390,5733387,5733444,5733702,5733394,5733594,5733488,5733459,5733410,5733441,5733659,5733449,5733586,5733613,5733494,5733637,5733473,5733558,5733476,5733510,5733498,5733646,5733521,5733532,5733526,5733685,5733626,5733557,5733539,5733564,5733590,5733602,5733593,5733720,5733683,5733621,5733723,5733550,5733423,4611,5733814,5733349,5733638,5733350,5733653,5733678,1274,5733552,5733489,5733050,5733635,103'
			,	@ip_Skip:=0
			,	@ip_Take=50
			,	@outParam8); 
	*/
	DECLARE CONST_ASSTYPE_BETTINGPATTERN 		INT DEFAULT 2;
    DECLARE CONST_ASSBYAI_ACTIVESTATUS 			INT DEFAULT 1;
	DECLARE CONST_PARENTID_WRAPPER				INT;
	DECLARE CONST_PARENTID_PA               	INT;
	DECLARE	CONST_PARENTID_POTENTIALPA 			INT;
	DECLARE	CONST_BIZCATEGROUPID_NORMAL 		INT;
    DECLARE CONST_AGENCY_PARENTID_PA            INT;
    DECLARE CONST_ROLEID_MEMBER					TINYINT DEFAULT 1;
    DECLARE CONST_ROLEID_AGENT            		TINYINT DEFAULT 2;
    DECLARE CONST_ROLEID_MASTER            		TINYINT DEFAULT 3;
    DECLARE CONST_ROLEID_SUPER            		TINYINT DEFAULT 4;
    #==================================================
	DECLARE lv_CustID INT;
    
    #=====================DEBUG LOG===========================================
	DECLARE lv_IsLog BOOLEAN DEFAULT 0;    
	DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_Association_Profile_Get';
	IF lv_IsLog = 1 THEN
		SET @LogInfo = CONCAT('@ip_CTSCustID:=''',IFNULL(ip_CTSCustID,'NULL'),''''
								,',@ip_AssociationType:=''',IFNULL(ip_AssociationType,'NULL'),''''
                                ,',@ip_AssociationStatus:=''',IFNULL(ip_AssociationStatus,'NULL'),''''
                                ,',@ip_AccountStatusIDs:=''',IFNULL(ip_AccountStatusIDs,'NULL'),''''
                                ,',@ip_CategoryIDs:=''',IFNULL(ip_CategoryIDs,'NULL'),''''
                                ,',@ip_SubscriberIDs:=''',IFNULL(ip_SubscriberIDs,'NULL'),''''
                                ,',@ip_Skip:=''',IFNULL(ip_Skip,'NULL'),''''
                                ,',@ip_Take:=''',IFNULL(ip_Take,'NULL'),'''');
        
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), @LogInfo; 
	END IF;  
	
	SET CONST_PARENTID_WRAPPER 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_PARENTID_PA 				    = CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
    SET CONST_PARENTID_POTENTIALPA 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_POTENTIALPA');
    SET CONST_BIZCATEGROUPID_NORMAL 		= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_NORMAL');
    SET CONST_AGENCY_PARENTID_PA 			= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
    
	#========================================================================
    IF (ip_SubscriberIDs IS NULL OR ip_SubscriberIDs = '' OR ip_SubscriberIDs = -1) OR  (ip_CategoryIDs IS NULL OR ip_CategoryIDs = '' OR ip_CategoryIDs = -1) THEN
		LEAVE sp;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedAccount;
    CREATE TEMPORARY TABLE 		Temp_AssociatedAccount (
			CTSCustID			BIGINT UNSIGNED
		,	CustID				BIGINT UNSIGNED
        ,	CustSubID			INT UNSIGNED
        ,	RoleID				SMALLINT
		,	SiteID				INT UNSIGNED
        ,	SiteName			VARCHAR(50)
        ,	SubscriberID 		INT UNSIGNED
        ,	SubscriberName		VARCHAR(50)
        ,	UserName			VARCHAR(50)
        ,	UserName2			VARCHAR(50)
		,	AccountStatusGroup	INT
        ,	AccountStatusID		INT
		,	AccountStatusName	VARCHAR(20)
        ,	AssociationType 	INT
        ,	AssociationTypeName	VARCHAR(50)
		, 	AssociationStatus	INT
        ,	AssociationDate		DATETIME
        ,	IsFiltered	        BIT DEFAULT 0
        , 	PRIMARY KEY(CTSCustID)
        ,	INDEX IX_Temp_AssociatedAccount_CustID(CustID)
        ,	INDEX IX_Temp_AssociatedAccount_SubscriberID(SubscriberID)
        ,	INDEX IX_Temp_AssociatedAccount_RoleID(RoleID)
	);   
	
    DROP TEMPORARY TABLE IF EXISTS Temp_Classification;
    CREATE TEMPORARY TABLE 	Temp_Classification (
			CTSCustID 		BIGINT UNSIGNED
		,	ParentID		INT UNSIGNED
		,	CategoryIDs		VARCHAR(1000)
		,	CategoryNames	VARCHAR(5000)
		,	ColorTypeIDs	VARCHAR(100)
		,	IsPAProbation	BIT DEFAULT 0
        , 	PRIMARY KEY (CTSCustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
    CREATE TEMPORARY TABLE 		Temp_Association(
			CTSCustID_Aff 		BIGINT UNSIGNED
        , 	AssociationType		INT
		, 	AssociationStatus	INT
        ,	AssociationDate		DATETIME
        , 	PRIMARY KEY (CTSCustID_Aff,AssociationType,AssociationStatus)
	);  
    
	DROP TEMPORARY TABLE IF EXISTS Temp_UnlinkedAssociation;
    CREATE TEMPORARY TABLE 		Temp_UnlinkedAssociation (
			CTSCustID_Aff 		BIGINT UNSIGNED
        , 	AssociationType		INT
        , 	AssociationStatus	INT
        ,	AssociationDate		DATETIME
        , 	PRIMARY KEY (CTSCustID_Aff,AssociationType,AssociationStatus)
	);  
	
    DROP TEMPORARY TABLE IF EXISTS Temp_SubscriberID;
    CREATE TEMPORARY TABLE 		Temp_SubscriberID (
			SubscriberID 		INT UNSIGNED
        , 	PRIMARY KEY (SubscriberID)
	);   
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AccountStatusID;
    CREATE TEMPORARY TABLE 		Temp_AccountStatusID (
			AccountStatusID 	INT UNSIGNED
        , 	PRIMARY KEY (AccountStatusID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CategoryID;
    CREATE TEMPORARY TABLE 	Temp_CategoryID (
			CategoryID 		INT UNSIGNED
        , 	PRIMARY KEY (CategoryID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Group;
    CREATE TEMPORARY TABLE 	Temp_Group (
			GroupID 		BIGINT UNSIGNED PRIMARY KEY
		,	OriginGroupID	BIGINT UNSIGNED
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustomerGroup;
    CREATE TEMPORARY TABLE 	Temp_CustomerGroup (
			CustID 					BIGINT UNSIGNED PRIMARY KEY
		,	AssociationDate			DATETIME
		,	GroupIDList				VARCHAR(1000)        
		,	OriginGroupIDList		VARCHAR(1000)
	);
	#=============================================================
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByAI_AssType (
			AssTypeItemValue INT PRIMARY KEY            
	);
    
	#=============================================================
	DROP TEMPORARY TABLE IF EXISTS Temp_RoleID;
	CREATE TEMPORARY TABLE 	Temp_RoleID (
		RoleID SMALLINT PRIMARY KEY         
	);
    #===========GET AssociationByAI status is Applied==============================================    
    INSERT INTO Temp_AssociationByAI_AssType(AssTypeItemValue)
    SELECT atd.AssTypeItemValue
    FROM CTS_DataCenter.AssociationTypeSetting AS atd
    WHERE atd.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN AND atd.AssTypeItemStatus = CONST_ASSBYAI_ACTIVESTATUS;
    
	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_SubscriberID (SubscriberID) VALUES ('", REPLACE(ip_SubscriberIDs, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1; 

    SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_AccountStatusID (AccountStatusID) VALUES ('", REPLACE(ip_AccountStatusIDs, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1;

    SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_CategoryID (CategoryID) VALUES ('", REPLACE(ip_CategoryIDs, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1;
	
	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_RoleID (RoleID) VALUES ('", REPLACE(ip_RoleIDList, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1;
    
    /* Get CustID */    
    SELECT CustID 
    INTO lv_CustID
    FROM CTS_DataCenter.CTSCustomer 
    WHERE CTSCustID = ip_CTSCustID;
    
    # ip_AssociationType: 0 - ALL, 1 - Device, 2 - AI, 3 - Manual, 4 - IP
    IF ip_AssociationType = 0 OR ip_AssociationType = 1 THEN
		INSERT INTO Temp_Association(CTSCustID_Aff, AssociationType, AssociationStatus,  AssociationDate)
		SELECT  asCus.CTSCustID  
			,	1 AS AssociationType
            , 	1 AS AssociationStatus
			,	GREATEST(asDv.CreatedTime, asCus.CreatedTime)
		FROM CTS_DataCenter.AssociationByDevice AS asDv 
			INNER JOIN CTS_DataCenter.AssociationByDevice AS asCus ON asCus.DCSDeviceID = asDv.DCSDeviceID AND asCus.CTSCustID <> ip_CTSCustID
		WHERE asDv.CTSCustID = ip_CTSCustID
        ON DUPLICATE KEY UPDATE AssociationDate = LEAST(Temp_Association.AssociationDate, GREATEST(asDv.CreatedTime, asCus.CreatedTime)); 
    END IF;
    
    # ip_AssociationType: 0 - ALL, 1 - Device, 2 - AI, 3 - Manual, 4 - IP
    IF ip_AssociationType = 0 OR ip_AssociationType = 3 THEN
		INSERT IGNORE INTO Temp_Association(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT  asMa.ToCTSCustID 
			,	3 AS AssociationType
            ,   1 AS AssociationStatus
			,	asMa.CreatedDate
		FROM CTS_DataCenter.AssociationByManual AS asMa 
		WHERE	asMa.FromCTSCustID = ip_CTSCustID;
        
        INSERT IGNORE INTO Temp_Association(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT  asMa.FromCTSCustID 
			,	3 AS AssociationType
            ,   1 AS AssociationStatus
			,	asMa.CreatedDate
		FROM CTS_DataCenter.AssociationByManual AS asMa 
		WHERE	asMa.ToCTSCustID =  ip_CTSCustID;
    END IF;

    # ip_AssociationType: 0 - ALL, 1 - Device, 2 - AI, 3 - Manual, 4 - IP
    IF ip_AssociationType = 0 OR ip_AssociationType = 2 THEN
		INSERT IGNORE INTO Temp_Association(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT  cust.CTSCustID 
			,	CONST_ASSTYPE_BETTINGPATTERN AS AssociationType
            ,	CONST_ASSBYAI_ACTIVESTATUS AS AssociationStatus
			,	asAI.CreatedDate
		FROM CTS_DataCenter.AssociationByAI AS asAI 
			INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = asAI.ToCustID AND cust.CustSubID = 0
		WHERE	asAI.FromCustID = lv_CustID
			AND asAI.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt)
		ORDER BY asAI.CreatedDate ASC;
        
        INSERT IGNORE INTO Temp_Association(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT  cust.CTSCustID 
			,	CONST_ASSTYPE_BETTINGPATTERN AS AssociationType
            ,	CONST_ASSBYAI_ACTIVESTATUS AS AssociationStatus
			,	asAI.CreatedDate
		FROM CTS_DataCenter.AssociationByAI AS asAI 
			INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = asAI.FromCustID AND cust.CustSubID = 0
		WHERE	asAI.ToCustID = lv_CustID
			AND asAI.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt)
		ORDER BY asAI.CreatedDate ASC;
        
        INSERT INTO Temp_Group(GroupID, OriginGroupID)
        SELECT DISTINCT GroupID, OriginGroupID
        FROM CTS_DataCenter.AssociationGroupByAI
        WHERE CustID = lv_CustID;
        
        INSERT INTO Temp_CustomerGroup(CustID, AssociationDate, GroupIDList, OriginGroupIDList)
        SELECT  g.CustID
			,	MIN(g.CreatedDate)
            ,	GROUP_CONCAT(g.GroupID SEPARATOR ',')            
            ,	CONCAT(GROUP_CONCAT(g.OriginGroupID SEPARATOR ','), ',', GROUP_CONCAT(t.OriginGroupID SEPARATOR ','))
            #,	GROUP_CONCAT(g.OriginGroupID SEPARATOR ',')
		FROM Temp_Group AS t
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS g ON t.GroupID = g.GroupID AND g.CustID <> lv_CustID
		GROUP BY g.CustID;
        
        INSERT IGNORE INTO Temp_Association(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT   c.CTSCustID
			,	2 AS AssociationType
            ,	1 AS AssociationStatus
			,	t.AssociationDate
		FROM Temp_CustomerGroup AS t
			INNER JOIN CTSCustomer AS c ON t.CustID = c.CustID;
    END IF;
   
	IF ip_AssociationType = 0 OR ip_AssociationType = 4 THEN	
  
		DROP TEMPORARY TABLE IF EXISTS Temp_IPCustID;
        CREATE TEMPORARY TABLE Temp_IPCustID (CustID BIGINT PRIMARY KEY, AssociationDate DATETIME);
        INSERT INTO Temp_IPCustID(CustID, AssociationDate)
        SELECT 	asIP.ToCustID
			,	asIP.CreatedDate
        FROM CTS_DataCenter.AssociationByIP AS asIP 
        WHERE asIP.FromCustID =  lv_CustID
        ON DUPLICATE KEY UPDATE AssociationDate = LEAST(AssociationDate, asIP.CreatedDate);

        INSERT INTO Temp_IPCustID(CustID, AssociationDate)
        SELECT 	asIP.FromCustID
			,	asIP.CreatedDate
        FROM CTS_DataCenter.AssociationByIP AS asIP 
        WHERE asIP.ToCustID =  lv_CustID
        ON DUPLICATE KEY UPDATE AssociationDate = LEAST(AssociationDate, asIP.CreatedDate);        

        INSERT INTO Temp_Association(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT  cus.CTSCustID 
			,	4 AS AssociationType
            ,	1 AS AssociationStatus
			,	tmpIp.AssociationDate
		FROM Temp_IPCustID AS tmpIp
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID  = tmpIp.CustID AND cus.CustSubID = 0;	

    END IF;
    
    #ip_AssociationStatus: 0 - All, 1 - Linked, 2 - UnLinked
	INSERT IGNORE INTO Temp_UnlinkedAssociation (CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
	WITH CTE_AssociationRemove AS (
		SELECT asRe.ToCTSCustID AS CTSCustID_Aff
			,  asRe.CreatedDate
		FROM CTS_DataCenter.AssociationRemove AS asRe 
		WHERE asRe.FromCTSCustID = ip_CTSCustID
	)
	SELECT 	cte.CTSCustID_Aff
		,	tmp.AssociationType
		,	2 AS AssociationStatus
		,	cte.CreatedDate
	FROM CTE_AssociationRemove AS cte
		INNER JOIN Temp_Association AS tmp ON cte.CTSCustID_Aff = tmp.CTSCustID_Aff;        
        
	INSERT IGNORE INTO Temp_UnlinkedAssociation (CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
	WITH CTE_AssociationRemove AS (
		SELECT asRe.FromCTSCustID AS CTSCustID_Aff
			,  asRe.CreatedDate
		FROM CTS_DataCenter.AssociationRemove AS asRe 
		WHERE asRe.ToCTSCustID = ip_CTSCustID
	)
	SELECT 	cte.CTSCustID_Aff
		,	tmp.AssociationType
		,	2 AS AssociationStatus
		,	cte.CreatedDate
	FROM CTE_AssociationRemove AS cte
		INNER JOIN Temp_Association AS tmp ON cte.CTSCustID_Aff = tmp.CTSCustID_Aff;
        
	DELETE cuAs 
	FROM Temp_Association AS cuAs 
	WHERE cuAs.CTSCustID_Aff IN (SELECT CTSCustID_Aff FROM Temp_UnlinkedAssociation);
        
	INSERT IGNORE INTO Temp_Association(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
	SELECT 	CTSCustID_Aff
		,	AssociationType
		,	AssociationStatus
		,	AssociationDate
	FROM Temp_UnlinkedAssociation;

     IF ip_AssociationStatus = 2 THEN
		DELETE 
        FROM Temp_Association 
        WHERE Temp_Association.AssociationStatus <> 2;
     END IF;
     
     IF ip_AssociationStatus = 1 THEN
		DELETE cuAs
        FROM Temp_Association  AS cuAs
            INNER JOIN Temp_UnlinkedAssociation AS un ON un.CTSCustID_Aff = cuAs.CTSCustID_Aff AND un.AssociationStatus = cuAs.AssociationStatus;
     END IF;     
  
     /* Insert data */
     INSERT IGNORE INTO Temp_AssociatedAccount(CTSCustID,CustID,CustSubID,RoleID,SubscriberID,SubscriberName,SiteID,SiteName,UserName, UserName2,AccountStatusGroup,AccountStatusID,AccountStatusName,AssociationType, AssociationTypeName,AssociationStatus,AssociationDate)
     SELECT cust.CTSCustID
		,	cust.CustID
        ,	cust.CustSubID
        ,	cust.RoleID
		,	cust.SubscriberID
        ,	maSu.SubscriberName
        ,	cust.SiteID
        ,	cust.Site AS SiteName
        ,	cust.UserName
        ,	cust.UserName2
        ,	sta1.PriorityOrder AS AccountStatusGroup
        ,	sta1.ItemID AS AccountStatusID
		,   sta1.ItemName AS AccountStatusName
        ,	cuAs.AssociationType
        ,	sta.ItemName AS AssociationTypeName 
        ,	cuAs.AssociationStatus
        ,	cuAs.AssociationDate
     FROM Temp_Association AS cuAs
        STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cust ON cuAs.CTSCustID_Aff = cust.CTSCustID AND cust.RoleID IN (SELECT RoleID FROM Temp_RoleID)
        STRAIGHT_JOIN CTS_DataCenter.StaticList AS sta ON sta.ListID = 2 AND sta.ItemID = cuAs.AssociationType 
	    STRAIGHT_JOIN CTS_DataCenter.StaticList AS sta1 ON sta1.ListID = 1 AND sta1.ItemID = cust.CustStatusID
        STRAIGHT_JOIN CTS_DataCenter.MappingSubscriberSite AS maSu ON maSu.SubscriberID = cust.SubscriberID AND maSu.SiteID = cust.SiteID
        STRAIGHT_JOIN CTS_DataCenter.SubscriberGroup AS sg ON sg.SubscriberGroupID = maSu.SubscriberGroupID AND sg.IsActive = 1
    ON DUPLICATE KEY UPDATE AssociationTypeName =  CONCAT(Temp_AssociatedAccount.AssociationTypeName, ', ', sta.ItemName),
							AssociationDate = LEAST(Temp_AssociatedAccount.AssociationDate, cuAs.AssociationDate);

    /* Get category */         
    IF EXISTS (SELECT 1 FROM Temp_CategoryID WHERE CategoryID = 0) THEN
		INSERT IGNORE INTO Temp_Classification(CTSCustID, ParentID)
		SELECT	tmpAcc.CTSCustID
			,	0
		FROM Temp_AssociatedAccount AS tmpAcc
			LEFT JOIN CTS_DataCenter.CTSCustomerClassification AS cate ON cate.CTSCustID = tmpAcc.CTSCustID 
		WHERE tmpAcc.RoleID = CONST_ROLEID_MEMBER
			AND cate.CTSCustID IS NULL;
        
        INSERT IGNORE INTO Temp_Classification(CTSCustID, ParentID)
		SELECT	tmpAcc.CTSCustID
			,	0
		FROM Temp_AssociatedAccount AS tmpAcc
			LEFT JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cate ON cate.CTSCustID = tmpAcc.CTSCustID 
		WHERE tmpAcc.RoleID IN (CONST_ROLEID_AGENT,CONST_ROLEID_MASTER,CONST_ROLEID_SUPER)
			AND cate.CTSCustID IS NULL;        
    END IF;
    
   INSERT IGNORE INTO Temp_Classification(CTSCustID, ParentID, CategoryIDs, CategoryNames, ColorTypeIDs, IsPAProbation)  
   SELECT	tmpAcc.CTSCustID
		,	cat.ParentID -- Each Customer has only 1 ParentID
		,	GROUP_CONCAT(DISTINCT cat.CategoryID SEPARATOR ',') 
        ,	GROUP_CONCAT(DISTINCT cat.CategoryName SEPARATOR ',')
        ,	GROUP_CONCAT((SELECT cat.ColorTypeID FROM CTS_DataCenter.CustomerCategory AS cate2 WHERE cate2.CategoryID = cat.CategoryID) ORDER BY cat.CategoryPriority ASC)
		,	MAX(cat.IsPAProbation)
	FROM	Temp_AssociatedAccount AS tmpAcc
		,	LATERAL (	SELECT clss.CTSCustID, cat.ParentID
						FROM CTS_DataCenter.CTSCustomerClassification AS clss
							INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = clss.CategoryID AND cat.IsActive = 1
						WHERE clss.CTSCustID = tmpAcc.CTSCustID AND clss.ParentID <> CONST_PARENTID_WRAPPER
						ORDER BY cat.CategoryPriority ASC
						LIMIT 1) AS cate
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON clss.CTSCustID = cate.CTSCustID AND clss.ParentID = cate.ParentID
		INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = clss.CategoryID AND cat.IsActive = 1
        INNER JOIN Temp_CategoryID AS tmpCate ON tmpCate.CategoryID = cat.CategoryID
	WHERE tmpAcc.RoleID = CONST_ROLEID_MEMBER
	GROUP BY tmpAcc.CTSCustID, cat.ParentID;
    
    #===========================AGENT===================================================
	INSERT IGNORE INTO Temp_Classification(CTSCustID, ParentID, CategoryIDs, CategoryNames, ColorTypeIDs, IsPAProbation)
	SELECT	tmpAcc.CTSCustID
		,	cat.ParentID -- Each Customer has only 1 ParentID
		,	GROUP_CONCAT(DISTINCT cat.CategoryID SEPARATOR ',') 
        ,	GROUP_CONCAT(DISTINCT cat.CategoryName SEPARATOR ',')
		,	GROUP_CONCAT((SELECT cat.ColorTypeID FROM CTS_DataCenter.CustomerCategoryAgency AS cate2 WHERE cate2.CategoryID = cat.CategoryID) ORDER BY cat.CategoryPriority ASC)
		,	MAX(cat.IsPAProbation)
	FROM	Temp_AssociatedAccount AS tmpAcc
		,	LATERAL (	SELECT clss.CTSCustID, cat.ParentID
						FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clss
							INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = clss.CategoryID AND cat.IsActive = 1
						WHERE clss.CTSCustID = tmpAcc.CTSCustID
						ORDER BY cat.CategoryPriority ASC
						LIMIT 1) AS cate
		INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS clss ON clss.CTSCustID = cate.CTSCustID AND clss.ParentID = cate.ParentID
		INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = clss.CategoryID AND cat.IsActive = 1
        INNER JOIN Temp_CategoryID AS tmpCate ON tmpCate.CategoryID = cat.CategoryID
	WHERE tmpAcc.RoleID IN (CONST_ROLEID_AGENT,CONST_ROLEID_MASTER,CONST_ROLEID_SUPER) 
	GROUP BY tmpAcc.CTSCustID, cat.ParentID;
    
    /* Update IsFiltered */
    UPDATE 	Temp_AssociatedAccount AS tmpAcc
		INNER JOIN Temp_SubscriberID AS tmpSub ON tmpSub.SubscriberID = tmpAcc.SubscriberID
        INNER JOIN Temp_AccountStatusID AS tmpSt ON tmpSt.AccountStatusID = tmpAcc.AccountStatusID
        INNER JOIN Temp_Classification AS tmpCS ON tmpCS.CTSCustID = tmpAcc.CTSCustID
    SET tmpAcc.IsFiltered = 1;

	/* Return data */
	SELECT	tmpAcc.CTSCustID
		,	tmpAcc.CustId
        , 	tmpAcc.CustSubId
        ,	tmpAcc.RoleID
		,	tmpAcc.SubscriberID
		, 	tmpAcc.SubscriberName
        , 	tmpAcc.SiteID
		, 	tmpAcc.SiteName
		, 	tmpAcc.UserName
		, 	tmpAcc.UserName2
		,	tmpAcc.AccountStatusGroup AS StatusGroup
		, 	tmpAcc.AccountStatusID AS StatusID
		, 	tmpAcc.AccountStatusName AS StatusName
		, 	tmpAcc.AssociationTypeName
        , 	tmpAcc.AssociationStatus
		, 	tmpAcc.AssociationDate
		,	tmpCS.ParentID AS ParentIDs
		,	tmpCS.CategoryIDs AS CategoryIDs
		,	tmpCS.CategoryNames AS CategoryNames
		,	tmpCS.ColorTypeIDs AS ColorTypeIDs
		,	tmpCS.IsPAProbation AS IsProbation
		,	t.GroupIDList AS GroupIDs
		,	t.OriginGroupIDList AS OriginGroupIDs
		,	CASE WHEN tmpCS.ParentID IN (CONST_PARENTID_PA, CONST_AGENCY_PARENTID_PA ) THEN 1 ELSE 0 END AS IsPA
		,	CASE WHEN tmpCS.ParentID = CONST_PARENTID_POTENTIALPA THEN 1 ELSE 0 END AS IsPotentialPA
	FROM Temp_AssociatedAccount AS tmpAcc
		INNER JOIN Temp_Classification AS tmpCS ON tmpCS.CTSCustID = tmpAcc.CTSCustID
		LEFT JOIN Temp_CustomerGroup AS t ON tmpAcc.CustID = t.CustID
	WHERE tmpAcc.IsFiltered = 1
	ORDER BY  tmpAcc.SubscriberName ASC, tmpAcc.AssociationStatus ASC , tmpAcc.AccountStatusGroup ASC, tmpAcc.AccountStatusID ASC,  tmpAcc.AssociationDate DESC, tmpAcc.CTSCustID ASC
	LIMIT ip_Take
	OFFSET ip_Skip; 
 
	SELECT COUNT(1) 
	INTO op_TotalItems
	FROM Temp_AssociatedAccount
    WHERE IsFiltered = 1; 
END$$
DELIMITER ;