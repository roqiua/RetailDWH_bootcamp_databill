
USE RetailDWH;


GO
-- Drop tables if they exist (existing data will be deleted).
DROP TABLE IF EXISTS dbo.etl_execution_log;

DROP TABLE IF EXISTS dbo.etl_batch_log;


GO
-- Stores overall ETL batch execution status.
CREATE TABLE dbo.etl_batch_log
(
    batch_id INT IDENTITY (1, 1) PRIMARY KEY, -- Batch ID
    start_date DATETIME2 DEFAULT SYSDATETIME() NOT NULL, -- Start time
    end_date DATETIME2 NULL, -- End time
    status VARCHAR (20) DEFAULT 'Running' NOT NULL -- Running/Succeeded/Failed
);


GO
-- Stores each table's ETL operation results.
CREATE TABLE dbo.etl_execution_log
(
    log_id INT IDENTITY (1, 1) PRIMARY KEY, -- Log ID
    batch_id INT NOT NULL, -- Parent batch ID
    table_name NVARCHAR (128), -- Staging table name
    operation_type NVARCHAR (50), -- Truncate/Insert/Overwrite
    load_type NVARCHAR (50), -- Full refresh / Overwrite
    no_rows INT, -- Number of rows
    is_success INT, -- 1 = Success, 0 = Failure, -1 = Truncate failure
    message NVARCHAR (MAX), -- Result or error message
    execution_date DATETIME DEFAULT GETDATE(), -- Log timestamp
    -- Links each operation log to its batch.
    CONSTRAINT FK_etl_execution_log_batch FOREIGN KEY (batch_id) REFERENCES dbo.etl_batch_log (batch_id)
);


GO
