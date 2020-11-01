-- Show APEX dictionary
select *
from apex_dictionary
where column_id = 0
order by apex_view_name;