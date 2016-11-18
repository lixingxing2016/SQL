USE [Meta]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






/*
Author: Leigh Haynes
Date: February 2015

*/


CREATE PROCEDURE [dbo].[LogError]
	@errorNum int,
	@errorMsg varchar(1000),
	@sprocName varchar(200)


AS

SET NOCOUNT ON;

DECLARE
	@programName varchar(100),
	@jobId uniqueidentifier,
	@job varchar(100),
	@stepNumber int,
	@step varchar(200)
	
SET @programName = (SELECT RTRIM (program_name) from master.dbo.sysprocesses where spid = @@spid)
--SET @programName = 'SQLAgent - TSQL JobStep (Job 0x06D28E05171D614680A59D44A07815C1 : Step 1)' 

IF @programName like '%jobstep%'
BEGIN

	EXEC @jobId = dbo.GetJobIdFromProgramName @programName
	SET @job = (SELECT name from msdb.dbo.sysjobs where job_id = @jobId)
	SET @stepNumber = CAST (REPLACE (RIGHT (@programName, 3), ')', '') as INT)
	SET @step = (SELECT step_name from msdb.dbo.sysjobsteps where job_id = @jobId and step_id = @stepNumber)
	
	INSERT into dbo.AutomationErrors (
		Server,
		Job,
		Step,
		StepName,
		ErrorDate,
		ErrorNumber,
		ErrorMessage
	) VALUES (
		'SQLDM',
		@job,
		@stepNumber,
		ISNULL (@sprocName, @step),
		getdate(), --ErrorDate
		@errorNum,
		@errorMsg)
	--SELECT * from Meta.dbo.AutomationErrors order by id_key desc

	RAISERROR (@errorMsg, 18, 1)

END










GO

