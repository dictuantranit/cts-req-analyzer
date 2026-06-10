/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Common_BettypeSetting_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Common_BettypeSetting_Get`(
		ip_FunctionID 					TINYINT
	,	ip_SportTypeIDList 				TEXT
	,	ip_BettypeIDList 				TEXT
	,	ip_IsFilterMMDetection 			BOOLEAN
    ,	ip_IsFilterMMParlayDetection	BOOLEAN
	,	ip_IsShowDetailsX				BOOLEAN
    ,	ip_Status						TINYINT 
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20231122@Casey.Huynh
		Task :		Get Bettype List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20231122@Casey.Huynh: Created [Redmine ID: #196396]
            -	20240530@Casey.Huynh: Saba Group Betting [Redmine ID: #191972]
            -	20240822@Casey.Huynh: Seperate BettypeSetting to New Table [Redmine ID: #207397]
            -	20250214@Casey.Huynh: Update Bettype Order for MM [Redmine ID: #217782]
            -	20250319@Thomas.Nguyen: Return SportOrder [Redmine ID: #219681]
            -   20250811@Casey.Huynh: Update Return BettypeDetails X > 9 [Redmine ID: #235043]

		Param's Explanation (filtered by):
        	ip_FunctionID: 1, 2
		,	ip_SportTypeIDList: NULL-Gett ALL Bettype, else '1,2,43..'
		,	ip_BettypeIDList: NULL: Gett ALL Bettype, else '1,3,7...'
		,	ip_IsFilterMMDetection: 1- Get DetectMonitor Bettype Only
		,	ip_IsShowDetailsX BOOLEAN   #Show filter basketball Quater 1, quater 2.. )
        
		Example:        
		#Service MM Detection Single Ticket:
		 CALL CTS_DC_Common_BettypeSetting_Get(@ip_FunctionID:=1,@ip_SportTypeIDList:=NULL,@ip_BettypeIDList:=NULL,@ip_IsFilterMMDetection:=1, @ip_IsFilterMMParlayDetection:=0, @ip_IsShowDetailsX:=0,@ip_Status:=1); 
		#Service MM Detection Parlay Ticket: 
		CALL CTS_DC_Common_BettypeSetting_Get(@ip_FunctionID:=1,@ip_SportTypeIDList:=NULL,@ip_BettypeIDList:=NULL,@ip_IsFilterMMDetection:=0, @ip_IsFilterMMParlayDetection:=1, @ip_IsShowDetailsX:=0,@ip_Status:=1); 
		#Filter MM: 
		CALL CTS_DC_Common_BettypeSetting_Get(@ip_FunctionID:=1,@ip_SportTypeIDList:=NULL,@ip_BettypeIDList:=NULL,@ip_IsFilterMMDetection:=0, @ip_IsFilterMMParlayDetection:=0, @ip_IsShowDetailsX:=1,@ip_Status:=1);	
        #WEB MM Detection Parlay Ticket: 
		CALL CTS_DC_Common_BettypeSetting_Get(@ip_FunctionID:=NULL,@ip_SportTypeIDList:=NULL,@ip_BettypeIDList:=NULL,@ip_IsFilterMMDetection:=0, @ip_IsFilterMMParlayDetection:=1, @ip_IsShowDetailsX:=0,@ip_Status:=1); 
		
*/
    
	DROP TEMPORARY TABLE IF EXISTS Temp_SportTypeID;
	CREATE TEMPORARY TABLE Temp_SportTypeID (
			SportTypeID	INT
        ,   INDEX IX_Temp_SportTypeID(SportTypeID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_BettypeID;
	CREATE TEMPORARY TABLE Temp_BettypeID (
			BettypeID	INT
		,   INDEX IX_Temp_BettypeID(BettypeID)
	);
	IF ip_FunctionID IS NULL THEN

		SELECT DISTINCT bs.BetTypeID
					, 	(CASE WHEN js.NameDetailsX <> '' THEN REPLACE(bs.BettypeNameDisplay,'[X]', js.NameDetailsX)  
									ELSE bs.BettypeNameDisplay END) AS BettypeNameDisplay					
					,	(CASE WHEN js.NameDetailsX <> '' THEN REPLACE(bs.BetIDPattern,'X',js.NameDetailsX)  
									ELSE 0 END) AS BetID 
                    ,	bs.BetChoiceType
					,	MAX(CASE WHEN bs.BetteamOrder = 1 THEN bs.BetTeamDB ELSE NULL END) AS BetChoiceHome
					,	MAX(CASE WHEN bs.BetteamOrder = 1 THEN bs.BetTeamShortName ELSE NULL END) AS BetChoiceHomeDisplay
					,	MAX(CASE WHEN bs.BetteamOrder = 1 THEN bs.BetTeamName ELSE NULL END) AS BetChoiceHomeFullName
					,	MAX(CASE WHEN bs.BetteamOrder = 2 THEN bs.BetTeamDB ELSE NULL END) AS BetChoiceAway
					,	MAX(CASE WHEN bs.BetteamOrder = 2 THEN bs.BetTeamShortName ELSE NULL END) AS BetChoiceAwayDisplay
					,	MAX(CASE WHEN bs.BetteamOrder = 2 THEN bs.BetTeamName ELSE NULL END) AS BetChoiceAwayFullName
        FROM CTS_DataCenter.BettypeSetting AS bs
			, JSON_TABLE(CONCAT('["', REPLACE(IFNULL(BetTypeNameDetailsX,''), ',', '","'), '"]'),
								  '$[*]' COLUMNS (NameDetailsX VARCHAR(1) PATH '$')) js
        GROUP BY 		bs.BetTypeID
					,	bs.BetIDPattern
					,	js.NameDetailsX
					, 	bs.BetTypeNameDisplay
					,	bs.BetChoiceType
					,	bs.BetIDPattern;       

    ELSE 
		IF(ip_IsFilterMMDetection = 0)
		THEN
			SET ip_IsFilterMMDetection = NULL;
		END IF;
		
		IF(ip_IsFilterMMParlayDetection = 0)
		THEN
			SET ip_IsFilterMMParlayDetection = NULL;
		END IF;

		IF ip_SportTypeIDList IS NOT NULL THEN		
			SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_SportTypeID(SportTypeID) VALUES ('", REPLACE(ip_SportTypeIDList, ",", "'),('"),"');");
			PREPARE stmt1 FROM @sql;
			EXECUTE stmt1;  
			
		ELSE 
			INSERT INTO Temp_SportTypeID(SportTypeID)
			VALUES(NULL);
		END IF;
		
		IF ip_BetTypeIDList IS NOT NULL THEN
			SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_BettypeID(BettypeID) VALUES ('", REPLACE(ip_BetTypeIDList, ",", "'),('"),"');");
			PREPARE stmt1 FROM @sql;
			EXECUTE stmt1;
		ELSE 
			INSERT INTO Temp_BettypeID(BettypeID)
			VALUES(NULL);
		END IF;
		
		IF ip_IsShowDetailsX = 1 THEN    

			SELECT  (CASE WHEN sbs.LeagueGroupID = 0 THEN NULL ELSE LeagueGroupID END) AS LeagueGroupID
				,	sbs.SportTypeID
				,	sbs.SportName
				,	bs.BetTypeID
				,	(CASE WHEN js.NameDetailsX <> '' THEN REPLACE(sbs.BettypeNameDisplay,'[X]', js.NameDetailsX)   
								ELSE REPLACE(sbs.BettypeNameDisplay,'[X]', 'X')  END) AS BettypeNameDisplay
				,	bs.BetChoiceType            
				,	bs.BetIDPattern
				,	sbs.IsMMDetection
				,	sbs.IsDefaultSelected
				,	bs.BettypeOrder
				,	IFNULL(js.NameDetailsX,'') AS  NameDetailsX
				,	MAX(CASE WHEN bs.BetteamOrder = 1 THEN bs.BetTeamDB ELSE NULL END) AS BetChoiceHome
				,	MAX(CASE WHEN bs.BetteamOrder = 1 THEN bs.BetTeamShortName ELSE NULL END) AS BetChoiceHomeDisplay
				,	MAX(CASE WHEN bs.BetteamOrder = 1 THEN bs.BetTeamName ELSE NULL END) AS BetChoiceHomeFullName
				,	MAX(CASE WHEN bs.BetteamOrder = 2 THEN bs.BetTeamDB ELSE NULL END) AS BetChoiceAway
				,	MAX(CASE WHEN bs.BetteamOrder = 2 THEN bs.BetTeamShortName ELSE NULL END) AS BetChoiceAwayDisplay
				,	MAX(CASE WHEN bs.BetteamOrder = 2 THEN bs.BetTeamName ELSE NULL END) AS BetChoiceAwayFullName
				,	sbs.SportOrder
			FROM CTS_DataCenter.SportBettypeSetting AS sbs
				INNER JOIN CTS_DataCenter.BettypeSetting AS bs ON bs.BettypeID = sbs.BetTypeID
				INNER JOIN Temp_SportTypeID AS tmpSt ON IFNULL(tmpSt.SportTypeID,sbs.SportTypeID) = sbs.SportTypeID
				INNER JOIN Temp_BettypeID AS tmpBt ON IFNULL(tmpBt.BettypeID,sbs.BettypeID) = sbs.BettypeID
				, JSON_TABLE(CONCAT('["', REPLACE(IFNULL(sbs.BetTypeNameDetailsX,''), ',', '","'), '"]'),
							  '$[*]' COLUMNS (NameDetailsX SMALLINT PATH '$')) js
			WHERE 	sbs.Status = ip_Status
				AND	sbs.FunctionID = ip_FunctionID			
				AND	sbs.IsMMDetection = IFNULL(ip_IsFilterMMDetection,sbs.IsMMDetection) 
				AND sbs.IsMMParlayDetection = IFNULL(ip_IsFilterMMParlayDetection,sbs.IsMMParlayDetection)
			GROUP BY sbs.LeagueGroupID
				,	sbs.SportTypeID
				,	sbs.SportName                   
				,	sbs.IsMMDetection
				,	sbs.IsDefaultSelected
				,	bs.BettypeOrder
				,	sbs.BetTypeID     
				,	bs.BetChoiceType
				,	bs.BetIDPattern
				,	js.NameDetailsX
				,	sbs.BettypeNameDisplay
				,	sbs.SportOrder
			ORDER BY LeagueGroupID, bs.BettypeOrder, js.NameDetailsX; 
		ELSE	
		
			SELECT  (CASE WHEN sbs.LeagueGroupID = 0 THEN NULL ELSE LeagueGroupID END) AS LeagueGroupID
				,	sbs.SportTypeID
				,	sbs.SportName
				,	sbs.BetTypeID
				, 	REPLACE(bs.BettypeNameDisplay,'[X]', 'X') AS BetTypeNameDisplay
				,	bs.BetChoiceType
				,	bs.BetIDPattern
				,	sbs.IsMMDetection
				,	sbs.IsDefaultSelected
				,	bs.BettypeOrder
				,	MAX(CASE WHEN bs.BetteamOrder = 1 THEN bs.BetTeamDB ELSE NULL END) AS BetChoiceHome
				,	MAX(CASE WHEN bs.BetteamOrder = 1 THEN bs.BetTeamShortName ELSE NULL END) AS BetChoiceHomeDisplay
				,	MAX(CASE WHEN bs.BetteamOrder = 1 THEN bs.BetTeamName ELSE NULL END) AS BetChoiceHomeFullName
				,	MAX(CASE WHEN bs.BetteamOrder = 2 THEN bs.BetTeamDB ELSE NULL END) AS BetChoiceAway
				,	MAX(CASE WHEN bs.BetteamOrder = 2 THEN bs.BetTeamShortName ELSE NULL END) AS BetChoiceAwayDisplay
				,	MAX(CASE WHEN bs.BetteamOrder = 2 THEN bs.BetTeamName ELSE NULL END) AS BetChoiceAwayFullName
				,	sbs.SportOrder
			FROM CTS_DataCenter.SportBettypeSetting AS sbs
				INNER JOIN CTS_DataCenter.BettypeSetting AS bs ON bs.BettypeID = sbs.BetTypeID
				INNER JOIN Temp_SportTypeID AS tmpSt ON IFNULL(tmpSt.SportTypeID,sbs.SportTypeID) = sbs.SportTypeID
				INNER JOIN Temp_BettypeID AS tmpBt ON IFNULL(tmpBt.BettypeID,sbs.BettypeID) = sbs.BettypeID
			WHERE 	sbs.Status = ip_Status
				AND	sbs.FunctionID = ip_FunctionID
				AND	sbs.IsMMDetection = IFNULL(ip_IsFilterMMDetection,sbs.IsMMDetection) 
				AND sbs.IsMMParlayDetection = IFNULL(ip_IsFilterMMParlayDetection,sbs.IsMMParlayDetection)
			GROUP BY sbs.LeagueGroupID
				,	sbs.SportTypeID
				,	sbs.SportName                   
				,	sbs.IsMMDetection
				,	sbs.IsDefaultSelected
				,	bs.BettypeOrder
				,	sbs.BetTypeID     
				,	bs.BetChoiceType
				,	bs.BetIDPattern
				,	bs.BettypeNameDisplay
				,	sbs.SportOrder
			ORDER BY LeagueGroupID, bs.BettypeOrder; 
			
		END IF;
	END IF;
END$$
DELIMITER ;

	