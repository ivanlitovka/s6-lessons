-- Проверка уникальности id пользователей
SELECT 
    COUNT(id) AS COUNT,
    COUNT(DISTINCT id) AS COUNT
FROM VT26082774B67B__STAGING.users;