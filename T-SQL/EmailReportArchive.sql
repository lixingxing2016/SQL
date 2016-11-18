USE [Meta]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[EmailReportArchive]
   @file_attachments               VARCHAR(MAX)  = NULL

AS

SET NOCOUNT ON
DECLARE	@sprocName varchar(200) = DB_NAME() + '.' + SCHEMA_NAME() + '.' + OBJECT_NAME (@@PROCID)
BEGIN TRY


	CREATE table #files (filename varchar(200), folder varchar(200))
	DECLARE @full_path varchar(200), @folder varchar(200), @len int, @filename_len int

	--need to parse files in case there are multiple files in the attachment
	WHILE @file_attachments like '%;%'
	BEGIN
		SET @full_path = SUBSTRING (@file_attachments, 1, charindex (';', @file_attachments) - 1)
		SET @full_path = LTRIM (RTRIM (@full_path))
		SET @len = len (@full_path)
		SET @folder = REVERSE (@full_path)
		SET @filename_len = charindex ('\', @folder)
		SET @folder = SUBSTRING (@full_path, 1, @len - @filename_len + 1)
		INSERT into #files VALUES (@full_path, @folder)
		SET @file_attachments = SUBSTRING (@file_attachments, @len + 2, len (@file_attachments) - charindex (';', @file_attachments))
	END

	SET @full_path = LTRIM (RTRIM (@file_attachments))
	SET @len = len (@full_path)
	SET @folder = REVERSE (@full_path)
	SET @filename_len = charindex ('\', @folder)
	SET @folder = SUBSTRING (@full_path, 1, @len - @filename_len + 1)
	INSERT into #files VALUES (@full_path, @folder)
	--SELECT * from #files

	DECLARE
		@cmd varchar(300),
		@archiveFolder varchar(200),
		@filename varchar(200),
		@result int

	WHILE (SELECT count(*) from #files) > 0
	BEGIN
		SELECT @filename = filename, @folder = folder from #files order by filename
		SET @archiveFolder = @folder + 'Archive\'

		--check whether the Archive folder already exists, if not, create it.
		SET @cmd = 'IF NOT EXIST ' + @archiveFolder + ' MKDIR ' + @archiveFolder
		EXEC master.sys.xp_cmdshell @cmd;

		SET @cmd = 'MOVE ' + @filename + ' ' + @archiveFolder
		EXEC master.sys.xp_cmdshell @cmd
		DELETE from #files where filename = @filename
	END


END TRY
BEGIN CATCH
	DECLARE @errorNumber int = ERROR_NUMBER(), @errorMsg VARCHAR(1000) = ERROR_MESSAGE()
	EXEC dbo.LogError @errorNumber, @errorMsg, @sprocName
END CATCH
PRINT 'END ' + @sprocName




GO

