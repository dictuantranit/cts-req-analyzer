/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_ViewHistory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_ViewHistory`(
	IN ip_CTSCustID 	BIGINT
)
    SQL SECURITY INVOKER
BEGIN
  /*
		Created:	20201214@Irena.Vo
		Task:		View History for customer category in CTS
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20210105@Irena.Vo: 		Created. Update logic SP [RedmineID: #145951]
			- 20210226@Irena.Vo: 		Get TaggingType flag for log [RedmineID: #150454]
			- 20210401@Irena.Vo: 		Update View Log [RedmineID: #152249]
			- 20210525@Irena.Vo: 		Change view log: CustID -> CTSCustID [RedmineID: #152965] 
			- 20210610@Irena.Vo: 		Write log for Inactive Account [RedmineID: #156465] 
			- 20210722@Irena.Vo: 		Refactor SP [RedmineID: #157203] 
			- 20210727@Long.Luu: 		Return more data for TW's categories [RedmineID: #155956] 
			- 20210907@Long.Luu: 		Update Robot Users rules  [Redmine ID: #161232]
			- 20211116@Aries.Nguyen: 	Return history with CTSUser is null[Redmine ID: #156935]
			- 20220510@Irena.Vo: 		Update for return CreatedBy [Redmine ID: #171512]
			- 20220519@Aries.Nguyen: 	Renovate the Category Log History [Redmine ID: #172560]
			- 20200705@Casey.Huynh: 	Add New Category LicVIP, LicBA [Redmine ID: #174219]       
			- 20220817@Long.Luu: 		Rearrange CC's IDs [Redmine ID: #175698]
			- 20220913@Casey.Huynh: 	Update Remark [Redmine ID: #176976]
			- 20230315@Victoria.Le:		Add Robot Imperva [Redmine ID: #184773]
			- 20230404@Victoria.Le		TVS Abnormal Bet and Abnormal Account - Add IsParlay,SportType,IssueTypeId [Redmine ID: #185319] 
			- 20230404@Victoria.Le		Return First5TWGBTicketCount [Redmine ID: #195060] 
			- 20240626@Thomas.Nguyen:	Renovate CC phase 2 - Get remark from template [Redmine ID: #205317]
            - 20241210@Casey.Huynh: 	New Robot AI, Bot Login Pattern [Redmine ID: #214655]
			- 20250909@Logan.Nguyen:	Get Remark for INITIALSMART_B, INITIALSMART_B_LOSING [Redmine ID: #237405]
			- 20250922@Logan.Nguyen: 	Adjust Performance Calculation Logic for Initial Smart - CC2700 - Initial Smart (Losing) - CC2701 [Redmine ID: #239118]
			
		Param's Explanation (filtered by):		
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_ViewHistory(25);
	*/  
 
		DECLARE CONST_CATEID_LICBA 						INT;
    	DECLARE CONST_CATEID_LICVIPSUSPICIOUS 			INT;
    	DECLARE CONST_CATEID_LICVIPDANGEROUS 			INT;
		DECLARE	CONST_CATEID_UNAUTHORIZEDLOGIN 			INT;
		DECLARE	CONST_CATEID_UNAUTHORIZEDLOGINLOSING	INT;
		DECLARE	CONST_CATEID_EARLYWARNING 				INT;
		DECLARE	CONST_CATEID_EARLYWARNINGLOSING			INT;
		DECLARE	CONST_CATEID_INITIALGB		 			INT;
		DECLARE	CONST_CATEID_INITIALGBLOSING			INT;
		DECLARE	CONST_CATEID_INITIALSMART		 		INT;
		DECLARE	CONST_CATEID_INITIALSMARTLOSING			INT;
		DECLARE CONST_CATEID_ROBOTUSER 					INT;
    	DECLARE CONST_CATEID_ROBOTOCRD 					INT;
        DECLARE CONST_CATEID_BOTLOGINPATTERN 			INT;
    	DECLARE CONST_CATEID_ROBOTUSERLOSING 			INT;
    	DECLARE CONST_CATEID_ROBOTOCRDLOSING 			INT;
        DECLARE CONST_CATEID_BOTLOGINPATTERNLOSING		INT;
		DECLARE	CONST_CATEID_INITIALSMART_B		 		INT;
		DECLARE	CONST_CATEID_INITIALSMART_B_LOSING		INT;

		DECLARE CONST_REMARKID_TVSREQUESTIDPARLAY		INT;
    	DECLARE CONST_REMARKID_TVSBETIDPARLAY			INT;
    	DECLARE CONST_REMARKID_ROBOTFROMTW				INT;
    	DECLARE CONST_REMARKID_ROBOTFROMIMPERVA			INT;
    	DECLARE CONST_REMARKID_ROBOTFROMAI				INT;
    	DECLARE CONST_REMARKID_ROBOTFROMCTS				INT;
    	DECLARE CONST_REMARKID_ROBOTFROMTVSREQUESTID	INT;
    	DECLARE CONST_REMARKID_ROBOTFROMTVSBETID		INT;
		DECLARE CONST_REMARKID_NOTSHOWDETAILS			INT;
		DECLARE CONST_REMARKID_RESCANROBOT				INT;

		DECLARE lv_LicBA_CC								INT UNSIGNED;
		DECLARE lv_LicVIPProblem_CC						INT UNSIGNED;
		DECLARE lv_LicVIPNormal_CC						INT UNSIGNED;
		DECLARE lv_LicBA_CategoryName					VARCHAR(50);
        DECLARE lv_LicVIPProblem_CategoryName			VARCHAR(50);
        DECLARE lv_LicVIPNormal_CategoryName			VARCHAR(50);        
        
		SET CONST_CATEID_LICBA 		                    = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICBA');
    	SET CONST_CATEID_LICVIPSUSPICIOUS 		        = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPSUSPICIOUS');
    	SET CONST_CATEID_LICVIPDANGEROUS 		        = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPDANGEROUS');
		SET CONST_CATEID_UNAUTHORIZEDLOGIN 		        = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_UNAUTHORIZEDLOGIN');
		SET CONST_CATEID_UNAUTHORIZEDLOGINLOSING 		= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_UNAUTHORIZEDLOGINLOSING');
		SET CONST_CATEID_EARLYWARNING 		    		= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_EARLYWARNING');
		SET CONST_CATEID_EARLYWARNINGLOSING 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_EARLYWARNINGLOSING');
		SET CONST_CATEID_INITIALGB 		                = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INITIALGB');
		SET CONST_CATEID_INITIALGBLOSING 		        = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INITIALGBLOSING');
		SET CONST_CATEID_INITIALSMART 		            = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INITIALSMART');
		SET CONST_CATEID_INITIALSMARTLOSING 		    = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INITIALSMARTLOSING');
		SET CONST_CATEID_ROBOTUSER 		                = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTUSER');
    	SET CONST_CATEID_ROBOTOCRD 		                = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTOCRD');
    	SET CONST_CATEID_ROBOTUSERLOSING 		        = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTUSERLOSING');
    	SET CONST_CATEID_ROBOTOCRDLOSING 		        = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTOCRDLOSING');
        SET CONST_CATEID_BOTLOGINPATTERN 		        = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_BOTLOGINPATTERN');
        SET CONST_CATEID_BOTLOGINPATTERNLOSING	        = CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_BOTLOGINPATTERNLOSING');
		SET CONST_CATEID_INITIALSMART_B		            = 30400;
		SET CONST_CATEID_INITIALSMART_B_LOSING 		    = 35400;

		SET CONST_REMARKID_TVSREQUESTIDPARLAY       	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_TVSREQUESTIDPARLAY');
    	SET CONST_REMARKID_TVSBETIDPARLAY           	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_TVSBETIDPARLAY');
    	SET CONST_REMARKID_ROBOTFROMTW              	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_ROBOTFROMTW');
    	SET CONST_REMARKID_ROBOTFROMIMPERVA         	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_ROBOTFROMIMPERVA');
    	SET CONST_REMARKID_ROBOTFROMAI              	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_ROBOTFROMAI');
    	SET CONST_REMARKID_ROBOTFROMCTS             	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_ROBOTFROMCTS');
    	SET CONST_REMARKID_ROBOTFROMTVSREQUESTID    	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_ROBOTFROMTVSREQUESTID');
    	SET CONST_REMARKID_ROBOTFROMTVSBETID        	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_ROBOTFROMTVSBETID');
		SET CONST_REMARKID_NOTSHOWDETAILS        		= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_NOTSHOWDETAILS');
		SET CONST_REMARKID_RESCANROBOT 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_REMARKID_RESCANROBOT');

        SELECT cat.CategoryName, cat.CustomerClass
        INTO lv_LicVIPProblem_CategoryName, lv_LicVIPProblem_CC
        FROM CTS_DataCenter.CustomerCategory AS cat
        WHERE cat.CategoryID = CONST_CATEID_LICVIPDANGEROUS;
        
        SELECT cat.CategoryName, cat.CustomerClass
        INTO lv_LicVIPNormal_CategoryName, lv_LicVIPNormal_CC
        FROM CTS_DataCenter.CustomerCategory AS cat
        WHERE cat.CategoryID = CONST_CATEID_LICVIPSUSPICIOUS;        
        
        SELECT cat.CategoryName, cat.CustomerClass
        INTO lv_LicBA_CategoryName, lv_LicBA_CC
        FROM CTS_DataCenter.CustomerCategory AS cat
        WHERE cat.CategoryID = CONST_CATEID_LICBA;  
        
		DROP TEMPORARY TABLE IF EXISTS Temp_CustRemark;
		CREATE TEMPORARY TABLE 	Temp_CustRemark (
					HistoryID			BIGINT UNSIGNED NOT NULL PRIMARY KEY
				,	CustID				BIGINT UNSIGNED
				,	CategoryID			INT
				,	SourceTypeID		SMALLINT UNSIGNED
				,	RemarkID			SMALLINT UNSIGNED
				,	Remark				TEXT
				,	RoleID				TINYINT
				,	SportType			SMALLINT
				,	IsParlay			BIT(1)
				,	LastModifiedDate	DATETIME	
				,	KEY IX_Temp_CustRemark_CateID(CategoryID)	
		);

		INSERT IGNORE INTO Temp_CustRemark(HistoryID, CustID, CategoryID, SourceTypeID, RoleID, SportType, IsParlay, LastModifiedDate)
		SELECT  clss.ID
			,	clss.CustID
            ,   clss.CategoryID
			,	clss.SourceTypeID
			,	cus.RoleID
			,	clss.SportType
			,	clss.IsParlay
			,	clss.LastModifiedDate
		FROM CTS_DataCenter.CTSCustomerClassification_History AS clss
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON clss.CustID = cus.CustID
		WHERE 	clss.CTSCustID = ip_CTSCustID AND clss.IsDataChanged = 1;

		UPDATE Temp_CustRemark AS tmp
			INNER JOIN CTS_DataCenter.CustomerCategorySettings AS cs ON cs.CategoryID = tmp.CategoryID AND cs.RemarkTemplateID IS NOT NULL
            INNER JOIN CTS_DataCenter.CustomerClassification_Remark AS cr ON cr.RemarkID = cs.RemarkTemplateID
		SET tmp.Remark = cr.RemarkTemplate;

		DROP TEMPORARY TABLE IF EXISTS Temp_CustRemark_Duplicate; 
		CREATE TEMPORARY TABLE Temp_CustRemark_Duplicate LIKE Temp_CustRemark;
		INSERT INTO Temp_CustRemark_Duplicate(HistoryID, CustID, CategoryID, SourceTypeID, Remark)
		SELECT	HistoryID
			,	CustID
			,	CategoryID
			,	SourceTypeID
			,	Remark
		FROM Temp_CustRemark
		WHERE Remark IS NULL;

		WITH CTECustRemarkID AS (
        SELECT  tmp.HistoryID
			,	tmp.CustID
            ,   tmp.CategoryID
            ,   CASE
                    WHEN tmp.CategoryID IN (CONST_CATEID_ROBOTUSER, CONST_CATEID_ROBOTOCRD
											, CONST_CATEID_ROBOTUSERLOSING, CONST_CATEID_ROBOTOCRDLOSING
                                            , CONST_CATEID_BOTLOGINPATTERN, CONST_CATEID_BOTLOGINPATTERNLOSING
                                            ) AND tmp.SourceTypeID <> CONST_REMARKID_RESCANROBOT THEN
                        CASE    WHEN clss.IsFromTW = 1 											THEN CONST_REMARKID_ROBOTFROMTW
                                WHEN clss.IsFromImperva = 1 									THEN CONST_REMARKID_ROBOTFROMIMPERVA
                                WHEN clss.IsFromAI = 1 											THEN CONST_REMARKID_ROBOTFROMAI
                                WHEN clss.IsFromCTS = 1 										THEN CONST_REMARKID_ROBOTFROMCTS
                                WHEN clss.IsFromTVS = 1 AND clss.TVSRequestID > 0 				THEN CONST_REMARKID_ROBOTFROMTVSREQUESTID
                                WHEN clss.IsFromTVS = 1 AND IFNULL(clss.TVSRequestID,0) = 0 	THEN CONST_REMARKID_ROBOTFROMTVSBETID END
					WHEN clss.IsFromTVS = 1 AND clss.TVSRequestID > 0 THEN CONST_REMARKID_TVSREQUESTIDPARLAY
                    WHEN clss.IsFromTVS = 1 AND IFNULL(clss.TVSRequestID,0) = 0 THEN CONST_REMARKID_TVSBETIDPARLAY
                END AS RemarkID
        FROM Temp_CustRemark_Duplicate AS tmp
			INNER JOIN CTS_DataCenter.CTSCustomerClassification_History AS clss ON tmp.HistoryID = clss.ID
        )
		UPDATE Temp_CustRemark AS tmp
			INNER JOIN CTECustRemarkID AS cte ON cte.HistoryID = tmp.HistoryID
        	INNER JOIN CTS_DataCenter.CustomerClassification_Remark AS cr ON cr.RemarkID = cte.RemarkID
		SET		tmp.Remark = cr.RemarkTemplate
			,	tmp.RemarkID = cr.RemarkID;

		IF EXISTS (SELECT 1 FROM Temp_CustRemark WHERE RemarkID IN (CONST_REMARKID_TVSREQUESTIDPARLAY, CONST_REMARKID_TVSBETIDPARLAY)) THEN
			UPDATE Temp_CustRemark AS tmp
			SET tmp.Remark = REPLACE(tmp.Remark,'| Win loss: [Winloss] ','')
			WHERE tmp.RemarkID IN (CONST_REMARKID_TVSREQUESTIDPARLAY, CONST_REMARKID_TVSBETIDPARLAY) AND tmp.RoleID <> 1;

			UPDATE Temp_CustRemark AS tmp
			SET tmp.Remark = REPLACE(tmp.Remark,'| Sport: [SportName] ','')
			WHERE tmp.RemarkID IN (CONST_REMARKID_TVSREQUESTIDPARLAY, CONST_REMARKID_TVSBETIDPARLAY) AND IFNULL(tmp.SportType,0) = 0;

			UPDATE Temp_CustRemark AS tmp
			SET tmp.Remark = REPLACE(tmp.Remark,'| Parlay','')
			WHERE tmp.RemarkID IN (CONST_REMARKID_TVSREQUESTIDPARLAY, CONST_REMARKID_TVSBETIDPARLAY) AND IFNULL(tmp.IsParlay,0) = 0;
		END IF;

		UPDATE Temp_CustRemark AS tmp
			INNER JOIN CTS_DataCenter.CustomerClassification_Remark AS cr ON cr.RemarkID = tmp.SourceTypeID
		SET tmp.Remark = cr.RemarkTemplate
		WHERE tmp.Remark IS NULL AND tmp.SourceTypeID IS NOT NULL;

		IF EXISTS (SELECT 1 FROM Temp_CustRemark WHERE CategoryID IN (CONST_CATEID_UNAUTHORIZEDLOGIN, CONST_CATEID_UNAUTHORIZEDLOGINLOSING)) THEN
            UPDATE Temp_CustRemark AS tmp,
			LATERAL (
				SELECT cld.CustID, cld.FirstBetDate, cld.SourceCreatedDate, cld.Bot, cld.BotTransPercentage, cld.InvalidBrowser, cld.InvalidBrowserInfoTransPercentage
				FROM CTS_DataCenter.CustomerLoginInfoDetection AS cld
				WHERE cld.CustID = tmp.CustID AND tmp.LastModifiedDate >= cld.InsertedTime
				ORDER BY cld.InsertedTime DESC
				LIMIT 1
			) AS cd
            SET tmp.Remark = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(tmp.Remark,'[FBDate]', IFNULL(DATE_FORMAT(cd.FirstBetDate, '%b %d, %Y'),''))
								,'[DetectedDate]', IFNULL(DATE_FORMAT(cd.SourceCreatedDate, '%b %d, %Y'),'')), '[Bot]', IFNULL(cd.Bot,0)),'[BotPCT]',IFNULL(cd.BotTransPercentage,0)),'[InvalidBrowser]'
                                ,IFNULL(cd.InvalidBrowser,0)),'[InvalidBrowserPCT]',IFNULL(cd.InvalidBrowserInfoTransPercentage,0))
            WHERE tmp.CategoryID IN (CONST_CATEID_UNAUTHORIZEDLOGIN, CONST_CATEID_UNAUTHORIZEDLOGINLOSING);
		END IF;

        IF EXISTS (SELECT 1 FROM Temp_CustRemark WHERE CategoryID IN (CONST_CATEID_EARLYWARNING, CONST_CATEID_EARLYWARNINGLOSING)) THEN
            UPDATE Temp_CustRemark AS tmp
                INNER JOIN CTS_DataCenter.Customer_DangerousScore AS cds ON cds.CustID = tmp.CustID
            SET tmp.Remark = REPLACE(REPLACE(tmp.Remark,'[DetectedDate]', IFNULL(DATE_FORMAT(cds.ClassifiedDate, '%b %d, %Y'),'')), '[DangerousScore]', IFNULL(CAST(cds.ClassifiedScore*100 AS DECIMAL(5,2)),0))
            WHERE tmp.CategoryID IN (CONST_CATEID_EARLYWARNING, CONST_CATEID_EARLYWARNINGLOSING);
		END IF;

        IF EXISTS (SELECT 1 FROM Temp_CustRemark WHERE CategoryID IN (CONST_CATEID_INITIALSMART, CONST_CATEID_INITIALSMARTLOSING, CONST_CATEID_INITIALSMART_B, CONST_CATEID_INITIALSMART_B_LOSING)) THEN
            UPDATE Temp_CustRemark AS tmp
                INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = tmp.CategoryID
				INNER JOIN CTS_DataCenter.Customer_InitialSmart_BySport AS cis ON cis.CustID = tmp.CustID AND cis.SportType = ccs.SportType
            SET tmp.Remark = REPLACE(REPLACE(tmp.Remark,'[DetectedDate]', IFNULL(DATE_FORMAT(cis.SourceCreatedDate, '%b %d, %Y'),'')), '[Probability]', IFNULL(cis.Probability,0))
            WHERE tmp.CategoryID IN (CONST_CATEID_INITIALSMART, CONST_CATEID_INITIALSMARTLOSING, CONST_CATEID_INITIALSMART_B, CONST_CATEID_INITIALSMART_B_LOSING);
		END IF;

        IF EXISTS (SELECT 1 FROM Temp_CustRemark WHERE CategoryID IN (CONST_CATEID_INITIALGB, CONST_CATEID_INITIALGBLOSING)) THEN
            UPDATE Temp_CustRemark AS tmp
                INNER JOIN CTS_DataCenter.Customer_InitialGroupBetting AS cgb ON cgb.CustID = tmp.CustID
            SET		tmp.Remark = REPLACE(REPLACE(tmp.Remark,'[DetectedDate]', IFNULL(DATE_FORMAT(cgb.SourceCreatedDate, '%b %d, %Y'),'')), '[GBTicketCount]', IFNULL(cgb.GBTicketCount,0))
            WHERE tmp.CategoryID IN (CONST_CATEID_INITIALGB, CONST_CATEID_INITIALGBLOSING);
        END IF;

		SELECT 	temp.LastModifiedDate AS CreatedTime
			,   (CASE WHEN temp.CategoryID IS NULL OR cc1.CustomerClass IS NULL THEN '-' ELSE cc1.CategoryName END) AS CategoryName
			,   (CASE WHEN temp.TargetCC IN (-1, -99) THEN '-' /* -1: Remove, -99: No mapping CC */ ELSE temp.TargetCC END) AS CustomerClass
			,   s.ItemNameDisplay AS SourceTypeName
			, 	s.ItemID AS SourceTypeID
			,   IFNULL(u.UserName, temp.LastModifiedBy) AS CreatedBy
			,	CONCAT_WS(	CASE WHEN temp.SourceTypeID <> CONST_REMARKID_NOTSHOWDETAILS AND temp.TargetCC IN (lv_LicVIPProblem_CC,lv_LicVIPNormal_CC,lv_LicBA_CC) THEN '<br/>' ELSE '' END
						,	CASE WHEN temp.SourceTypeID <> CONST_REMARKID_NOTSHOWDETAILS THEN
								CASE temp.TargetCC	WHEN lv_LicVIPProblem_CC THEN lv_LicVIPProblem_CategoryName
													WHEN lv_LicVIPNormal_CC THEN lv_LicVIPNormal_CategoryName
													WHEN lv_LicBA_CC THEN lv_LicBA_CategoryName ELSE '' END	END
						,	TRIM(TRAILING '|' FROM TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(tmpcr.Remark, 
								'[TVSRequestID]', IFNULL(temp.TVSRequestID,0))
							,   '[Winloss]', IFNULL(FORMAT(temp.WinlossRM, 2),0))
							,   '[Margin]', CASE WHEN IFNULL(temp.TurnOverRM,0) = 0 THEN 0 ELSE ROUND((temp.WinlossRM/temp.TurnOverRM) * 100, 3) END)
							,   '[BetCount]', IFNULL(temp.BetCount,0))
							,   '[TurnOver]', IFNULL(FORMAT(temp.TurnOverRM, 2),0))
							,   '[ActiveDays]', IFNULL(temp.ActiveDays,0))
							,   '[TWGBRate]', IFNULL(temp.TWGroupBettingRate,0))
							,   '[TWDesktopUsageRate]', IFNULL(temp.TWDesktopUsageRate,0))
							,   '[TWTicketRejectRate]', IFNULL(temp.TWTicketRejectRate,0))
							,   '[TWRobotCounter]', IFNULL(temp.RobotCounter,0))
							,   '[MatchID]', CASE WHEN temp.Remark LIKE 'Auto MatchID: %' THEN REPLACE(temp.Remark,'Auto MatchID: ','') ELSE '' END)
							,   '[Remark]', IFNULL(temp.Remark,''))
							,   '[SourceTypeName]', IFNULL(s.ItemNameDisplay,''))
							,	'[CategoryName]', IFNULL(cc1.CategoryName,''))
							))) AS Remark
			,	temp.SportType AS SportType
			,	CASE WHEN tmpcr.Remark LIKE '%[SportName]%' AND temp.SportType IS NOT NULL THEN 1 ELSE 0 END AS IsGetSportName
		FROM 	CTS_DataCenter.CTSCustomerClassification_History AS temp
			LEFT JOIN Temp_CustRemark AS tmpcr ON tmpcr.HistoryID = temp.ID
			LEFT JOIN CTS_DataCenter.CustomerCategory AS cc1 ON temp.CategoryID = cc1.CategoryID
			LEFT JOIN CTS_DataCenter.StaticList AS s ON s.ListID = 4 AND temp.SourceTypeID = s.ItemID
			LEFT JOIN CTS_Admin.CTSUser AS u ON temp.LastModifiedBy = u.UserID
        WHERE 	temp.CTSCustID = ip_CTSCustID AND temp.IsDataChanged = 1
		ORDER BY temp.ID DESC; 
END$$
DELIMITER ;
