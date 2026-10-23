
/*
===============================================================================
SSIS ETL PROJECT - VARIABLES AND LOGGING QUERIES
===============================================================================

1. SSIS VARIABLES AND PACKAGE PARAMETERS
===============================================================================

User::batch_id
    Type: Int64
    Identifies the current ETL batch.

User::error_message
    Type: String
    Stores the operation error message.

User::is_success
    Type: Int64
    Values:
         1 = Success
        -1 = Failure

User::row_counts
    Type: Int64
    Stores the number of rows affected by an operation.

User::new_rows_count
    Type: Int64
    Used for Incremental Load.
    Stores the number of new rows detected by SCD Type 1 or Type 2.

User::update_row_count
    Type: Int64
    Used for Incremental Load.
    Stores the number of changed rows detected during the load.
    Stores the number of new rows detected by SCD Type 1 or Type 2.

User::inferred_row_count
    Type: Int64
    Used for Incremental Load.
    Stores the number of inferred rows created or detected during the load.

User::last_mod_date
    Type: DateTime
    Used for Incremental Load.
    Stores the watermark used to identify records modified after
    the previous successful load.

$Package::table_name
    Type: String
    Contains the target table name used for logging and watermark lookup.

$Package::layer_schema
    Type: String
    Identifies the target layer:
        stg        = Staging layer
        dim & fact = Dimension & Fact layer

    The value depends on the layer being loaded.

===============================================================================
2. LOG BATCH START
===============================================================================

OLE DB Parameter Mapping:
    0 = $Package::layer_schema
        Direction: Input
    1 = User::batch_id
        Direction: Output

NOTE:
    Configure the output parameter/result handling to store SCOPE_IDENTITY()
    in User::batch_id. Verify that the selected Execute SQL Task result
    configuration supports this syntax.
===============================================================================
*/

INSERT INTO dbo.etl_batch_log (start_date, layer_schema)
VALUES (GETDATE(), ?);

SET ? = SCOPE_IDENTITY();


/*
===============================================================================
3. LOG BATCH END
===============================================================================

Status = Failed:
    No execution log records exist for the batch, or at least one
    operation has is_success <= 0.

Status = Succeeded:
    Execution log records exist and all operations have is_success > 0.

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = User::batch_id
    2 = User::batch_id
    3 = User::batch_id
===============================================================================
*/

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.etl_execution_log
    WHERE batch_id = ?
)
OR EXISTS
(
    SELECT 1
    FROM dbo.etl_execution_log
    WHERE batch_id = ?
      AND is_success <= 0
)
BEGIN
    UPDATE dbo.etl_batch_log
    SET status = 'Failed',
        end_date = GETDATE()
    WHERE batch_id = ?;
END
ELSE
BEGIN
    UPDATE dbo.etl_batch_log
    SET status = 'Succeeded',
        end_date = GETDATE()
    WHERE batch_id = ?;
END;


/*
===============================================================================
4. OVERWRITE LOAD LOGGING
===============================================================================

Used when existing target data is replaced.

Operation types:
    truncate = Target table truncation.
    insert   = Data insertion.

===============================================================================
4.1 TRUNCATE SUCCESS
===============================================================================

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = $Package::table_name
    2 = User::row_counts
    3 = User::is_success
    4 = User::error_message
===============================================================================
*/

INSERT INTO dbo.etl_execution_log
(
    batch_id,
    table_name,
    operation_type,
    load_type,
    no_rows,
    is_success,
    message
)
VALUES
(
    ?,
    ?,
    N'truncate',
    N'Overwrite',
    ?,
    ?,
    ?
);


/*
===============================================================================
4.2 TRUNCATE FAILURE
===============================================================================

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = $Package::table_name

The failure status and message are hardcoded in this query.
===============================================================================
*/

INSERT INTO dbo.etl_execution_log
(
    batch_id,
    table_name,
    operation_type,
    load_type,
    no_rows,
    is_success,
    message
)
VALUES
(
    ?,
    ?,
    N'truncate',
    N'Overwrite',
    0,
    -1,
    N'Truncate operation failed.'
);


/*
===============================================================================
4.3 INSERT SUCCESS
===============================================================================

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = $Package::table_name
    2 = User::row_counts
===============================================================================
*/

INSERT INTO dbo.etl_execution_log
(
    batch_id,
    table_name,
    operation_type,
    load_type,
    no_rows,
    is_success,
    message
)
VALUES
(
    ?,
    ?,
    N'insert',
    N'Overwrite',
    ?,
    1,
    N'Insert completed successfully.'
);


/*
===============================================================================
4.4 INSERT FAILURE
===============================================================================

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = $Package::table_name
    2 = User::error_message
===============================================================================
*/

INSERT INTO dbo.etl_execution_log
(
    batch_id,
    table_name,
    operation_type,
    load_type,
    no_rows,
    is_success,
    message
)
VALUES
(
    ?,
    ?,
    N'insert',
    N'Overwrite',
    0,
    -1,
    N'Overwrite completed failed.'
);


/*
===============================================================================
5. INCREMENTAL LOAD - ROW COUNTS AND CONDITIONS
===============================================================================

New Rows:
    @[User::new_rows_count] > 0

Updated Rows:
    @[User::update_row_count] > 0

Inferred Rows:
    @[User::inferred_row_count] > 0

No Changes:
    @[User::new_rows_count] == 0
    &&
    @[User::update_row_count] == 0
    &&
    @[User::inferred_row_count] == 0

The row-count variables must be populated before these conditions
are evaluated.

===============================================================================
5.1 INCREMENTAL INSERT SUCCESS
===============================================================================

Used when new_rows_count > 0.

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = $Package::table_name
    2 = User::new_rows_count
===============================================================================
*/

INSERT INTO dbo.etl_execution_log
(
    batch_id,
    table_name,
    operation_type,
    load_type,
    no_rows,
    is_success,
    message
)
VALUES
(
    ?,
    ?,
    N'insert',
    N'Incremental',
    ?,
    1,
    N'Insert completed successfully.'
);


/*
===============================================================================
5.2 INCREMENTAL UPDATE CHANGING SUCCESS
===============================================================================

Used when update_row_count > 0.

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = $Package::table_name
    2 = User::update_row_count
===============================================================================
*/

INSERT INTO dbo.etl_execution_log
(
    batch_id,
    table_name,
    operation_type,
    load_type,
    no_rows,
    is_success,
    message
)
VALUES
(
    ?,
    ?,
    N'Update Changing',
    N'Incremental',
    ?,
    1,
    N'Update Changing completed successfully.'
);


/*
===============================================================================
5.3 INCREMENTAL INFERRED ROWS SUCCESS
===============================================================================

Used when inferred_row_count > 0.

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = $Package::table_name
    2 = User::inferred_row_count
===============================================================================
*/

INSERT INTO dbo.etl_execution_log
(
    batch_id,
    table_name,
    operation_type,
    load_type,
    no_rows,
    is_success,
    message
)
VALUES
(
    ?,
    ?,
    N'inferred',
    N'Incremental',
    ?,
    1,
    N'Inferred rows processed successfully.'
);


/*
===============================================================================
5.4 INCREMENTAL NO CHANGES
===============================================================================

Used when all three row-count variables are zero.

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = $Package::table_name
===============================================================================
*/

INSERT INTO dbo.etl_execution_log
(
    batch_id,
    table_name,
    operation_type,
    load_type,
    no_rows,
    is_success,
    message
)
VALUES
(
    ?,
    ?,
    N'incremental',
    N'Incremental',
    0,
    1,
    N'No changes detected.'
);


/*
===============================================================================
5.5 INCREMENTAL FAILURE
===============================================================================

Use this template for a failed incremental operation.
Change operation_type and row count to match the operation that failed.

OLE DB Parameter Mapping:
    0 = User::batch_id
    1 = $Package::table_name
===============================================================================
*/

INSERT INTO dbo.etl_execution_log
(
    batch_id,
    table_name,
    operation_type,
    load_type,
    no_rows,
    is_success,
    message
)
VALUES
(
    ?,
    ?,
    N'Update Changing',
    N'Incremental',
    0,
    -1,
    N'Incremental Load Failed'
);


/*
===============================================================================
6. GET WATERMARK FOR DIMENSION AND FACT LAYERS
===============================================================================

Returns the latest successful watermark recorded for the target table.
If no watermark exists, returns 1900-01-01.

OLE DB Parameter Mapping:
    0 = $Package::table_name

Result Set:
    Single row, single column
    Map the result to User::last_mod_date.
===============================================================================
*/

SELECT
    ISNULL
    (
        MAX(LastSuccessfulWatermark),
        CAST('19000101' AS DATETIME)
    )
FROM etl.Watermarks
WHERE [TableName] = ?;


/*
===============================================================================
7. GET WATERMARK FROM THE STAGING LAYER
===============================================================================

Returns the latest LastModifiedAt value from the specified staging table.
If the table contains no dates, returns 1900-01-01.

OLE DB Parameter Mapping:
    None

Result Set:
    Single row, single column
    Map the result to User::last_mod_date.

NOTE:
    Replace stg.Customers with the relevant staging table.
    Table names cannot be passed as ordinary OLE DB value parameters;
    use a controlled dynamic SQL approach if the table name must vary.
===============================================================================
*/

SELECT
    ISNULL
    (
        MAX(LastModifiedAt),
        CAST('19000101' AS DATETIME)
    )
FROM stg.Customers;


/*
===============================================================================
END OF DOCUMENTATION
===============================================================================
*/
