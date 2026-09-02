SET SESSION AUTOCOMMIT TO off;

DELETE FROM VT26082774B67B.members WHERE age > 45;

SELECT node_name, projection_name, deleted_row_count FROM DELETE_VECTORS
   where projection_name like 'members%';

SELECT MAX(deleted_row_count) FROM DELETE_VECTORS;

ROLLBACK;