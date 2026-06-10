-- =============================================
-- Example Stored Procedures for Testing
-- =============================================

-- Procedure 1: Get Match Data
CREATE PROCEDURE dbo.SP_CTS_GetMatchData
    @MatchId INT,
    @UserId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Get match information
    SELECT 
        m.MatchId,
        m.MatchName,
        m.MatchDate,
        m.Status,
        l.LeagueName,
        ht.TeamName AS HomeTeam,
        at.TeamName AS AwayTeam
    FROM CTS_Match m
    INNER JOIN CTS_League l ON m.LeagueId = l.LeagueId
    INNER JOIN CTS_Team ht ON m.HomeTeamId = ht.TeamId
    INNER JOIN CTS_Team at ON m.AwayTeamId = at.TeamId
    WHERE m.MatchId = @MatchId
    
    -- Get betting odds
    SELECT * FROM CTS_Odds
    WHERE MatchId = @MatchId
    
    -- Log user activity if UserId provided
    IF @UserId IS NOT NULL
    BEGIN
        EXEC SP_LogUserActivity @UserId, 'VIEW_MATCH', @MatchId
    END
END
GO

-- Procedure 2: Process Bet
CREATE PROCEDURE dbo.SP_CTS_ProcessBet
    @BetId BIGINT,
    @UserId INT,
    @MatchId INT,
    @BetType VARCHAR(50),
    @Amount DECIMAL(18,2),
    @OddsValue DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Check user balance
        DECLARE @CurrentBalance DECIMAL(18,2)
        SELECT @CurrentBalance = Balance 
        FROM CTS_User 
        WHERE UserId = @UserId
        
        IF @CurrentBalance < @Amount
        BEGIN
            RAISERROR('Insufficient balance', 16, 1)
            RETURN
        END
        
        -- Insert bet record
        INSERT INTO CTS_Bet (
            BetId, UserId, MatchId, BetType, 
            Amount, OddsValue, Status, CreatedDate
        )
        VALUES (
            @BetId, @UserId, @MatchId, @BetType,
            @Amount, @OddsValue, 'PENDING', GETDATE()
        )
        
        -- Update user balance
        UPDATE CTS_User
        SET Balance = Balance - @Amount,
            LastBetDate = GETDATE()
        WHERE UserId = @UserId
        
        -- Log transaction
        EXEC SP_LogTransaction @UserId, @BetId, 'BET_PLACED', @Amount
        
        -- Update match statistics
        EXEC SP_UpdateMatchStats @MatchId
        
        COMMIT TRANSACTION;
        
        -- Return bet details
        SELECT * FROM CTS_Bet WHERE BetId = @BetId
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Procedure 3: Settle Bet
CREATE PROCEDURE dbo.SP_CTS_SettleBet
    @BetId BIGINT,
    @Result VARCHAR(20), -- 'WIN', 'LOSE', 'VOID'
    @SettledBy INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    
    BEGIN TRY
        DECLARE @UserId INT
        DECLARE @Amount DECIMAL(18,2)
        DECLARE @OddsValue DECIMAL(10,2)
        DECLARE @Payout DECIMAL(18,2)
        
        -- Get bet information
        SELECT 
            @UserId = UserId,
            @Amount = Amount,
            @OddsValue = OddsValue
        FROM CTS_Bet
        WHERE BetId = @BetId
        
        -- Calculate payout
        IF @Result = 'WIN'
            SET @Payout = @Amount * @OddsValue
        ELSE IF @Result = 'VOID'
            SET @Payout = @Amount
        ELSE
            SET @Payout = 0
        
        -- Update bet status
        UPDATE CTS_Bet
        SET Status = @Result,
            Payout = @Payout,
            SettledDate = GETDATE(),
            SettledBy = @SettledBy
        WHERE BetId = @BetId
        
        -- Update user balance if win or void
        IF @Payout > 0
        BEGIN
            UPDATE CTS_User
            SET Balance = Balance + @Payout
            WHERE UserId = @UserId
        END
        
        -- Log settlement
        EXEC SP_LogTransaction @UserId, @BetId, 'BET_SETTLED', @Payout
        
        -- Update user statistics
        EXEC SP_UpdateUserStats @UserId
        
        COMMIT TRANSACTION;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Procedure 4: Get User Bet History
CREATE PROCEDURE dbo.SP_CTS_GetUserBetHistory
    @UserId INT,
    @FromDate DATETIME = NULL,
    @ToDate DATETIME = NULL,
    @Status VARCHAR(20) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Set default dates if not provided
    IF @FromDate IS NULL
        SET @FromDate = DATEADD(MONTH, -1, GETDATE())
    
    IF @ToDate IS NULL
        SET @ToDate = GETDATE()
    
    -- Get bet history with pagination
    SELECT 
        b.BetId,
        b.MatchId,
        m.MatchName,
        m.MatchDate,
        b.BetType,
        b.Amount,
        b.OddsValue,
        b.Status,
        b.Payout,
        b.CreatedDate,
        b.SettledDate
    FROM CTS_Bet b
    INNER JOIN CTS_Match m ON b.MatchId = m.MatchId
    WHERE b.UserId = @UserId
        AND b.CreatedDate BETWEEN @FromDate AND @ToDate
        AND (@Status IS NULL OR b.Status = @Status)
    ORDER BY b.CreatedDate DESC
    OFFSET (@PageNumber - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY
    
    -- Get total count
    SELECT COUNT(*) AS TotalRecords
    FROM CTS_Bet
    WHERE UserId = @UserId
        AND CreatedDate BETWEEN @FromDate AND @ToDate
        AND (@Status IS NULL OR Status = @Status)
    
    -- Get summary statistics
    EXEC SP_GetUserBetSummary @UserId, @FromDate, @ToDate
END
GO
