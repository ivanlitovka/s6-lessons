SELECT 
    'users' AS dataset,
    COUNT(id) AS total,
    COUNT(DISTINCT id) AS uniq
FROM VT26082774B67B__STAGING.users

UNION ALL

SELECT 
    'groups' AS dataset,
    COUNT(id) AS total,
    COUNT(DISTINCT id) AS uniq
FROM VT26082774B67B__STAGING.groups

UNION ALL

SELECT 
    'dialogs' AS dataset,
    COUNT(message_id) AS total,
    COUNT(DISTINCT message_id) AS uniq
FROM VT26082774B67B__STAGING.dialogs

ORDER BY dataset;