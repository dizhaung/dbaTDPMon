RAISERROR('Create procedure: [dbo].[usp_purgeHistoryData]', 10, 1) WITH NOWAIT
GO
IF  EXISTS (
	    SELECT * 
	      FROM sysobjects 
	     WHERE id = OBJECT_ID(N'[dbo].[usp_purgeHistoryData]') 
	       AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_purgeHistoryData]
GO

GO
CREATE PROCEDURE [dbo].[usp_purgeHistoryData]
/* WITH ENCRYPTION */
AS

-- ============================================================================
-- Copyright (c) 2004-2017 Dan Andrei STEFAN (danandrei.stefan@gmail.com)
-- ============================================================================
-- Author			 : Dan Andrei STEFAN
-- Create date		 : 22.03.2017
-- Module			 : Database Analysis & Performance Monitoring
-- ============================================================================

SET NOCOUNT ON

DECLARE @retentionDays	[int],
		@customMessage	[varchar](256),
		@queryToRun		[nvarchar](1024)

SET NOCOUNT ON

-----------------------------------------------------------------------------------------
--Log events retention (days)
-----------------------------------------------------------------------------------------
SELECT @retentionDays = [value]
FROM [dbo].[appConfigurations]
WHERE [name] = 'Log events retention (days)'
	AND [module] = 'common'

SET @customMessage = 'Cleaning event history - keeping last ' + CAST(@retentionDays AS [varchar](32)) + ' days.'
EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 0, @stopExecution=0

SET @retentionDays = ISNULL(@retentionDays, 0)
IF @retentionDays<>0
	begin
		SET ROWCOUNT 2048
		WHILE 1=1
			begin
				DELETE FROM [dbo].[logEventMessages]
				WHERE [event_date_utc] < DATEADD(dd, -@retentionDays, GETUTCDATE())

				IF @@ROWCOUNT=0
					BREAK
			end
		SET ROWCOUNT 0

	end
SET @customMessage = 'Done.'
EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 0, @stopExecution=0


-----------------------------------------------------------------------------------------
--Internal jobs log retention (days)
-----------------------------------------------------------------------------------------
IF  EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'[dbo].[jobExecutionHistory]') AND type in (N'U'))
	begin
		SELECT @retentionDays = [value]
		FROM [dbo].[appConfigurations]
		WHERE [name] = 'Internal jobs log retention (days)'
			AND [module] = 'common'

		SET @customMessage = 'Cleaning internal jobs logs - keeping last ' + CAST(@retentionDays AS [varchar](32)) + ' days.'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 0, @stopExecution=0

		SET @retentionDays = ISNULL(@retentionDays, 0)
		IF @retentionDays<>0
			begin
				SET @queryToRun = 'DELETE FROM [dbo].[jobExecutionHistory]
									WHERE [event_date_utc] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETUTCDATE())'
				SET ROWCOUNT 4096
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0

				SET @queryToRun = 'DELETE FROM [dbo].[jobExecutionStatisticsHistory]
									WHERE [start_date] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETDATE())'
				SET ROWCOUNT 4096
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0
			end
		SET @customMessage = 'Done.'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 0, @stopExecution=0
	end

-----------------------------------------------------------------------------------------
--History data retention (days)
-----------------------------------------------------------------------------------------
IF  EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'[health-check].[statsDatabaseUsageHistory]') AND type in (N'U'))
	begin
		SELECT @retentionDays = [value]
		FROM [dbo].[appConfigurations]
		WHERE [name] = 'History data retention (days)'
			AND [module] = 'health-check'

		SET @customMessage = 'Cleaning Health-Check history data - keeping last ' + CAST(@retentionDays AS [varchar](32)) + ' days.'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 0, @stopExecution=0

		SET @retentionDays = ISNULL(@retentionDays, 0)

		SET @customMessage = '[monitoring].[statsSQLAgentJobs]'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 1, @stopExecution=0	
		IF @retentionDays<>0
			begin
				SET @queryToRun = 'DELETE FROM [monitoring].[statsSQLAgentJobs]
									WHERE [event_date_utc] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETUTCDATE())'
				SET ROWCOUNT 2048
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0
			end

		SET @customMessage = '[health-check].[statsDatabaseUsageHistory]'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 1, @stopExecution=0	
		IF @retentionDays<>0
			begin
				SET @queryToRun = 'DELETE FROM [health-check].[statsDatabaseUsageHistory]
									WHERE [event_date_utc] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETUTCDATE())'
				SET ROWCOUNT 2048
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0
			end

		SET @customMessage = '[health-check].[statsDatabaseAlwaysOnDetails]'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 1, @stopExecution=0	
		IF @retentionDays<>0
			begin
				SET @queryToRun = 'DELETE FROM [health-check].[statsDatabaseAlwaysOnDetails]
									WHERE [event_date_utc] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETUTCDATE())'
				SET ROWCOUNT 2048
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0
			end

		SET @customMessage = '[health-check].[statsDatabaseDetails]'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 1, @stopExecution=0	
		IF @retentionDays<>0
			begin
				SET @queryToRun = 'DELETE FROM [health-check].[statsDatabaseDetails]
									WHERE [event_date_utc] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETUTCDATE())'
				SET ROWCOUNT 2048
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0
			end

		SET @customMessage = '[health-check].[statsSQLAgentJobsHistory]'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 1, @stopExecution=0	
		IF @retentionDays<>0
			begin
				SET @queryToRun = 'DELETE FROM [health-check].[statsSQLAgentJobsHistory]
									WHERE [event_date_utc] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETUTCDATE())'
				SET ROWCOUNT 2048
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0
			end

		SET @customMessage = '[health-check].[statsOSEventLogs]'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 1, @stopExecution=0	
		IF @retentionDays<>0
			begin
				SET @queryToRun = 'DELETE FROM [health-check].[statsOSEventLogs]
									WHERE [event_date_utc] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETUTCDATE())'
				SET ROWCOUNT 2048
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0
			end

		SET @customMessage = '[health-check].[statsErrorlogDetails]'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 1, @stopExecution=0	
		IF @retentionDays<>0
			begin
				SET @queryToRun = 'DELETE FROM [health-check].[statsErrorlogDetails]
									WHERE [event_date_utc] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETUTCDATE())'
				SET ROWCOUNT 2048
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0
			end

		SET @customMessage = '[health-check].[statsDiskSpaceInfo]'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 1, @messagRootLevel = 0, @messageTreelevel = 1, @stopExecution=0	
		IF @retentionDays<>0
			begin
				SET @queryToRun = 'DELETE FROM [health-check].[statsDiskSpaceInfo]
									WHERE [event_date_utc] < DATEADD(dd, -' + CAST(@retentionDays AS [varchar]) + ', GETUTCDATE())'
				SET ROWCOUNT 2048
				WHILE 1=1
					begin
						EXEC sp_executesql  @queryToRun
						
						IF @@ROWCOUNT=0
							BREAK
					end
				SET ROWCOUNT 0
			end

		SET @customMessage = 'Done.'
		EXEC [dbo].[usp_logPrintMessage] @customMessage = @customMessage, @raiseErrorAsPrint = 0, @messagRootLevel = 0, @messageTreelevel = 0, @stopExecution=0
	end
GO
