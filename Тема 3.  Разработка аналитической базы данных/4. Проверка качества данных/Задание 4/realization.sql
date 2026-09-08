SELECT 
    MIN(registration_dt) AS datestamp,
    'earliest user registration' AS info
FROM VT26082774B67B__STAGING.users

UNION ALL

SELECT 
    MAX(registration_dt) AS datestamp,
    'latest user registration' AS info
FROM VT26082774B67B__STAGING.users

UNION ALL

SELECT 
    MIN(registration_dt) AS datestamp,
    'earliest group creation' AS info
FROM VT26082774B67B__STAGING.groups

UNION ALL

SELECT 
    MAX(registration_dt) AS datestamp,
    'latest group creation' AS info
FROM VT26082774B67B__STAGING.groups

UNION ALL

SELECT 
    MIN(message_ts) AS datestamp,
    'earliest dialog message' AS info
FROM VT26082774B67B__STAGING.dialogs

UNION ALL

SELECT 
    MAX(message_ts) AS datestamp,
    'latest dialog message' AS info
FROM VT26082774B67B__STAGING.dialogs

ORDER BY datestamp;