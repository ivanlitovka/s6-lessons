SELECT 
    COUNT(id) AS total_groups,
    COUNT(DISTINCT hash(group_name)) AS unique_group_names
FROM VT26082774B67B__STAGING.groups;