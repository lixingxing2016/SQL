
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO


CREATE TABLE [dbo].[AutomationErrors](
	[id_key] [int] IDENTITY(1,1) NOT NULL,
	[Server] [varchar](20) NULL,
	[Job] [varchar](100) NULL,
	[Step] [int] NULL,
	[StepName] [varchar](200) NULL,
	[ErrorDate] [datetime] NULL,
	[ErrorNumber] [int] NULL,
	[ErrorMessage] [varchar](1000) NULL
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

