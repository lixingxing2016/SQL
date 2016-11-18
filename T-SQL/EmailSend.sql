SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*

Notes:	Wrapper for msdb.dbo.sp_send_dbmail that does some extra stuff.

*/


CREATE PROCEDURE [dbo].[EmailSend]
   @from_address               VARCHAR(max)  = NULL,
   @reply_to                   VARCHAR(max)  = NULL,
   @recipients                 VARCHAR(MAX)  = NULL,
   @copy_recipients            VARCHAR(MAX)  = NULL,
   @blind_copy_recipients      VARCHAR(MAX)  = NULL,
   @subject                    NVARCHAR(255) = NULL,
   @body                       NVARCHAR(MAX) = NULL,
   @body_format				NVARCHAR(20) = NULL,
   @file_attachments           NVARCHAR(MAX) = NULL,
   @query                      NVARCHAR(MAX) = NULL,
   @attach_query_result_as_file BIT          = 0,
   @query_attachment_filename  NVARCHAR(260) = NULL,
   @query_result_header        BIT           = 0,
   @query_result_width         INT           = 400,
   @query_result_separator     CHAR(1)       = ' ',
   @exclude_query_output       BIT           = 1,
   @append_query_error BIT = 0,
   @query_no_truncate BIT = 0,
   @query_result_no_padding BIT = 0,
   @importance VARCHAR(6)    = 'NORMAL',
   @job NVARCHAR(100) = NULL,
   @sproc nvarchar(200) = NULL,
   @rcd_cnt int = NULL,
   @header varchar(100) = NULL,
   @sign bit = 0

--WITH EXECUTE AS 'dbo'

AS
BEGIN

SET NOCOUNT ON

DECLARE
	@jobName varchar(100),
	@sprocName varchar(200) = DB_NAME() + '.' + SCHEMA_NAME() + '.' + OBJECT_NAME (@@PROCID);

SET @jobName = dbo.GetJobName()

IF @recipients is NULL
BEGIN
	SELECT @recipients = Recipients,
			@copy_recipients = CopyRecipients,
			@blind_copy_recipients = BlindCopyRecipients,
			@reply_to = ReplyTo
		FROM dbo.EmailRecipients
		WHERE @subject like Subject + '%'

	UPDATE dbo.EmailRecipients SET LastUsedDate = getdate() WHERE @subject like Subject + '%'
END

INSERT into dbo.AutomatedEmailStage VALUES (
	LEFT (@subject, 100),
	@rcd_cnt,
	LEFT (@file_attachments, 900),
	dateadd (hour, -3, getdate()),
	LEFT (@recipients, 500),
	LEFT (@copy_recipients, 500),
	LEFT (@blind_copy_recipients, 500),
	LEFT (@jobName, 100),
	LEFT (@sproc, 200)
)

IF @body is NULL AND @rcd_cnt is NOT NULL
BEGIN
	SET @body = @subject + ' for ' + cast (getdate() as varchar(6)) + ': ' + cast (@rcd_cnt as varchar(5)) + ' record(s).'
END

IF @rcd_cnt is NOT NULL
BEGIN
	SET @subject = @subject + ': ' + cast (@rcd_cnt as varchar(7)) + ' record(s)'
END

SET @body = @body + '

Job: ' + @jobName


IF @sproc is NOT NULL
BEGIN
	IF @body_format = 'HTML' 	SET @body = @body + '<br>SP: ' + @sproc
	ELSE SET @body = @body + '
SP: ' + @sproc
END

IF @query is NOT NULL
BEGIN
	SET @body = @body + '

'
	IF @header is NOT NULL SET @body = @body + @header
END

IF @body_format = 'HTML' and @sign = 1 and email.dbo.CheckEmailAddr (@reply_to) = 1
BEGIN

	DECLARE @sig varchar(2000)
	EXEC @sig = dbo.HtmlSig @reply_to
	SET @body = @body + @sig

END


EXEC msdb.dbo.sp_send_dbmail
	@profile_name = 'Database_Mail',
	@from_address = @from_address,
	@reply_to = @reply_to,
	@recipients = @recipients,
	@copy_recipients = @copy_recipients,
	@blind_copy_recipients = @blind_copy_recipients,
	@subject = @subject,
	@body = @body,
	@body_format = @body_format,
	@file_attachments = @file_attachments,
	@query = @query,
	@attach_query_result_as_file = @attach_query_result_as_file,
	@query_attachment_filename = @query_attachment_filename,
	@query_result_header = @query_result_header,
	@query_result_width = @query_result_width,
	@query_result_separator = @query_result_separator,
	@exclude_query_output = @exclude_query_output,
	@importance = @importance

IF @file_attachments is NOT NULL and @file_attachments <> '' and @file_attachments not like '%Archive%'
BEGIN
	--need to move attachment files to Archive folder
	EXEC dbo.EmailReportArchive @file_attachments

END

PRINT 'END ' + @sprocName

END



GO

