(SELECT COUNT(1), 'missing group admin info' as info
FROM VT26082774B67B__STAGING.groups g
LEFT JOIN VT26082774B67B__STAGING.users u
ON g.admin_id = u.id
WHERE u.id IS NULL)

UNION ALL

(SELECT COUNT(1), 'missing sender info'
FROM VT26082774B67B__STAGING.dialogs d
LEFT JOIN VT26082774B67B__STAGING.users u
ON d.message_from = u.id
WHERE u.id IS NULL)

UNION ALL

(SELECT COUNT(1), 'missing receiver info'
FROM VT26082774B67B__STAGING.dialogs d
LEFT JOIN VT26082774B67B__STAGING.users u
ON d.message_to = u.id
WHERE d.message_group IS NULL AND u.id IS NULL)

UNION ALL 

(SELECT COUNT(1), 'norm receiver info'
FROM VT26082774B67B__STAGING.dialogs d
LEFT JOIN VT26082774B67B__STAGING.users u
ON d.message_to = u.id
WHERE d.message_group IS NULL AND u.id IS NOT NULL);