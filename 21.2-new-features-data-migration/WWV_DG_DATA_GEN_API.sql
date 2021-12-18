create or replace NONEDITIONABLE package wwv_dg_data_gen_api authid definer  as
--------------------------------------------------------------------------------
--
-- Copyright (c) Oracle Corporation 1999 - 2021. All Rights Reserved.
--
-- This package contains the implementation for data generation in APEX.
--
--
-- Since: 21.1
--
--    MODIFIED   (MM/DD/YYYY)
--     jstraub    01/11/2021 - Created from Anton Nielsen, Neelesh Shah, Martin D'Souza
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Misc Globals
--------------------------------------------------------------------------------
c_ds_data_source_type_table    constant varchar2(30)  := 'TABLE';
c_ds_data_source_type_query    constant varchar2(30)  := 'SQL_QUERY';
--
c_col_ds_type_blueprint        constant varchar2(30)  := 'BLUEPRINT';
c_col_ds_type_builtin          constant varchar2(30)  := 'BUILTIN';
c_col_ds_type_data_source      constant varchar2(30)  := 'DATA_SOURCE';
c_col_ds_type_formula          constant varchar2(30)  := 'FORMULA';
c_col_ds_type_inline           constant varchar2(30)  := 'INLINE';
c_col_ds_type_sequence         constant varchar2(30)  := 'SEQUENCE';
c_col_ds_type_table_column     constant varchar2(30)  := 'TABLE_COLUMN';
--
c_max_error_count              constant number        := 10000;
c_comma                        constant varchar2 (1)  := ',';
c_nl                           constant varchar2 (15) := chr (13) || chr(10);
c_json_date_format             constant varchar2 (32) := 'YYYY-MM-DD"T"HH24:MI:SS"Z"';


$IF sys.dbms_db_version.version < 18 $THEN

$ELSE
--==================================================================================================================
-- This function creates and returns the "insert ... select" statement for a single table within a blueprint
-- This function is called inside a loop in the generate_dataset procedure and excecuted via execute immediate or dbms_sql to populate a GTT with data to be downloaded.
-- This statement can also be used to validate a blueprint. the results of this can be found in the debug log by looking for *** table_name.
--
-- Returns:
-- Returns a SQL statement as a CLOB. This statement is an "insert...select" into the apex_dg_dataset_row global temporary table.
--
--
-- Parameters:
-- * p_blueprint_table_id   ID of blueprint_table
--   p_rows                 Will override the number of rows defined within the blueprint for this table
--   p_row_scaling          If p_rows is null, will scale the number of rows defined into the blueprint by this percentage value.
-- * p_dataset_id           ID of the dataset that this will be associated with
--
-- Example:
--
--
--   declare
--       l_sql clob;
--   begin
--       l_sql := apex_dg_data_gen.generate_dataset_sql(
--                    p_blueprint_table_id => 1,
--                    p_rows               => null,
--                    p_row_scaling        => 100,
--                    p_dataset_id         => 2);
--   end;
--==================================================================================================================
function generate_dataset_sql
    (p_blueprint_table_id    in number,
     p_rows                  in number default null,
     p_row_scaling           in number default 100,
     p_dataset_id            in number
    ) return clob;


--==================================================================================================================
-- This procedure creates a blueprint which is a collection of tables with corresponding columns and data generation
-- attributes
--
-- Parameters:
-- * p_name:           Name of blueprint, combination of name and language are unique, Name is automatically upper cased.
--   p_default_schema  Not used
--   p_description     Description of blueprint to aid in.
--   p_lang            blueprint language determines values from builtin data sources. If the builtin data source has
--                     0 records in this language, 'en' is used

-- Example:
--
--
--   begin
--       apex_dg_data_gen.add_blueprint(
--                    p_name           => 'Cars',
--                    p_description    => 'A blueprint to generate car data');
--   end;
--==================================================================================================================
procedure add_blueprint
   (p_name                  in varchar2,
    p_default_schema        in varchar2 default null,
    p_description           in varchar2 default null,
    p_lang                  in varchar2 default 'en'
   );


--==================================================================================================================
-- This procedure removes meta data associated with a blueprint.
--
-- Parameters:
-- * p_name:           Name of blueprint to be removed.
--
--
-- Example:
--
--
--   begin
--       apex_dg_data_gen.remove_blueprint(
--                    p_name           => 'Cars');
--   end;
--==================================================================================================================
procedure remove_blueprint
    (p_name                  in varchar2
    );


--==================================================================================================================
-- This function exports a blueprint in JSON format.
--
-- Parameters:
-- * p_name:           Name of blueprint to be removed.
--   p_pretty          Y to return pretty results, all other values do not.
--
-- Returns:
-- Returns the blueprint as a JSON document in a CLOB.
--
-- Example:
--
--
--   declare
--       l_json clob;
--   begin
--       l_json := apex_dg_data_gen.export_blueprint(
--                    p_name => 'Cars');
--   end;
--==================================================================================================================
function export_blueprint
    (p_name                  in varchar2,
     p_pretty                in varchar2 default 'Y'
    ) return clob;


--==================================================================================================================
-- This procedure imports a JSON blueprint
--
-- Parameters:
-- * p_clob:            Blueprint in JSON format.
--   p_override_name    Name of blueprint, this will override the name provided in p_clob.
--   p_replace          Return error if blueprint exist and p_replace = FALSE. Will replace the blueprint (or p_override_name if provided).
--
--
-- Example:
--
--
--   declare
--       l_json clob;
--   begin
--       l_json := apex_dg_data_gen.export_blueprint(
--                    p_name => 'Cars');
--
--       apex_dg_data_gen.import_blueprint(
--                    p_clob => l_json,
--                    p_replace => TRUE);
--   end;
--==================================================================================================================
procedure import_blueprint
    (p_clob                  in clob,
     p_override_name         in varchar2 default null,
     p_replace               in boolean default FALSE
    );


--==================================================================================================================
-- This procedure creates a data source which identifies a table or query from which you can source data values.
--
-- Parameters:
-- * p_blueprint           identifies blueprint
-- * p_name                name of a data source, Name is upper cased and must be 26 characters or less
-- * p_data_source_type    TABLE, SQL_QUERY
--   p_table               for source type = TABLE. Typically this will match p_name.
--   p_preserve_case       Defaults to N which forces p_table_name to uppercase, if Y perserves casing of p_table
--   p_sql_query           for p_data_source_type  = SQL_QUERY
--   p_where_clause        for p_data_source_type = TABLE, this adds the where clause. Do not include "where" keyword. e.g. deptno <= 20
--   p_inline_data         this will be used for p_data_source_type JSON_DATA
--   p_order_by_column     not used
--
--
-- Example:
--
--
--   begin
--       apex_dg_data_gen.add_data_source(
--                    p_blueprint           => 'Cars',
--                    p_name                => 'apex_dg_builtin_cars',
--                    p_data_source_type    => 'TABLE',
--                    p_table               => 'apex_dg_builtin_cars');
--   end;
--==================================================================================================================
procedure add_data_source

    (p_blueprint             in varchar2,
     p_name                  in varchar2,
     p_data_source_type      in varchar2,
     p_table                 in varchar2 default null,
     p_preserve_case         in varchar2 default 'N',
     p_sql_query             in varchar2 default null,
     p_where_clause          in varchar2 default null,
     p_inline_data           in clob     default null,
     p_order_by_column       in varchar2 default null
    );


--==================================================================================================================
-- This procedure removes meta data associated with the data source for given blueprint.
--
-- Parameters:
-- * p_blueprint           identifies blueprint
-- * p_name                data source to be removed from blueprint
--
--
-- Example:
--
--
--   begin
--       apex_dg_data_gen.remove_data_source(
--                    p_blueprint           => 'Cars',
--                    p_name                => 'apex_dg_builtin_cars');
--   end;
--==================================================================================================================
procedure remove_data_source
    (p_blueprint             in varchar2,
     p_name                  in varchar2
    );


--==================================================================================================================
-- This procedure identifies a destination table for the generated data.
--
-- Parameters:
-- * p_blueprint           identifier for blueprint
-- * p_sequence            1 for first table, 2 for second etc
-- * p_table_name          name of table that can exist or not exist
--   p_preserve_case       defaults to N which forces table name to uppercase, if Y perserves casing of parameter
--   p_display_name        friendly display name
--   p_singular_name       singluar friendly name
--   p_plural_name         plural friendly name
--   p_rows                number of rows to generate for this table

--
--
-- Example:
--
--
--   begin
--       apex_dg_data_gen.add_table(
--                    p_blueprint               => 'Cars',
--                    p_sequence                => 1,
--                    p_table_name              => 'my_cars',
--                    p_rows                    => '50');
--   end;
--==================================================================================================================
procedure add_table
    (p_blueprint             in varchar2,
     p_sequence              in pls_integer,
     p_table_name            in varchar2,
     p_preserve_case         in varchar2 default 'N',
     p_display_name          in varchar2 default null,
     p_singular_name         in varchar2 default null,
     p_plural_name           in varchar2 default null,
     p_rows                  in varchar2 default 0
    );


--==================================================================================================================
-- This procedure removes a table for the specified blueprint.
--
-- Parameters:
-- * p_blueprint           identifier for blueprint
-- * p_table_name          table name to be removed from blueprint
--
--
-- Example:
--
--
--   begin
--       apex_dg_data_gen.remove_table(
--                    p_blueprint               => 'Cars',
--                    p_table_name              => 'MY_CARS');
--   end;
--==================================================================================================================
procedure remove_table
    (p_blueprint             in varchar2,
     p_table_name            in varchar2
    );


--==================================================================================================================
-- This procedure adds a column to the blueprint table.
--
-- Parameters:
-- * p_blueprint             identifier for blueprint
-- * p_sequence              1 for first column, 2 for second etc
-- * p_table_name            table name as known to blueprint (note:first checks exact case, then checks upper case)
-- * p_column_name           name of column
--   p_preserve_case         defaults to N which forces column name to uppercase, if Y perserves casing of parameter
--   p_display_name          a friendly name for a given
--   p_max_length            when generating data (e.g. latin text) substring to this
--   p_multi_value           Y or N (currently  available for BUILTIN table data and INLINE data)
--                           BUILTIN table data will be distinct
--                           INLINE data will be distinct if all values appear once (red,1;blue,1;green,1). Will allow duplicates otherwise (red,3;blue,4;green,8).
--                           Note: database will sometimes misbehave and not give the right number of values
--   p_mv_format             DELIMITED (based upon p_mv_delimiter) or JSON (e.g. {"p_column_name" : ["sympton1","sympton2"]} )
--   p_mv_unique             Y indicates values will not repeat within the multi-value column, N indicates values may repeat
--   p_mv_delimiter          Delimiter for a DELIMITED
--   p_mv_min_entries        Minimum values in a multi value list
--   p_mv_max_entries        Maximum values in a multi value list
--   p_mv_partition_by       This value must match a column in the same builtin data source, e.g. if p_data_sourse is "car.model", this value might be "make" because "car.make" is valid.
--   p_lang                  language code en, de, es *** not currenlty used
-- * p_data_source_type      DATA_SOURCE, BUILTIN, BLUEPRINT, INLINE, SEQUENCE, FORMULA  (Note: FORMULA requires p_data_source to be null)
--   p_data_source           When p_data_source_type = DATA_SOURCE then DATA_SOURCE_NAME.COLUMN_NAME (column names case follows p_ds_preserve_case and by default will upper case)
--                                                   = BUILTIN then see builtin list, must match exactly a builtin
--                                                   = BLUEPRINT references table data already generated (table must have lower sequence), e.g. Dept.Deptno where add_table with p_table_name = Dept and add_column with Deptno exist
--                                                      (note: This is case sensitive. Tables created with p_preserve_case = N are automatically upper cased. Hence, this will typically require DEPT.DEPTNO instead of dept.deptno)
--                                                   = INLINE then PART_TIME,20;FULL_TIME,80
--                                                   = SEQUENCE uses p_sequence_ params
--                                                   = FORMULA p_data_source must be null. Uses p_formula as a plsql formula and {column_name} as substitutions from this table, e.g. p_formula => {first_name}||'.'||{last_name}||'.insum.ca'
--   p_ds_preserve_case      if p_data_source_type in ('DATA_SOURCE'. 'BLUEPRINT') and p_ds_preserve_case = N then the data source will be upper cased to match an upper case table_name.column_name
--   p_min_numeric_value     minimum numeric value, values equal or greater than this value. Note: Only used in BUILTIN functions.
--   p_max_numeric_value     maximum numeric value, values. Note: Only used in BUILTIN functions.
--   p_numeric_precision     0=no decimal values, -1=round to ten, positive integer=# of decimal places
--   p_min_date_value        minimum date value, values equal or greater than this value. Note: Only used in BUILTIN functions.
--   p_max_date_value        maximum date value, must be greater than or equal to p_min_date_value, if specified. Note: Only used in BUILTIN functions.
--   p_format_mask           Format mask when datatype is a date
--   p_date_precision        YEAR, QUARTER, MONTH, WEEK, DAY, HOUR, MINUTE, SECOND. Note: *** not implemented.
--   p_sequence_start_with   Only used when p_data_source_type = SEQUENCE
--   p_sequence_increment    Only used when p_data_source_type = SEQUENCE
--   p_depends_on            only populate when another column in this row is equal to value (including null). Note: not implemented.
--   p_formula               allows referencing columns in this row,
--                           pl/sql expressions that can reference columns defined in this blueprint row
--                           example: {FIRST_NAME}||'.'||{LAST_NAME}||'.insum.ca' (note: substitutions are case sensitive and must match {column_name} exactly. If p_preserve_case was set to N, {COLUMN_NAME} must be upper case.)
--                           can be used on any DATA_SOURCE_TYPE
--                           NOTE: formulas are applied last, after p_percent_blank. Hence if p_percent_blank = 100 but FORMULAR is "sysdate", the column value will be sysdate
--   p_formula_lang          PLSQL and Javascript. Refrence columns in this table as {column_name}.  *** only PLSQL implemented
--   p_custom_attributes     for future expansion
--   p_percent_blank         0-100. This is applied prior to all formulas. Hence, if this column is referenced in a formula, the formula will have a blank when appropriate. A formula on this column, however, may cause the column to not be blank.
--
--
-- Example:
--
--
--   begin
--       apex_dg_data_gen.add_column(
--                    p_blueprint               => 'Cars',
--                    p_sequence                => 1,
--                    p_table_name              => 'MY_CARS',
--                    p_column_name             => 'make',
--                    p_data_source_type        => 'BUILTIN',
--                    p_data_source             => 'car.make');
--   end;
--==================================================================================================================
procedure add_column
    (p_blueprint             in varchar2,
     p_sequence              in pls_integer,
     p_table_name            in varchar2,
     p_column_name           in varchar2,
     p_preserve_case         in varchar2 default 'N',
     p_display_name          in varchar2 default null,
     p_max_length            in number default 4000,
     p_multi_value           in varchar2 default 'N',
     p_mv_format             in varchar2 default 'JSON',
     p_mv_unique             in varchar2 default 'Y',
     p_mv_delimiter          in varchar2 default ':',
     p_mv_min_entries        in integer default 1,
     p_mv_max_entries        in integer default 2,
     p_mv_partition_by       in varchar2 default null,
     p_lang                  in varchar2 default 'en',
     p_data_source_type      in varchar2,
     p_data_source           in varchar2 default null,
     p_ds_preserve_case      in varchar2 default 'N',
     p_min_numeric_value     in number default 1,
     p_max_numeric_value     in number default 10,
     p_numeric_precision     in number default 0,
     p_min_date_value        in date default null,
     p_max_date_value        in date default null,
     p_format_mask           in varchar2 default c_json_date_format,
     p_date_precision        in varchar2 default null,
     p_sequence_start_with   in number default 1,
     p_sequence_increment    in number default 1,
     p_depends_on            in varchar2 default null,
     p_formula               in varchar2 default null,
     p_formula_lang          in varchar2 default 'PLSQL',
     p_custom_attributes     in varchar2 default null,
     p_percent_blank         in number default 0
    );


--==================================================================================================================
-- This procedure removes a column to the blueprint table.
--
-- Parameters:
-- * p_blueprint             identifier for blueprint
-- * p_table_name            name of table within blueprint
-- * p_column_name           ame of column within table
--
--
-- Example:
--
--
--   begin
--       apex_dg_data_gen.remove_column(
--                    p_blueprint               => 'Cars',
--                    p_table_name              => 'MY_CARS',
--                    p_column_name             => 'MAKE');
--   end;
--==================================================================================================================
procedure remove_column
    (p_blueprint             in varchar2,
     p_table_name            in varchar2,
     p_column_name           in varchar2
    );




--==================================================================================================================
-- This procedure will validate appropriate instance settings (table, column, generation level).
--
-- Parameters:
-- * p_json                  JSON Document
-- * p_valid                 Out parameter to identify whether settings are valid
-- * p_result                Out parameter with a detailed message
--
--
-- Example:
--
--   declare
--        l_is_valid varchar2(30);
--        l_messsage clob;
--   begin
--       apex_dg_data_gen.validate_instance_setting(
--                    p_json               => '<json_doc>',
--                    p_valid              => l_is_valid,
--                    p_message            => l_message);
--   end;
--==================================================================================================================
procedure validate_instance_setting
    (p_json    in         clob,
     p_valid   out nocopy varchar2,
     p_message out nocopy clob
    );



--==================================================================================================================
-- Semi colon (;) delimited list of values. For each value add a comma to define weight. Ex "F,45;M,30"
-- Parameters:
-- * p_data                  the list of values
--
--
-- Example:
--
--   declare
--        l_weighted varchar2(4000);
--   begin
--       l_weighted := apex_dg_data_gen.get_weighted_inline_data(
--                        p_data               => 'F;M');
--   end;
--==================================================================================================================
function get_weighted_inline_data
    (p_data in varchar2
    ) return wwv_flow_t_varchar2;


--
--
-- Return the blueprint ID from the name
function get_blueprint_id
    (p_name in varchar2
    ) return number;



--
-- Returns the current process status
procedure process_status
    (x_current_step out        number,
     x_total_steps  out        number,
     x_message      out nocopy varchar2
    );


--
-- wrapper for the procedure to return the current process status
function process_status
    return varchar2;


$END
end wwv_dg_data_gen_api;