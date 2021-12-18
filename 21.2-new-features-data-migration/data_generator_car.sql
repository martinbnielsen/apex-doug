begin
    apex_dg_data_gen.remove_blueprint(p_name  => 'Cars');
end;
/

drop table my_cars;


create table my_cars (
  make varchar2(200),
  model varchar2(200),
  purchase_date date
);


-- Set workspace context
declare
   l_workspace_id      number;
 begin
     l_workspace_id := apex_util.find_security_group_id (p_workspace => 'DEMO');
     apex_util.set_security_group_id (p_security_group_id => l_workspace_id);
 end;
/

begin
    apex_dg_data_gen.add_blueprint(
                 p_name           => 'Cars',
                 p_description    => 'A blueprint to generate car data');
end;
/

select * from apex_dg_blueprints;

begin
    apex_dg_data_gen.add_table(
                 p_blueprint               => 'Cars',
                 p_sequence                => 1,
                 p_table_name              => 'my_cars',
                 p_rows                    => '50');
end;
/

begin
    apex_dg_data_gen.add_column(
                 p_blueprint               => 'Cars',
                 p_sequence                => 1,
                 p_table_name              => 'MY_CARS',
                 p_column_name             => 'make',
                 p_data_source_type        => 'BUILTIN',
                 p_data_source             => 'car.make');
end;
/

select * from apex_dg_bp_tables;

begin
    apex_dg_data_gen.add_column(
                 p_blueprint               => 'Cars',
                 p_sequence                => 2,
                 p_table_name              => 'MY_CARS',
                 p_column_name             => 'model',
                 p_data_source_type        => 'BUILTIN',
                 p_data_source             => 'car.model');
end;
/

begin
    apex_dg_data_gen.add_column(
                 p_blueprint               => 'Cars',
                 p_sequence                => 3,
                 p_table_name              => 'MY_CARS',
                 p_column_name             => 'purchase_date',
                 p_data_source_type        => 'BUILTIN',
                 p_data_source             => 'date.random_past');
end;
/

select * from my_cars;


-- * p_blueprint            Name of the blueprint. This value not
--   p_blueprint_table      Null for all tables. If not null, will generate data only for designated table.
--                          If not null, must be table name of a table within the blueprint. Note: this value is
--                          case sensitive.
--   p_row_scaling          Will scale the number of rows defined into the blueprint by this percentage value.
-- * p_format               When p_format = SQL INSERT then function outputs a sql script
--                                        = CSV then function outputs a ZIP for multiple tables
--                                        = JSON then function outputs JSON
--                                        = INSERT INTO then function runs insert into statements
--                                        = FAST INSERT INTO then function runs insert into select statements

declare
    l_output    blob;
begin
    l_output :=
    apex_dg_output.generate_data
        (p_blueprint          => 'Cars',
         p_blueprint_table    => null,
         p_format             => 'FAST INSERT INTO'
        );
end;
/

select * from my_cars;