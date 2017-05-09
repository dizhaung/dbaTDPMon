USE [dbaTDPMon]
GO

RAISERROR('*-----------------------------------------------------------------------------*', 10, 1) WITH NOWAIT
RAISERROR('* dbaTDPMon (Troubleshoot Database Performance / Monitoring)                  *', 10, 1) WITH NOWAIT
RAISERROR('* http://dbatdpmon.codeplex.com, under GNU (GPLv3) licence model              *', 10, 1) WITH NOWAIT
RAISERROR('*-----------------------------------------------------------------------------*', 10, 1) WITH NOWAIT
RAISERROR('* Patch script: from version 2017.4 to 2017.5 (2017.05.08)				  *', 10, 1) WITH NOWAIT
RAISERROR('*-----------------------------------------------------------------------------*', 10, 1) WITH NOWAIT

SELECT * FROM [dbo].[appConfigurations] WHERE [module] = 'common' AND [name] = 'Application Version'
GO
UPDATE [dbo].[appConfigurations] SET [value] = N'2017.05.08' WHERE [module] = 'common' AND [name] = 'Application Version'
GO

/*---------------------------------------------------------------------------------------------------------------------*/
/* patch module: commons																							   */
/*---------------------------------------------------------------------------------------------------------------------*/
RAISERROR('Patching module: COMMONS', 10, 1) WITH NOWAIT



/*---------------------------------------------------------------------------------------------------------------------*/
/* patch module: maintenance-plan																					   */
/*---------------------------------------------------------------------------------------------------------------------*/
RAISERROR('Patching module: MAINTENANCE-PLAN', 10, 1) WITH NOWAIT

RAISERROR('Create function: [dbo].[ufn_mpObjectQuoteName]', 10, 1) WITH NOWAIT
GO
IF  EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID(N'[dbo].[ufn_mpObjectQuoteName]') AND xtype in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[ufn_mpObjectQuoteName]
GO

CREATE FUNCTION [dbo].[ufn_mpObjectQuoteName]
(		
	@objectName	[sysname]
)
RETURNS [sysname]
/* WITH ENCRYPTION */
AS

-- ============================================================================
-- Copyright (c) 2004-2017 Dan Andrei STEFAN (danandrei.stefan@gmail.com)
-- ============================================================================
-- Author			 : Dan Andrei STEFAN
-- Create date		 : 2004-2017
-- Module			 : Database Analysis & Performance Monitoring
-- ============================================================================

begin
	DECLARE   @quoteCharStart	[varchar](1)
			, @quoteCharEnd		[varchar](1)

	SET @quoteCharStart	= '['
	SET @quoteCharEnd	= ']'

	IF CHARINDEX(']', @objectName)<>0 OR CHARINDEX(']', @objectName)<>0
		begin
			SET @quoteCharStart	= '"'
			SET @quoteCharEnd	= '"'								
		end

	RETURN (@quoteCharStart + @objectName + @quoteCharEnd)
end
GO


RAISERROR('Create procedure: [dbo].[usp_mpCheckAvailabilityGroupLimitations]', 10, 1) WITH NOWAIT
GO
IF  EXISTS (
	    SELECT * 
	      FROM sysobjects 
	     WHERE [id] = OBJECT_ID(N'[dbo].[usp_mpCheckAvailabilityGroupLimitations]') 
	       AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_mpCheckAvailabilityGroupLimitations]
GO

-----------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_mpCheckAvailabilityGroupLimitations]
		@sqlServerName		[sysname] = @@SERVERNAME,
		@dbName				[sysname],
		@actionName			[sysname],
		@actionType			[sysname],
		@flgActions			[smallint]	= 0,
		@flgOptions			[int]	  OUTPUT,
		@agName				[sysname] OUTPUT,
		@agInstanceRoleDesc	[sysname] OUTPUT,
		@executionLevel		[tinyint]	= 0,
		@debugMode			[bit]		= 0
/* WITH ENCRYPTION */
AS

-----------------------------------------------------------------------------------------
SET NOCOUNT ON

DECLARE		@queryToRun  					[nvarchar](2048),
			@queryParameters				[nvarchar](512),
			@nestedExecutionLevel			[tinyint],
			@eventData						[varchar](8000)

-----------------------------------------------------------------------------------------
SET @nestedExecutionLevel = @executionLevel + 1

--------------------------------------------------------------------------------------------------
DECLARE @clusterName				 [sysname],		
		@agSynchronizationState		 [sysname],
		@agPreferredBackupReplica	 [bit],
		@agAutomatedBackupPreference [tinyint]

SET @agName = NULL

/* get cluster name */
SET @queryToRun = N'SELECT [cluster_name] FROM sys.dm_hadr_cluster'
SET @queryToRun = [dbo].[ufn_formatSQLQueryForLinkedServer](@sqlServerName, @queryToRun)

SET @queryToRun = N'SELECT @clusterName = [cluster_name]
					FROM (' + @queryToRun + N')inq'

SET @queryParameters = N'@clusterName [sysname] OUTPUT'
IF @debugMode=1	EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

EXEC sp_executesql @queryToRun, @queryParameters, @clusterName = @clusterName OUTPUT


/* availability group configuration */
SET @queryToRun = N'
			SELECT    ag.[name]
					, ars.[role_desc]
					, ag.[automated_backup_preference]
			FROM sys.availability_replicas ar
			INNER JOIN sys.dm_hadr_availability_replica_states ars ON ars.[replica_id]=ar.[replica_id] AND ars.[group_id]=ar.[group_id]
			INNER JOIN sys.availability_groups ag ON ag.[group_id]=ar.[group_id]
			INNER JOIN sys.dm_hadr_availability_replica_cluster_nodes arcn ON arcn.[group_name]=ag.[name] AND arcn.[replica_server_name]=ar.[replica_server_name]
			INNER JOIN sys.dm_hadr_database_replica_states hdrs ON ar.[replica_id]=hdrs.[replica_id]
			INNER JOIN sys.availability_databases_cluster adc ON adc.[group_id]=hdrs.[group_id] AND adc.[group_database_id]=hdrs.[group_database_id]
			WHERE arcn.[replica_server_name] = ''' + @sqlServerName + N'''
				  AND adc.[database_name] = ''' + @dbName + N''''
SET @queryToRun = [dbo].[ufn_formatSQLQueryForLinkedServer](@sqlServerName, @queryToRun)

SET @queryToRun = N'SELECT    @agName = [name]
							, @agInstanceRoleDesc = [role_desc]
							, @agAutomatedBackupPreference = [automated_backup_preference]
					FROM (' + @queryToRun + N')inq'
SET @queryParameters = N'@agName [sysname] OUTPUT, @agInstanceRoleDesc [sysname] OUTPUT, @agAutomatedBackupPreference [tinyint] OUTPUT'
IF @debugMode=1	EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

EXEC sp_executesql @queryToRun, @queryParameters, @agName = @agName OUTPUT
												, @agInstanceRoleDesc = @agInstanceRoleDesc OUTPUT
												, @agAutomatedBackupPreference = @agAutomatedBackupPreference OUTPUT
	

IF @agName IS NOT NULL AND @clusterName IS NOT NULL
	begin
		/* availability group synchronization status */
		SET @queryToRun = N'
				SELECT    hdrs.[synchronization_state_desc]
						, sys.fn_hadr_backup_is_preferred_replica(''' + @dbName + N''') AS [backup_is_preferred_replica]
				FROM sys.dm_hadr_database_replica_states hdrs
				INNER JOIN sys.availability_replicas ar ON ar.[replica_id]=hdrs.[replica_id]
				INNER JOIN sys.availability_databases_cluster adc ON adc.[group_id]=hdrs.[group_id] AND adc.[group_database_id]=hdrs.[group_database_id]
				INNER JOIN sys.dm_hadr_availability_replica_cluster_states rcs ON rcs.[replica_id]=ar.[replica_id] AND rcs.[group_id]=hdrs.[group_id]
				INNER JOIN sys.databases sd ON sd.name = adc.database_name
				WHERE	ar.[replica_server_name] = ''' + @sqlServerName + N'''
						AND adc.[database_name] = ''' + @dbName + N''''
		SET @queryToRun = [dbo].[ufn_formatSQLQueryForLinkedServer](@sqlServerName, @queryToRun)

		SET @queryToRun = N'SELECT    @agSynchronizationState = [synchronization_state_desc]
									, @agPreferredBackupReplica = [backup_is_preferred_replica]
							FROM (' + @queryToRun + N')inq'

		SET @queryParameters = N'@agSynchronizationState [sysname] OUTPUT, @agPreferredBackupReplica [bit] OUTPUT'
		IF @debugMode=1	EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

		EXEC sp_executesql @queryToRun, @queryParameters, @agSynchronizationState = @agSynchronizationState OUTPUT
														, @agPreferredBackupReplica = @agPreferredBackupReplica OUTPUT

		SET @agSynchronizationState = ISNULL(@agSynchronizationState, '')
		SET @agInstanceRoleDesc = ISNULL(@agInstanceRoleDesc, '')
	
		IF ISNULL(@agSynchronizationState, '')<>''
			begin
				IF UPPER(@agInstanceRoleDesc) NOT IN ('PRIMARY', 'SECONDARY')
					begin
						SET @queryToRun=N'Availability Group: Current role state [ ' + @agInstanceRoleDesc + N'] does not permit the "' + @actionName + '" operation.'
						EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

						SET @eventData='<skipaction><detail>' + 
											'<name>' + @actionName + '</name>' + 
											'<type>' + @actionType + '</type>' + 
											'<affected_object>' + @dbName + '</affected_object>' + 
											'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
											'<reason>' + @queryToRun + '</reason>' + 
										'</detail></skipaction>'

						EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
															@dbName			= @dbName,
															@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
															@eventName		= @actionName,
															@eventMessage	= @eventData,
															@eventType		= 0 /* info */

						SET @eventData='<alert><detail>' + 
										'<severity>critical</severity>' + 
										'<instance_name>' + @sqlServerName + '</instance_name>' + 
										'<cluster_name>' + @clusterName + '</instance_name>' + 
										'<availability_group_name>' + @agName + '</instance_name>' + 
										'<action_name>' + @actionName + '</action_name>' + 
										'<action_type>' + @actionType + '</action_type>' + 
										'<message>' + @queryToRun + '</message' + 
										'<event_date_utc>' + CONVERT([varchar](24), GETUTCDATE(), 121) + '</event_date_utc>' + 
										'</detail></alert>'

						EXEC [dbo].[usp_logEventMessageAndSendEmail]	@projectCode			= DEFAULT,
																		@sqlServerName			= @sqlServerName,
																		@dbName					= @dbName,
																		@objectName				= NULL,
																		@childObjectName		= NULL,
																		@module					= 'dbo.usp_mpDatabaseBackup',
																		@eventName				= 'database backup',
																		@parameters				= NULL,	
																		@eventMessage			= @eventData,
																		@dbMailProfileName		= NULL,
																		@recipientsList			= NULL,
																		@eventType				= 6,	/* 6 - alert-custom */
																		@additionalOption		= 0

						RETURN 1
					end

				/*-------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
				/* database backup - allowed actions on a secondary replica */
				IF @actionName = 'database backup' AND UPPER(@agInstanceRoleDesc) = 'SECONDARY'
					begin	
						/* if automated_backup_preference is 0 (primary), Backups should always occur on the primary replica */
						IF @agAutomatedBackupPreference = 0
							begin
								SET @queryToRun=N'Availability Group: Current setting for Backup Preferences do not permit backups on a seconday replica (0: Primary).'
								EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

								SET @eventData='<skipaction><detail>' + 
													'<name>' + @actionName + '</name>' + 
													'<type>' + @actionType + '</type>' + 
													'<affected_object>' + @dbName + '</affected_object>' + 
													'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
													'<reason>' + @queryToRun + '</reason>' + 
												'</detail></skipaction>'

								EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
																	@dbName			= @dbName,
																	@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
																	@eventName		= @actionName,
																	@eventMessage	= @eventData,
																	@eventType		= 0 /* info */

								RETURN 1
							end

						/* if instance is preferred replica */
						IF @agPreferredBackupReplica = 0
							begin
								SET @queryToRun=N'Availability Group: Current instance [ ' + @sqlServerName + N'] is not a backup preferred replica for the database [' + @dbName + N'].'
								EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

								SET @eventData='<skipaction><detail>' + 
													'<name>' + @actionName + '</name>' + 
													'<type>' + @actionType + '</type>' + 
													'<affected_object>' + @dbName + '</affected_object>' + 
													'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
													'<reason>' + @queryToRun + '</reason>' + 
												'</detail></skipaction>'

								EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
																	@dbName			= @dbName,
																	@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
																	@eventName		= @actionName,
																	@eventMessage	= @eventData,
																	@eventType		= 0 /* info */

								RETURN 1
							end

						/* copy-only full backups are allowed */
						IF @flgActions & 1 = 1 AND @flgOptions & 4 = 0
							begin
								/* on alwayson availability groups, for secondary replicas, force copy-only backups */
								IF @flgOptions & 1024 = 1024
									begin
										SET @queryToRun='Server is part of an Availability Group as a secondary replica. Forcing copy-only full backups.'
										EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0
				
										SET @flgOptions = @flgOptions + 4
									end
								ELSE
									begin
										SET @queryToRun=N'Availability Group: Only copy-only full backups are allowed on a secondary replica.'
										EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

										SET @eventData='<skipaction><detail>' + 
															'<name>' + @actionName + '</name>' + 
															'<type>' + @actionType + '</type>' + 
															'<affected_object>' + @dbName + '</affected_object>' + 
															'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
															'<reason>' + @queryToRun + '</reason>' + 
														'</detail></skipaction>'

										EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
																			@dbName			= @dbName,
																			@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
																			@eventName		= @actionName,
																			@eventMessage	= @eventData,
																			@eventType		= 0 /* info */

										RETURN 1
									end
							end

						/* Differential backups are not supported on secondary replicas. */
						IF @flgActions & 2 = 2
							begin
								SET @queryToRun=N'Availability Group: Differential backups are not supported on secondary replicas.'
								EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

								SET @eventData='<skipaction><detail>' + 
													'<name>' + @actionName + '</name>' + 
													'<type>' + @actionType + '</type>' + 
													'<affected_object>' + @dbName + '</affected_object>' + 
													'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
													'<reason>' + @queryToRun + '</reason>' + 
												'</detail></skipaction>'

								EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
																	@dbName			= @dbName,
																	@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
																	@eventName		= @actionName,
																	@eventMessage	= @eventData,
																	@eventType		= 0 /* info */

								RETURN 1
							end
				
						/* BACKUP LOG supports only regular log backups (the COPY_ONLY option is not supported for log backups on secondary replicas).*/
						IF @flgActions & 4 = 4 AND @flgOptions & 4 = 4
							begin
								SET @queryToRun=N'Availability Group: BACKUP LOG supports only regular log backups (the COPY_ONLY option is not supported for log backups on secondary replicas).'
								EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

								SET @eventData='<skipaction><detail>' + 
													'<name>' + @actionName + '</name>' + 
													'<type>' + @actionType + '</type>' + 
													'<affected_object>' + @dbName + '</affected_object>' + 
													'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
													'<reason>' + @queryToRun + '</reason>' + 
												'</detail></skipaction>'

								EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
																	@dbName			= @dbName,
																	@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
																	@eventName		= @actionName,
																	@eventMessage	= @eventData,
																	@eventType		= 0 /* info */

								RETURN 1
							end

						/* To back up a secondary database, a secondary replica must be able to communicate with the primary replica and must be SYNCHRONIZED or SYNCHRONIZING. */
						IF UPPER(@agSynchronizationState) NOT IN ('SYNCHRONIZED', 'SYNCHRONIZING')
							begin
								SET @queryToRun=N'Availability Group: Current secondary replica state [ ' + @agSynchronizationState + N'] does not permit the backup operation.'
								EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

								SET @eventData='<skipaction><detail>' + 
													'<name>' + @actionName + '</name>' + 
													'<type>' + @actionType + '</type>' + 
													'<affected_object>' + @dbName + '</affected_object>' + 
													'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
													'<reason>' + @queryToRun + '</reason>' + 
												'</detail></skipaction>'

								EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
																	@dbName			= @dbName,
																	@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
																	@eventName		= @actionName,
																	@eventMessage	= @eventData,
																	@eventType		= 0 /* info */

								RETURN 1
							end
					end

				/*-------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
				/* database backup - allowed actions on a primary replica */
				IF @actionName = 'database backup' AND UPPER(@agInstanceRoleDesc) = 'PRIMARY'
					begin	
						/* if automated_backup_preference is 1 (secondary only), backups logs must be performed on secondary */
						IF @agAutomatedBackupPreference = 1 AND @flgActions & 4 = 4 /* log */
							begin
								SET @queryToRun=N'Availability Group: Current setting for Backup Preferences do not permit LOG backups on a primary replica (1: Secondary only).'
								EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

								SET @eventData='<skipaction><detail>' + 
													'<name>' + @actionName + '</name>' + 
													'<type>' + @actionType + '</type>' + 
													'<affected_object>' + @dbName + '</affected_object>' + 
													'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
													'<reason>' + @queryToRun + '</reason>' + 
												'</detail></skipaction>'

								EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
																	@dbName			= @dbName,
																	@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
																	@eventName		= @actionName,
																	@eventMessage	= @eventData,
																	@eventType		= 0 /* info */

								RETURN 1
							end

						/* if automated_backup_preference is 2 (prefered secondary): performing backups on the primary replica is acceptable if no secondary replica is available for backup operations */
						/* full and differential backups are allowed only on primary / restrictions apply for a secondary replica */
						IF @agAutomatedBackupPreference = 2 AND @flgActions & 4 = 4 /* log */
							begin
								/* check if there are secondary replicas available to perform the log backup */
								DECLARE @agAvailableSecondaryReplicas [smallint]

								SET @queryToRun = N'SELECT @agAvailableSecondaryReplicas = COUNT(*)
													FROM sys.dm_hadr_database_replica_states hdrs
													INNER JOIN sys.availability_replicas ar ON ar.[replica_id]=hdrs.[replica_id]
													INNER JOIN sys.availability_databases_cluster adc ON adc.[group_id]=hdrs.[group_id] AND adc.[group_database_id]=hdrs.[group_database_id]
													INNER JOIN sys.dm_hadr_availability_replica_cluster_states rcs ON rcs.[replica_id]=ar.[replica_id] AND rcs.[group_id]=hdrs.[group_id]
													INNER JOIN sys.dm_hadr_availability_replica_states ars ON ars.[replica_id]=ar.[replica_id] AND ars.[group_id]=ar.[group_id]
													INNER JOIN sys.databases sd ON sd.name = adc.database_name
													WHERE	adc.[database_name] = ''' + @dbName + N'''
															AND hdrs.[synchronization_state_desc] IN (''SYNCHRONIZED'', ''SYNCHRONIZING'')
															AND ars.[role_desc] = ''SECONDARY'''

								SET @queryToRun = [dbo].[ufn_formatSQLQueryForLinkedServer](@sqlServerName, @queryToRun)

								SET @queryParameters = N'@agAvailableSecondaryReplicas [smallint] OUTPUT'
								IF @debugMode=1	EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

								EXEC sp_executesql @queryToRun, @queryParameters, @agAvailableSecondaryReplicas = @agAvailableSecondaryReplicas OUTPUT

								IF @agAvailableSecondaryReplicas > 0
									begin
										SET @queryToRun=N'Availability Group: Current setting for Backup Preferences indicate that LOG backups should be perform on a secondary (current available) replica.'
										EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

										SET @eventData='<skipaction><detail>' + 
															'<name>' + @actionName + '</name>' + 
															'<type>' + @actionType + '</type>' + 
															'<affected_object>' + @dbName + '</affected_object>' + 
															'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
															'<reason>' + @queryToRun + '</reason>' + 
														'</detail></skipaction>'

										EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
																			@dbName			= @dbName,
																			@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
																			@eventName		= @actionName,
																			@eventMessage	= @eventData,
																			@eventType		= 0 /* info */

										RETURN 1
									end
							end
					end

				/*-------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
				/* database maintenance - allowed actions on a secondary replica */
				IF @actionName = 'database maintenance' AND UPPER(@agInstanceRoleDesc) = 'SECONDARY'
					begin								
						SET @queryToRun=N'Availability Group: Operation is not supported on a secondary replica.'
						EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

						SET @eventData='<skipaction><detail>' + 
											'<name>' + @actionName + '</name>' + 
											'<type>' + @actionType + '</type>' + 
											'<affected_object>' + @dbName + '</affected_object>' + 
											'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
											'<reason>' + @queryToRun + '</reason>' + 
										'</detail></skipaction>'

						EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
															@dbName			= @dbName,
															@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
															@eventName		= @actionName,
															@eventMessage	= @eventData,
															@eventType		= 0 /* info */

						RETURN 1
					end

				/*-------------------------------------------------------------------------------------------------------------------------------------------------------------------*/
				/* database skrink - allowed actions on a secondary replica */
				IF @actionName = 'database shrink' AND UPPER(@agInstanceRoleDesc) = 'SECONDARY'
					begin								
						SET @queryToRun=N'Availability Group: Operation is not supported on a secondary replica.'
						EXEC [dbo].[usp_logPrintMessage] @customMessage = @queryToRun, @raiseErrorAsPrint = 0, @messagRootLevel = @executionLevel, @messageTreelevel = 1, @stopExecution=0

						SET @eventData='<skipaction><detail>' + 
											'<name>' + @actionName + '</name>' + 
											'<type>' + @actionType + '</type>' + 
											'<affected_object>' + @dbName + '</affected_object>' + 
											'<date>' + CONVERT([varchar](24), GETDATE(), 121) + '</date>' + 
											'<reason>' + @queryToRun + '</reason>' + 
										'</detail></skipaction>'

						EXEC [dbo].[usp_logEventMessage]	@sqlServerName	= @sqlServerName,
															@dbName			= @dbName,
															@module			= 'dbo.usp_mpCheckAvailabilityGroupLimitations',
															@eventName		= @actionName,
															@eventMessage	= @eventData,
															@eventType		= 0 /* info */

						RETURN 1

					end

				SET @agName = @clusterName + '$' + @agName
			end
		ELSE
			SET @agName=NULL
	end

RETURN 0
GO



/*---------------------------------------------------------------------------------------------------------------------*/
USE [dbaTDPMon]
GO
SELECT * FROM [dbo].[appConfigurations] WHERE [module] = 'common' AND [name] = 'Application Version'
GO

RAISERROR('* Done *', 10, 1) WITH NOWAIT
