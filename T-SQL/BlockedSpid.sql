
USE [Meta]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BlockedSpid](
	[id_key] [int] IDENTITY(1,1) NOT NULL,
	[Db] [nvarchar](128) NULL,
	[waitTime] [bigint] NULL,
	[waitType] [nvarchar](25) NULL,
	[blockedSpid] [smallint] NOT NULL,
	[blockedLogin] [nvarchar](128) NULL,
	[blockedHost] [nvarchar](128) NULL,
	[blockedSql] [nvarchar](max) NULL,
	[blockedCmd] [nvarchar](50) NULL,
	[blockedProgram] [nvarchar](128) NULL,
	[blockedStatus] [nvarchar](25) NULL,
	[blockedCpu] [int] NULL,
	[blockedLastBatch] [datetime] NULL,
	[currentDateTime] [datetime] NULL,
	[blockingSpid] [smallint] NOT NULL,
	[blockingLogin] [nvarchar](128) NULL,
	[blockingHost] [nvarchar](128) NULL,
	[blockingSql] [nvarchar](max) NULL,
	[blockingCmd] [nvarchar](50) NULL,
	[blockingProgram] [nvarchar](128) NULL,
	[blockingStatus] [nvarchar](25) NULL,
	[blockingCpu] [int] NULL,
	[blockingLastBatch] [datetime] NULL,
	[LoadDate] [datetime] NULL
) ON [PRIMARY]

GO

