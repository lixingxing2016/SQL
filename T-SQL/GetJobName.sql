
USE [Meta]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE FUNCTION [dbo].[GetJobName] ()
RETURNS varchar(100)

AS

BEGIN

DECLARE
	@jobName varchar(100),
	@programName varchar(200),
	@jobId uniqueidentifier

--PRINT @@SPID

SET @programName = (SELECT program_name from master.dbo.sysprocesses where spid = @@spid)

--SELECT program_name from master.dbo.sysprocesses where program_name  like '%jobstep%'

IF @programName like '%jobstep%'
BEGIN
	EXEC @jobId = dbo.GetJobIdFromProgramName @programName
	--PRINT @jobId
	SET @jobName = (SELECT name from msdb.dbo.sysjobs where job_id = @jobId)
END
ELSE
BEGIN
	SET @jobName = 'Manual Run'
END

RETURN @jobName

END


GO

