USE [Meta]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




/*


Detect blocked processes


*/


CREATE PROCEDURE [dbo].[BlockedSpidLoad]
AS

SET NOCOUNT ON;
DECLARE @sprocName varchar(200) = DB_NAME() + '.' + SCHEMA_NAME() + '.' + OBJECT_NAME (@@PROCID);
BEGIN TRY

	IF OBJECT_ID ('tempdb..#sql') is not null drop table #sql;
	CREATE TABLE #sql (
		dbid smallint,
		objectid int,
		number smallint,
		encrypted bit,
		sqltext text
	)

	--SELECT * from BlockedSpid order by id_key desc
	IF OBJECT_ID ('tempdb..#blocks') is not null drop table #blocks;
	SELECT DISTINCT
		IDENTITY(INT) as id_key,
		DB_NAME (blocked.dbid) Db,
		blocked.waitTime,
		blocked.lastWaitType,
		blocking.blocked blockedSpid,
		rtrim (blocked.loginame) blockedLogin,
		rtrim (blocked.hostname) blockedHost,
		blocked.sql_handle blockedHandle,
		cast (null as varchar(max)) blockedSql,
		rtrim (blocked.cmd) blockedCmd,
		rtrim (blocked.program_name) blockedProgram,
		rtrim (blocked.status) blockedStatus,
		blocked.cpu blockedCpu,
		blocked.last_batch as blockedLastBatch,
		getdate() as currentDateTime,
		blocking.spid blockingSpid,
		rtrim (blocking.loginame) blockingLogin,
		rtrim (blocking.hostname) blockingHost,
		blocking.sql_handle blockingHandle,
		cast (NULL as varchar(max)) blockingSql,
		rtrim (blocking.cmd) blockingCmd,
		rtrim (blocking.program_name) blockingProgram,
		rtrim (blocking.status) blockingStatus,
		blocking.cpu blockingCpu,
		blocking.last_batch as blockingLastBatch
	into #blocks
	FROM master.sys.sysprocesses blocked
	JOIN master.sys.sysprocesses blocking ON blocking.blocked = blocked.spid
	WHERE blocking.blocked <> 0
	AND blocked.spid <> blocking.spid
	AND blocked.spid >= 50 --spids lower than 50 are system spids
	AND (blocked.waitTime >= 60000 -- 60 seconds
		OR DATEDIFF(mi, blocked.last_batch, getdate()) > 1) -- 1 minute

	--SELECT * from master.dbo.sysprocesses order by blocked desc

	IF @@rowcount > 0
	BEGIN

		DECLARE
			@i int = 1,
			@rcd_cnt int,
			@blockedHandle varbinary(64),
			@blockedProgram varchar(100),
			@blockingHandle varbinary(64),
			@blockingProgram varchar(100),
			@blockedSql varchar(max),
			@blockingSql varchar(max),
			@jobId uniqueidentifier,
			@job varchar(100),
			@tableHtml varchar(max);

		SET @rcd_cnt = (SELECT count(*) from #blocks);
		PRINT @rcd_cnt;

		WHILE @i <= @rcd_cnt
		BEGIN

			SELECT
				@blockedHandle = blockedHandle,
				@blockedProgram = blockedProgram,
				@blockingHandle = blockingHandle,
				@blockingProgram = blockingProgram
			 from #blocks
			 where id_key = @i;

			TRUNCATE table #sql;
			INSERT into #sql SELECT * FROM sys.fn_get_sql (@blockedHandle);
			UPDATE #blocks SET blockedSql = (SELECT cast (sqltext as varchar(max)) from #sql) where id_key = @i;

			TRUNCATE table #sql
			INSERT into #sql SELECT * FROM sys.fn_get_sql (@blockingHandle);
			UPDATE #blocks SET blockingSql = (SELECT  cast (sqltext as varchar(max)) from #sql) where id_key = @i;

			IF @blockedProgram like '%JobStep%'
			BEGIN
				EXEC @jobId = dbo.GetJobIdFromProgramName @blockedProgram;
				SELECT @job = name from msdb.dbo.sysjobs where job_id = @jobId;
				UPDATE #blocks SET blockedSql = @job where id_key = @i;
			END

			IF @blockingProgram like '%JobStep%'
			BEGIN
				EXEC @jobId = dbo.GetJobIdFromProgramName @blockingProgram;
				SELECT @job = name from msdb.dbo.sysjobs where job_id = @jobId;
				UPDATE #blocks SET blockingSql = @job where id_key = @i;
			END

			SET @i = @i + 1

		END

		--get rid of carriage return, line feed, and tab characters
		UPDATE #blocks SET blockedSql = replace (blockedSql, char(13), ' ')
		UPDATE #blocks SET blockedSql = replace (blockedSql, char(10), ' ')
		UPDATE #blocks SET blockedSql = replace (blockedSql, char(9), ' ')
		UPDATE #blocks SET blockingSql = replace (blockingSql, char(13), ' ')
		UPDATE #blocks SET blockingSql = replace (blockingSql, char(10), ' ')
		UPDATE #blocks SET blockingSql = replace (blockingSql, char(9), ' ')

		--SELECT * from #blocks
		UPDATE #blocks SET
			blockedHost = CASE WHEN replace (blockedHost, ' ', '') = '' then NULL else blockedHost end,
			blockedProgram = CASE WHEN replace (blockedProgram, ' ', '') = '' then NULL else blockedProgram end,
			blockingHost = CASE WHEN replace (blockingHost, ' ', '') = '' then NULL else blockingHost end,
			blockingProgram = CASE WHEN replace (blockingProgram, ' ', '') = '' then NULL else blockingProgram end

		ALTER table #blocks drop column id_key, blockedHandle, blockingHandle

		INSERT into dbo.BlockedSpid
		SELECT *, NULL
		from #blocks;
		--SELECT * from BlockedSpid order by id_key desc

		IF OBJECT_ID ('tempdb..##blocksTable') is not null drop table ##blocksTable
		SELECT DISTINCT
			Db,
			blockedSpid as blocked,
			CASE WHEN blockedHost is not NULL THEN blockedLogin + ' on ' + blockedHost ELSE blockedLogin END as blockedLogin,
			LEFT (blockedSql, 295) blockedSql, --HtmlTable column width limit is 300
			blockedProgram,
			blockingSpid as blocking,
			CASE WHEN blockingHost is not NULL THEN blockingLogin + ' on ' + blockingHost ELSE blockingLogin END as blockingLogin,
			LEFT (blockingSql, 295) blockingSql,--HtmlTable column width limit is 300
			blockingProgram
		into ##blocksTable
		from dbo.BlockedSpid
		where (waitTime >= 60000 -- 60 seconds
					OR DATEDIFF(mi, blockedLastBatch, currentDateTime) > 1) -- 1 minute
		and LoadDate is NULL

		SET @rcd_cnt = @@rowcount
		PRINT @rcd_cnt

		UPDATE dbo.BlockedSpid SET LoadDate = getdate() where LoadDate is NULL

		IF @rcd_cnt > 0
		BEGIN


			--DECLARE @tableHtml varchar(max)
			EXEC dbo.HtmlTable
				'##blocksTable',
				@tableHtml output;

			EXEC dbo.EmailSend
				--SELECT * from Meta.dbo.EmailRecipients where Subject like 'Blocked%'
				@subject = 'Blocked Spid(s)',
				@rcd_cnt = @rcd_cnt,
				@body_format = 'HTML',
				@body = @tableHtml,
				@sproc = @sprocName;

		END
	END

END TRY
BEGIN CATCH
	DECLARE @errorNumber int = ERROR_NUMBER(), @errorMsg VARCHAR(1000) = ERROR_MESSAGE();
	EXEC dbo.ErrorLog @errorNumber, @errorMsg;
END CATCH
PRINT 'END ' + @sprocName;




GO

