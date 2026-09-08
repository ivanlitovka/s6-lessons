SELECT 
    s.age,
    COUNT(DISTINCT s.hk_user_id) as unique_users_count
FROM VT26082774B67B__DWH.s_user_socdem s
WHERE s.hk_user_id IN (
    SELECT lum.hk_user_id
    FROM VT26082774B67B__DWH.l_user_message lum
    WHERE lum.hk_message_id IN (
        SELECT lgd.hk_message_id
        FROM VT26082774B67B__DWH.l_groups_dialogs lgd
        WHERE lgd.hk_group_id IN (
            SELECT hg.hk_group_id
            FROM VT26082774B67B__DWH.h_groups hg
            ORDER BY hg.registration_dt
            LIMIT 10
        )
    )
)
GROUP BY s.age
ORDER BY unique_users_count DESC
LIMIT 5;