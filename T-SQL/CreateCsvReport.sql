SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Notes: Takes parameters for a data source (table), report name, and report folder, which are used to create a comma-delimited CSV file containing the column names of the data source in row 1 and the values from the data source in the following rows.

Can be modified to use a different delimiter in lines 142 - 147.

Sample use:

SELECT 123 as Column1, 'ABC' as Column2
into ##MyTable
SELECT * from ##MyTable

DECLARE @report_file varchar(200)
EXEC CreateCsvReport
	'##MyTable',
	'MyReport',
	'Testing\Meta',
	@report_file output

*/

ALTER PROCEDURE [dbo].[CreateCsvReport]
	@data_source varchar (100) = NULL, --table name that contains report data
	@report_name varchar (100) = NULL, --the base name of the report. A datestamp tail is added to this name.
	@folder varchar(100) = NULL, --folder on the filesystem where the report is to be created
	@report_file varchar(300) OUTPUT --UNC reference to the report file that has been created
AS

SET NOCOUNT ON;

DECLARE @sprocName varchar(200) = DB_NAME() + '.' + SCHEMA_NAME() + '.' + OBJECT_NAME (@@PROCID);

BEGIN TRY

	--##columnNames is a pivot of the names of the columns in the data source
	IF OBJECT_ID ('tempdb..##columnNames') IS not null DROP TABLE ##columnNames
	CREATE table ##columnNames (
		column_name varchar(50),
		position int identity
	);

	--##report is the table that will contain all the report data and will be BCP'ed as the report at conclusion
	IF OBJECT_ID ('tempdb..##report') IS not null DROP TABLE ##report
	--every data source must contain at least 1 column. Create the first column of ##report as f1.
	--note that all output fields are max len 300. This can be adjusted if needed.
	CREATE table ##report (f1 varchar(300))

	DECLARE
		@db varchar(30),
		@table varchar(100),
		@sql nvarchar(2000),
		@cmd varchar(400),
		@report_tail varchar(15),
		@today char(21) = convert (char(21), getdate(), 20); --2014-04-28 09:31:28

	--use procedure DataSourceCheck to see if @data_source is a valid table reference
	EXEC Meta.dbo.DataSourceCheck @data_source, @db output, @table output;

	IF @db is NULL --if the data source is not a valid table reference, @db comes back NULL, and @table holds info as to the problem (either the table does not exist, or it is empty).
	BEGIN
		SET @report_file = @table;
		RETURN;
	END;

	--We have a good table. Use information_schema metadata to insert table's column names into ##columnNames.
	SET @sql = 'USE ' + @db + '; INSERT into ##columnNames SELECT column_name from information_schema.columns where table_name = ''' + @table + ''' order by ordinal_position';
	EXEC master.sys.sp_executesql @sql;

	--the names of the fields in ##report are (f1..fn) where n is the number of columns in the data source.
	--the first row of data in ##report contains the names of the columns in the data source.
	--the data source must have at least one column. Put the name of the first column into row 1, column 1 of ##report before looping for the rest of the columns.
	INSERT into ##report (f1) SELECT top 1 column_name from ##columnNames order by position;

	DECLARE
		@i int = 2, --we are starting with the 2nd column of ##report, named f2, as f1 has been seeded above.
		@fieldct int = (SELECT COUNT(*) from ##columnNames),
		@field varchar(100),
		@column varchar(30),
		@value varchar(30);--name of the column, max len 30

	WHILE @i <= @fieldct
	BEGIN

		--add a column to ##report for each column in the data source
		SET @sql = 'ALTER table ##report ADD f' + cast (@i as varchar(2)) + ' varchar(300)';
		EXEC master.sys.sp_executesql @sql;

		--put the name of the corresponding column in the data source into our new column in ##report
		SET @sql = 'UPDATE ##report SET f' + cast (@i as varchar(2)) + ' = (SELECT top 1 column_name from ##columnNames where position = ' + cast (@i as varchar(2)) + ')';
		EXEC master.sys.sp_executesql @sql;

		SET @i = @i + 1;
	END

	--now the names of the data source's columns are in row 1 of ##report.
	--create the SQL query that will insert data from the data source into ##report
	SET @sql = 'INSERT into ##report SELECT ';
	SET @i = 1;

	--loop through to construct SQL query that will get values from the data source. ##report only contains character data, so need to cast all columns as varchar.	 Stop short of the last column.
	WHILE @i < @fieldct
	BEGIN
		SET @column = (SELECT top 1 column_name from ##columnNames where position = cast (@i as varchar(2)));
		SET @field = 'CAST(RTRIM([' + @column + ']) as varchar(300)),';
		SET @sql = @sql + @field;
		SET @i = @i + 1;
	END

	--add last column and finish constructing the SQL query
	SET @column = (SELECT top 1 column_name from ##columnNames where position = @fieldct);
	SET @field = 'CAST(RTRIM([' + @column + ']) as varchar(300)) FROM ' + @data_source;
	SET @sql = @sql + @field;

	--execute the SQL query that has been dynamically constructed
	EXEC master.sys.sp_executesql @sql;
	--##report now contains the report data with the report's column names in row 1.
	--##report is ready for BCP

	--construct path for the BCP of ##report to the file system

	--prepend @folder with UNC values
	SET @folder = '\\MyServer\MyPath\' + @folder;
	IF RIGHT (@folder, 1) <> '\' SET @folder = @folder + '\';

	--create @folder on the file system if needed
	SET @cmd = 'IF NOT EXIST ' + @folder + ' MKDIR ' + @folder;
	EXEC master.sys.xp_cmdshell @cmd;

	--add a ccyymmdd datestamp to the report name
	SET @report_tail = replace (substring (@today, 1, 10), '_', ''); --2014-04-28 09:31:28

	--some reports go multiple times a day. add a timestamp tail
	IF @report_name IN ('MyFrequentReport')
	BEGIN
		SET @report_tail = @report_tail + '_' + replace (substring (@today, 12, 5), ':', ''); --2014-04-28 09:31:28
	END

	--Construct the fully-qualified name of the report file. This value is returned to the invoking procedure.
	SET @report_file = @folder + @report_name + '_' + @report_tail + '.csv';

	--create the report file
	SET @cmd = 'BCP ##report OUT ' + @report_file + ' -S' + @@SERVERNAME + ' -T -c -t,';
	EXEC master.sys.xp_cmdshell @cmd;

	--I find it useful to have the filename in the job history.
	PRINT @report_file;

	--uncomment to check contents of small files.
	--SET @cmd = 'TYPE ' + @report_file;
	--EXEC master.sys.xp_cmdshell @cmd

END TRY

BEGIN CATCH

	DECLARE @errorNumber int = ERROR_NUMBER(), @errorMsg VARCHAR(1000) = ERROR_MESSAGE();

	--call LogError to put error metadata into table AutomationErrors
	EXEC Meta.dbo.LogError @errorNumber, @errorMsg, @sprocName

END CATCH

PRINT 'END ' + @sprocName;

GO


