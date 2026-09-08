-- Проверка диапазона дат для всех таблиц
SELECT 
    MIN(registration_dt) >= '2020-09-03' AS no_false_start_dates,
    MAX(registration_dt) <= NOW() AS no_future_dates,
    'users' AS dataset
FROM VT26082774B67B__STAGING.users

UNION ALL

SELECT 
    MIN(registration_dt) >= '2020-09-03' AS no_false_start_dates,
    MAX(registration_dt) <= NOW() AS no_future_dates,
    'groups' AS dataset
FROM VT26082774B67B__STAGING.groups

UNION ALL

SELECT 
    MIN(message_ts) >= '2020-09-03' AS no_false_start_dates,
    MAX(message_ts) <= NOW() AS no_future_dates,
    'dialogs' AS dataset
FROM VT26082774B67B__STAGING.dialogs

ORDER BY dataset;