USE [Meta]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




/*
By:		    Hillash Cheru
Notes:		Detect blocked processes



SELECT top 1000 * from BlockedSpidAgg order by id_key desc





*/



ALTER PROCEDURE [dbo].[BlockedSpidAggLoad]
AS

SET NOCOUNT ON;
DECLARE @sprocName varchar(200) = DB_NAME() + '.' + SCHEMA_NAME() + '.' + OBJECT_NAME (@@PROCID);
BEGIN TRY


	/*
	DELETE
	from BlockedSpid
	where waitTime < 30000
	and datediff (minute, blockedLastBatch, currentDateTime) < 30

	SELECT datediff (minute, blockedLastBatch, currentDateTime) as blockedTime, waitTime, *
	from BlockedSpid
	order by datediff (minute, blockedLastBatch, currentDateTime)  desc

	SELECT datediff (minute, blockedLastBatch, currentDateTime) as blockedTime
	from BlockedSpid
	order by waitTime desc
	*/


	IF OBJECT_ID ('tempdb..#agg') is not null drop table #agg;
	SELECT
		Db,
		max (waitTime) as waitTime,
		blockedSpid,
		blockedLogin,
		blockedHost,
		blockedSql,
		blockedProgram,
		blockedStatus,
		blockingSpid,
		blockingLogin,
		blockingHost,
		blockingSql,
		blockingProgram,
		blockingStatus
	into #agg
	from dbo.BlockedSpid
	where LoadDate > (SELECT max (LoadDate) from dbo.BlockedSpidAgg)
	and blockedSql is not null
	group by
		Db,
		blockedSpid,
		blockedLogin,
		blockedHost,
		blockedSql,
		blockedProgram,
		blockedStatus,
		blockingSpid,
		blockingLogin,
		blockingHost,
		blockingSql,
		blockingProgram,
		blockingStatus
	order by
		Db,
		blockedSpid,
		blockedLogin,
		blockedHost,
		blockedSql,
		blockedProgram,
		blockedStatus,
		blockingSpid,
		blockingLogin,
		blockingHost,
		blockingSql,
		blockingProgram,
		blockingStatus

	INSERT into dbo.BlockedSpidAgg SELECT
		a.Db,
		a.waitTime,
		b.waitType,
		a.blockedSpid,
		a.blockedLogin,
		a.blockedHost,
		a.blockedSql,
		b.blockedCmd,
		a.blockedProgram,
		a.blockedStatus,
		b.blockedCpu,
		b.blockedLastBatch,
		b.currentDateTime,
		a.blockingSpid,
		a.blockingLogin,
		a.blockingHost,
		a.blockingSql,
		b.blockingCmd,
		a.blockingProgram,
		a.blockingStatus,
		b.blockingCpu,
		b.blockingLastBatch,
		b.LoadDate
	from #agg a
	join dbo.BlockedSpid b on
		a.Db = b.Db and
		a.blockedSpid = b.blockedSpid and
		a.blockedLogin = b.blockedLogin and
		a.blockedHost = b.blockedHost and
		a.blockedSql = b.blockedSql and
		a.blockedProgram = b.blockedProgram and
		a.blockedStatus = b.blockedStatus and
		a.blockingSpid = b.blockingSpid  and
		a.blockingLogin = b.blockingLogin and
		a.blockingHost = b.blockingHost and
		a.blockingSql = b.blockingSql and
		a.blockingProgram = b.blockingProgram and
		a.blockingStatus = b.blockingStatus
	order by
		a.Db,
		a.blockedSpid,
		a.blockedLogin,
		a.blockedHost,
		a.blockedSql,
		a.blockedProgram,
		a.blockedStatus,
		a.blockingSpid,
		a.blockingLogin,
		a.blockingHost,
		a.blockingSql,
		a.blockingProgram,
		a.blockingStatus

		PRINT @@rowcount

END TRY
BEGIN CATCH
	DECLARE @errorNumber int = ERROR_NUMBER(), @errorMsg VARCHAR(1000) = ERROR_MESSAGE();
	EXEC dbo.ErrorLog @errorNumber, @errorMsg;
END CATCH
PRINT 'END ' + @sprocName;




GO
