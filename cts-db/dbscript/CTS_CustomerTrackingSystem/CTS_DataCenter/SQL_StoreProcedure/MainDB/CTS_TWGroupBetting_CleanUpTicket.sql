/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[CTS_TWGroupBetting_CleanUpTicket]
AS
/*
	Created: 20240405@Victoria.Le
	Task : Clean up fraud tickets by schedule
	DB	 : DBCTS.WASAVerse

	Revisions:
		- 20240405@Victoria.Le:	Initial Writing [Redmine ID: #200842]
		- 20240405@Victoria.Le:	Enhance SP to not update Flag if there is no data to delete [Redmine ID: #200842]
		
	Params Explaination:
		EXECUTE [dbo].[CTS_TWGroupBetting_CleanUpTicket] 
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @CleanTicketFlag_ParameterID			SMALLINT = 7
		,	@CleanTicketFlag_Value					SMALLINT
		,	@CleanTicketFlag_READY					SMALLINT = 0
		,	@CleanTicketFlag_WAITING				SMALLINT = -1
		,	@CleanTicketFlag_INPROGRESS				SMALLINT = 1
		,	@CleanTicketFlag_FINISH					SMALLINT = 2
		
		,	@RemainDays_TicketHistory_ParameterID	SMALLINT = 8
		,	@RemainDays_TicketHistory_Value			SMALLINT
		,	@RemainDays_Ticket_ParameterID			SMALLINT = 9
		,	@RemainDays_Ticket_Value				SMALLINT
		
		,	@ArchivedDate_TicketHistory				DATE
		,	@ArchivedDate_Ticket					DATE
		
		,	@BatchSize								INT = 5000
		,	@RC										INT = 0
		,	@DeletedCount							INT = 0
		,	@IsExists_TicketHistory					BIT = 0
		,	@IsExists_Ticket						BIT = 0
		;
		
	SELECT 	@CleanTicketFlag_Value = s.ParameterValue
    FROM 	dbo.SystemParameter AS s WITH (NOLOCK)
    WHERE 	s.ParameterID = @CleanTicketFlag_ParameterID;
	
	IF (@CleanTicketFlag_Value <> @CleanTicketFlag_FINISH 
			AND @CleanTicketFlag_Value <> @CleanTicketFlag_WAITING)
	BEGIN
		RETURN;
	END
	ELSE IF (@CleanTicketFlag_Value = @CleanTicketFlag_FINISH) 
			OR (@CleanTicketFlag_Value = @CleanTicketFlag_WAITING)
	BEGIN
	
		SELECT 	@RemainDays_TicketHistory_Value = s.ParameterValue
		FROM 	dbo.SystemParameter AS s WITH (NOLOCK)
		WHERE 	s.ParameterID = @RemainDays_TicketHistory_ParameterID;
		
		SELECT 	@RemainDays_Ticket_Value = s.ParameterValue
		FROM 	dbo.SystemParameter AS s WITH (NOLOCK)
		WHERE 	s.ParameterID = @RemainDays_Ticket_ParameterID;
		
		SET @ArchivedDate_TicketHistory = DATEADD(DAY, -@RemainDays_TicketHistory_Value, GETDATE());
		SET @ArchivedDate_Ticket 		= DATEADD(DAY, -@RemainDays_Ticket_Value, GETDATE());
	
		IF EXISTS (SELECT 1 FROM dbo.TWGroupBettingTicket_History AS gbh WITH (NOLOCK)
						WHERE gbh.TransDate <= @ArchivedDate_TicketHistory)
		BEGIN
			SET @IsExists_TicketHistory = 1;
		END;
		
		IF EXISTS (SELECT 1 FROM dbo.TWGroupBettingTicket AS gb WITH (NOLOCK)
						WHERE gb.TransDate <= @ArchivedDate_Ticket)	
		BEGIN
			SET @IsExists_Ticket = 1;
		END;
		
		-- ------------------------------------------------
		IF @CleanTicketFlag_Value = @CleanTicketFlag_WAITING
		BEGIN
			IF @IsExists_TicketHistory = 1 
			BEGIN
				UPDATE 	dbo.SystemParameter WITH(UPDLOCK, ROWLOCK)
				SET 	ParameterValue = @CleanTicketFlag_INPROGRESS
				WHERE 	ParameterID = @CleanTicketFlag_ParameterID
					AND ParameterValue = @CleanTicketFlag_WAITING;
			
				WHILE(1 = 1)
				BEGIN
					DELETE TOP(@BatchSize) gbh
					FROM dbo.TWGroupBettingTicket_History AS gbh WITH(ROWLOCK)
					WHERE gbh.TransDate <= @ArchivedDate_TicketHistory;
					
					SET @RC = @@ROWCOUNT;
					IF (@RC = 0)
					BEGIN
						BREAK;
					END
					ELSE
					BEGIN
						SET @DeletedCount = @DeletedCount + @RC;
					END;
					
					WAITFOR DELAY '00:00:0.100';
				END;
				
			END;
		
			IF @IsExists_Ticket = 1
			BEGIN
				UPDATE 	dbo.SystemParameter WITH(UPDLOCK, ROWLOCK)
				SET 	ParameterValue = @CleanTicketFlag_INPROGRESS
				WHERE 	ParameterID = @CleanTicketFlag_ParameterID
					AND ParameterValue = @CleanTicketFlag_WAITING;
			
				WHILE(1 = 1)
				BEGIN
					DELETE TOP(@BatchSize) gb
					FROM dbo.TWGroupBettingTicket AS gb WITH(ROWLOCK)
					WHERE gb.TransDate <= @ArchivedDate_Ticket;
					
					SET @RC = @@ROWCOUNT;
					IF (@RC = 0)
					BEGIN
						BREAK;
					END
					ELSE
					BEGIN
						SET @DeletedCount = @DeletedCount + @RC;
					END;
					
					WAITFOR DELAY '00:00:0.100';
				END;
				
			END;
			
			IF (@DeletedCount > 0)
			BEGIN
				UPDATE 	dbo.SystemParameter WITH(UPDLOCK, ROWLOCK)
				SET 	ParameterValue 	= @CleanTicketFlag_FINISH
				WHERE 	ParameterID 	= @CleanTicketFlag_ParameterID
					AND ParameterValue 	= @CleanTicketFlag_INPROGRESS;
			END;
			
		END
		ELSE IF @CleanTicketFlag_Value = @CleanTicketFlag_FINISH
		BEGIN
			IF @IsExists_TicketHistory = 0 AND @IsExists_Ticket = 0
			BEGIN
				RETURN;
			END
			ELSE
			BEGIN
				UPDATE 	dbo.SystemParameter WITH(UPDLOCK, ROWLOCK)
				SET 	ParameterValue = @CleanTicketFlag_READY
				WHERE 	ParameterID = @CleanTicketFlag_ParameterID
					AND ParameterValue = @CleanTicketFlag_FINISH;
			END;
		END;

	END;

END;