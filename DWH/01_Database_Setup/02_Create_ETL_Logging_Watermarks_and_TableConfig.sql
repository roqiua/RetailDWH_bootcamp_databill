/*
===============================================================================
RETAILDWH - ETL LOGGING AND CONFIGURATION TABLES
===============================================================================
Purpose:
    Create ETL batch logs, execution logs, watermarks, and table configuration.

WARNING:
    Existing tables will be dropped along with their data.
===============================================================================
*/
-- Switch to the RetailDWH database.
USE RetailDWH;


GO
/*
===============================================================================
1. DROP EXISTING TABLES
===============================================================================
Drop child tables before parent tables to avoid foreign key conflicts.
*/
DROP TABLE IF EXISTS dbo.etl_execution_log;


GO
DROP TABLE IF EXISTS dbo.etl_batch_log;


GO
DROP TABLE IF EXISTS etl.Watermarks;


GO
DROP TABLE IF EXISTS etl.TableConfig;


GO
/*
===============================================================================
2. CREATE ETL SCHEMA
===============================================================================
Create the etl schema if it does not already exist.
*/
IF NOT EXISTS (SELECT 1
               FROM   sys.schemas
               WHERE  name = N'etl')
    BEGIN
        EXECUTE (N'CREATE SCHEMA etl');
    END


GO
/*
===============================================================================
3. CREATE ETL BATCH LOG
===============================================================================
Stores the overall status and execution times of each ETL batch.

Status values:
    Running   = Batch is in progress.
    Succeeded = All logged operations completed successfully.
    Failed    = At least one operation failed, or no execution logs exist.
*/
CREATE TABLE dbo.etl_batch_log
(
    batch_id INT IDENTITY (1, 1) PRIMARY KEY,
    start_date DATETIME2 DEFAULT SYSDATETIME() NOT NULL,
    end_date DATETIME2 NULL,
    layer_schema NVARCHAR (50) NULL,
    status VARCHAR (20) DEFAULT 'Running' NOT NULL
);


GO
/*
===============================================================================
4. CREATE ETL EXECUTION LOG
===============================================================================
Stores the result of each ETL operation performed during a batch.

Operation examples:
    truncate = Target table truncation.
    insert   = Data insertion.
    Update Changing = Changed records processed during incremental loading.
    inferred = Inferred dimension members processed.

is_success values:
     1 = Success
     0 = Failure
    -1 = Truncate failure
*/
CREATE TABLE dbo.etl_execution_log
(
    log_id INT IDENTITY (1, 1) PRIMARY KEY,
    batch_id INT NOT NULL,
    table_name NVARCHAR (128) NULL,
    operation_type NVARCHAR (50) NULL,
    load_type NVARCHAR (50) NULL,
    no_rows INT NULL,
    is_success INT NULL,
    message NVARCHAR (MAX) NULL,
    execution_date DATETIME DEFAULT GETDATE() NOT NULL,
    -- Link each execution record to its parent ETL batch.
    CONSTRAINT FK_etl_execution_log_batch FOREIGN KEY (batch_id) REFERENCES dbo.etl_batch_log (batch_id)
);


GO
/*
===============================================================================
5. CREATE WATERMARKS TABLE
===============================================================================
Stores the last successful watermark for each target table in Final Layer.

The watermark is used during incremental loading to identify records
modified after the previous successful load.
*/
CREATE TABLE etl.Watermarks
(
    TableName NVARCHAR (128) NOT NULL,
    LastSuccessfulWatermark DATETIME NULL,
    -- Each table has one stored watermark.
    CONSTRAINT PK_Watermarks PRIMARY KEY (TableName)
);


GO

