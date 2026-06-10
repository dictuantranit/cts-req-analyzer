/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Acc_Rpt_CTS_CheckExistAccumulatedBetcount]
		@ListCustId		VARCHAR(MAX),
		@isResetBalance BIT = 1
AS
/*
	Created: 20241204@Jonas.Huynh
	Task : Customer Classification - CC 210x - Device Association
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20241204@Jonas.Huynh: Created [Redmine ID: #214353]
		- 20251024@Thomas.Nguyen: Fix SonarQube - Sort by CustID ASC [Redmine ID: #241032]

		Param's Explanation:
    Script:
        EXEC [dbo].[Acc_Rpt_CTS_CheckExistAccumulatedBetcount]  @listCustID     = '1,2,1044126,4799',
															    @isResetBalance = 1
*/
BEGIN

    DECLARE @batch    INT = 10000
    DECLARE @count    INT = 0

	DECLARE @SportGroup_SabaVRSoccer		SMALLINT = 145,
			@SportGroup_SabaVRBasketball	SMALLINT = 912,
			@SportGroup_NonSport			SMALLINT = 229;

    DECLARE @SabaLeagueGroupAll     VARCHAR(500)
    DECLARE @SabaLeagueGroupNormal  VARCHAR(500)
    DECLARE @SabaLeagueGroupPinGoal VARCHAR(500)
    SELECT  @SabaLeagueGroupAll     = VValue FROM bodb_Account.dbo.SystemSettings (NOLOCK) WHERE VID = 5
    SELECT  @SabaLeagueGroupNormal  = VValue FROM bodb_Account.dbo.SystemSettings (NOLOCK) WHERE VID = 11
    SELECT  @SabaLeagueGroupPinGoal = REPLACE(@SabaLeagueGroupAll, @SabaLeagueGroupNormal + ',', '')

    CREATE TABLE #tmpSABALeague (
        LeagueGroupType INT,
        LeagueGroupID   INT,
        LeagueID        INT,
        Sporttype       INT,
        isIncludeData   BIT
    )

    ;WITH
    CTE_All AS (
        SELECT value LeagueGroupID
        FROM STRING_SPLIT(@SabaLeagueGroupAll, ',')
    ),
    CTE_PinGoal AS (
        SELECT value LeagueGroupID
        FROM STRING_SPLIT(@SabaLeagueGroupPinGoal, ',')
    ),
    CTE_Final AS (
        SELECT a.LeagueGroupID,
               CASE WHEN p.LeagueGroupID IS NOT NULL THEN 1 ELSE 0 END isPinGoal
        FROM CTE_All a
             LEFT JOIN CTE_PinGoal p ON a.LeagueGroupID = p.LeagueGroupID
    )
    INSERT INTO #tmpSABALeague (LeagueGroupType, LeagueGroupID, LeagueID, Sporttype, isIncludeData)
    SELECT CASE WHEN f.isPinGoal = 1 THEN 2 ELSE 1 END LeagueGroupType,
           l.LeagueGroupID,
           l.leagueid LeagueID,
           l.sporttype Sporttype,
           CASE WHEN l.LeagueGroupID IN (42, 74) AND l.sporttype IN (1, 2) THEN 1 ELSE 0 END isIncludeData
    FROM bodb02.dbo.League l (NOLOCK)
         LEFT JOIN CTE_Final f ON l.LeagueGroupID = f.LeagueGroupID
    WHERE f.LeagueGroupID IS NOT NULL

    CREATE UNIQUE CLUSTERED INDEX CIX_tmpSABALeague ON #tmpSABALeague (LeagueID)

    -- #tmpSpecialEventLeague
    CREATE TABLE #tmpSpecialEventLeague (LeagueID INT NOT NULL)

    INSERT INTO #tmpSpecialEventLeague (LeagueID)
    SELECT leagueid LeagueID
    FROM bodb02.dbo.League WITH (NOLOCK)
    WHERE (DisplayMode = 2 AND ProgramID = '2022') OR
          (DisplayMode = 3 AND ProgramID = '2024')

    CREATE UNIQUE CLUSTERED INDEX CIX_tmpWorldCup2022League ON #tmpSpecialEventLeague(LeagueID)

    -- #tmpSpecialBettype
    CREATE TABLE #tmpSpecialBettype (
        BettypeGroupID INT NOT NULL,
        Bettype        INT NOT NULL
    )

    INSERT INTO #tmpSpecialBettype (BettypeGroupID, Bettype)
    SELECT BettypeGroupID, Bettype
    FROM bodb_account.dbo.BettypeGroup WITH (NOLOCK)
    WHERE BettypeGroupID IN (6, 10)

    CREATE UNIQUE CLUSTERED INDEX CIX_tmpSpecialBettype ON #tmpSpecialBettype(Bettype)

    ---------------------------
    -- Loop process temp tables

    -- #tmpCustFull
    CREATE TABLE #tmpCustFull (CustID INT NOT NULL, IsCheck BIT DEFAULT 0)
    INSERT INTO  #tmpCustFull (CustID) SELECT DISTINCT CAST(value AS INT) CustID FROM STRING_SPLIT(@listCustID, ',')
    CREATE UNIQUE CLUSTERED INDEX CIX_tmpCustFull ON #tmpCustFull(CustID)

    -- #tmpCustBatch
    CREATE TABLE #tmpCustBatch (CustID INT NOT NULL, ResetDate DATE, IsCheck BIT DEFAULT(0))
    CREATE UNIQUE CLUSTERED INDEX CIX_tmpCustBatch ON #tmpCustBatch(CustID, IsCheck)

    -- #tmpFinalData
    CREATE TABLE #tmpFinalData (
        CustID  INT NOT NULL
    )
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpFinalData ON #tmpFinalData(CustID)

    ------------------
    -- Process data --

    WHILE (1=1)
    BEGIN
        -- Check to break the loop
        SELECT @count = COUNT(1) FROM #tmpCustFull WHERE IsCheck = 0
        IF (@count = 0) BREAK
        
        -- Get list of customer to run
        -- + Reset data
        TRUNCATE TABLE #tmpCustBatch
        -- + Gen data
        INSERT INTO #tmpCustBatch (CustID)
        SELECT TOP (@batch) CustID
        FROM #tmpCustFull
        WHERE IsCheck = 0
        ORDER BY CustID ASC
        -- + Update data
        UPDATE tmp
        SET tmp.ResetDate = rs.ResetDate
        FROM #tmpCustBatch tmp
             LEFT JOIN bodb_VR2Model.dbo.CustomerClassification_ResetBalance rs WITH (NOLOCK) ON tmp.CustID = rs.CustID

        -- Get yesterday and today data
        ;WITH
        CTE_BaseData_Lvl0 AS (
            SELECT t.CustID,
                   CASE WHEN saba.isIncludeData = 1 AND saba.Sporttype = 1 THEN 145
                        WHEN saba.isIncludeData = 1 AND saba.Sporttype = 2 THEN 912
                        WHEN t.BetType IN (9, 29, 38)                      THEN 107
                        WHEN t.ProductID IN (1, 25, -1, -2, -3) THEN CASE WHEN t.Sporttype = 1  THEN 1
                                                                          WHEN t.Sporttype = 2  THEN 2
                                                                          WHEN t.Sporttype = 43 THEN 43
                                                                          ELSE 99 END
                        ELSE 229 END SportGroup,
                   CAST(t.winlostdate AS DATE) RptDate,
                   CASE WHEN t.status           IN ('Void','Reject','Refund') THEN 0
                        WHEN t.bettype          IN (9, 29, 999, 38)           THEN 0
                        WHEN saba.isIncludeData IN (0)                        THEN 0
                        WHEN se.LeagueID        IS NOT NULL                   THEN 0
                        WHEN t.ProductID        IN (37, 74)                   THEN 0
                        WHEN sb.Bettype         IS NOT NULL                   THEN 0
                        WHEN t.Sporttype        IN (150, 173)                 THEN 0
                        ELSE 1 END isNormalBet,
                   CASE WHEN @isResetBalance = 1 AND b.ResetDate IS NOT NULL AND CAST(t.winlostdate AS DATE) < b.ResetDate THEN 0 ELSE (t.BetCount)                                                                    END BetCount
            FROM bodb_ODS.dbo.ODS_bettrans t WITH (NOLOCK)
                 INNER JOIN #tmpCustBatch b ON t.custid = b.CustID AND b.IsCheck = 0
                 LEFT JOIN #tmpSABALeague saba ON t.LeagueID = saba.LeagueID
                 LEFT JOIN #tmpSpecialEventLeague se ON t.LeagueID = se.LeagueID
                 LEFT JOIN #tmpSpecialBettype sb ON t.bettype = sb.Bettype
            WHERE t.winlostdate >= DATEADD(DD, -1, CAST(GETDATE() AS DATE))
                  AND t.bettype NOT IN (31, 32, 33, 903, 904)
                  AND t.currency NOT IN (20, 27, 28)
                  AND t.status NOT IN ('running')
        )
        INSERT INTO #tmpFinalData (CustID)
		SELECT DISTINCT CustID
		FROM CTE_BaseData_Lvl0
		WHERE isNormalBet = 1
			AND BetCount > 0
			AND SportGroup NOT IN (@SportGroup_SabaVRSoccer, @SportGroup_SabaVRBasketball, @SportGroup_NonSport)
        OPTION (RECOMPILE, MAXDOP 4, USE HINT('ALLOW_BATCH_MODE'), MAX_GRANT_PERCENT = 5)

		-- Update checked customer BC
		UPDATE b WITH(ROWLOCK, UPDLOCK)
		SET	b.IsCheck = 1
		FROM #tmpCustBatch AS b
			INNER JOIN #tmpFinalData AS f ON f.CustID = b.CustID;
		
		-- Get before yesterday data
        ;WITH
        CTE_BaseData_Lvl0 AS (
           SELECT t.CustID,
                   CASE WHEN saba.isIncludeData = 1 AND saba.Sporttype = 1 THEN 145
                        WHEN saba.isIncludeData = 1 AND saba.Sporttype = 2 THEN 912
                        WHEN t.BetType IN (9, 29, 38)                      THEN 107
                        WHEN pb.ProductID IN (1, 25, -1, -2, -3) THEN CASE WHEN t.SportType = 1  THEN 1
                                                                           WHEN t.SportType = 2  THEN 2
                                                                           WHEN t.SportType = 43 THEN 43
                                                                           ELSE 99 END
                        ELSE 229 END SportGroup,
                   t.RptDate,
                   CASE WHEN t.TicketStatus     IN (10, 9, 14)      THEN 0
                        WHEN t.BetType          IN (9, 29, 999, 38) THEN 0
                        WHEN saba.isIncludeData IN (0)              THEN 0
                        WHEN se.LeagueID        IS NOT NULL         THEN 0
                        WHEN pb.ProductID       IN (37, 74)         THEN 0
                        WHEN sb.Bettype         IS NOT NULL         THEN 0
                        WHEN t.Sporttype        IN (150, 173)       THEN 0
                        ELSE 1 END isNormalBet,
                   CASE WHEN @isResetBalance = 1 AND b.ResetDate IS NOT NULL AND t.RptDate < b.ResetDate THEN 0 ELSE (t.BetCount) END BetCount
            FROM bodb_account.dbo.FactCustStatsInfo t WITH (NOLOCK, FORCESEEK)
                 INNER JOIN #tmpCustBatch b ON t.CustID = b.CustID AND b.IsCheck = 0
                 LEFT JOIN bodb_account.dbo.tbl_Currency_Daily ex WITH (NOLOCK) ON t.RptDate = ex.ExchangeDate AND t.CurrencyID = ex.Currency
                 LEFT JOIN bodb_account.dbo.Product_Bettype pb WITH (NOLOCK) ON t.BetType = pb.bettype
                 LEFT JOIN #tmpSABALeague saba ON t.LeagueID = saba.LeagueID
                 LEFT JOIN #tmpSpecialEventLeague se ON t.LeagueID = se.LeagueID
                 LEFT JOIN #tmpSpecialBettype sb ON t.BetType = sb.Bettype
            WHERE t.RptDate < DATEADD(DD, -1, CAST(GETDATE() AS DATE))
                  AND t.bettype NOT IN (31, 32, 33, 903, 904)
                  AND t.CurrencyID NOT IN (20, 27, 28)
                  AND t.SportType NOT IN (-1)
		)
        INSERT INTO #tmpFinalData (CustID)
        SELECT DISTINCT CustID
		FROM CTE_BaseData_Lvl0
		WHERE isNormalBet = 1
			AND BetCount > 0
			AND SportGroup NOT IN (@SportGroup_SabaVRSoccer, @SportGroup_SabaVRBasketball, @SportGroup_NonSport)
        OPTION (RECOMPILE, MAXDOP 4, USE HINT('ALLOW_BATCH_MODE'), MAX_GRANT_PERCENT = 5)

        -- Reset the loop
        UPDATE t
        SET t.IsCheck = 1
        FROM #tmpCustFull t
        WHERE EXISTS (SELECT TOP 1 1
                      FROM #tmpCustBatch b
                      WHERE t.CustID = b.CustID)
    END


    -----------------
    -- Return data --

    SELECT DISTINCT CustID
    FROM #tmpFinalData

    ----------------------
    -- Drop temp tables --

    DROP TABLE #tmpSABALeague
    DROP TABLE #tmpSpecialEventLeague
    DROP TABLE #tmpSpecialBettype

    DROP TABLE #tmpCustFull
    DROP TABLE #tmpCustBatch
    DROP TABLE #tmpFinalData

END;
GO