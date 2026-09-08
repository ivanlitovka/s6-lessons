-- ============================================
-- Создание таблицы group_log в staging-слое
-- ============================================

-- Удаляем таблицу, если существует
DROP TABLE IF EXISTS VT26082774B67B__STAGING.group_log;

-- Создаем таблицу
CREATE TABLE VT26082774B67B__STAGING.group_log (
    group_id INT,
    user_id INT,
    user_id_from INT,
    event VARCHAR(20),
    datetime TIMESTAMP
)
ORDER BY datetime
SEGMENTED BY group_id ALL NODES
PARTITION BY datetime::DATE
GROUP BY calendar_hierarchy_day(datetime::DATE, 3, 2);

-- Проверяем создание таблицы
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM v_catalog.columns
WHERE table_schema = 'VT26082774B67B__STAGING'
    AND table_name = 'group_log'
ORDER BY ordinal_position;

-- Комментарий
COMMENT ON TABLE VT26082774B67B__STAGING.group_log IS 
'Логи активности пользователей в группах (вход/выход/создание)';

-------------------------------------------------------------------
-- Создаем линк для связи пользователей и групп (активность)
DROP TABLE IF EXISTS VT26082774B67B__DWH.l_user_group_activity;

CREATE TABLE VT26082774B67B__DWH.l_user_group_activity
(
    hk_l_user_group_activity bigint PRIMARY KEY,
    hk_user_id bigint NOT NULL 
        CONSTRAINT fk_l_user_group_activity_user 
        REFERENCES VT26082774B67B__DWH.h_users (hk_user_id),
    hk_group_id bigint NOT NULL 
        CONSTRAINT fk_l_user_group_activity_group 
        REFERENCES VT26082774B67B__DWH.h_groups (hk_group_id),
    load_dt datetime,
    load_src varchar(20)
)
ORDER BY load_dt
SEGMENTED BY hk_user_id ALL NODES
PARTITION BY load_dt::DATE
GROUP BY calendar_hierarchy_day(load_dt::DATE, 3, 2);

-- Проверяем структуру
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM v_catalog.columns
WHERE table_schema = 'VT26082774B67B__DWH'
    AND table_name = 'l_user_group_activity'
ORDER BY ordinal_position;

-- Заполняем линк уникальными связями пользователь-группа из group_log
INSERT INTO VT26082774B67B__DWH.l_user_group_activity(
    hk_l_user_group_activity, 
    hk_user_id, 
    hk_group_id, 
    load_dt, 
    load_src
)
SELECT DISTINCT
    hash(hu.hk_user_id, hg.hk_group_id) as hk_l_user_group_activity,
    hu.hk_user_id,
    hg.hk_group_id,
    NOW() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.group_log AS gl
LEFT JOIN VT26082774B67B__DWH.h_users AS hu ON gl.user_id = hu.user_id
LEFT JOIN VT26082774B67B__DWH.h_groups AS hg ON gl.group_id = hg.group_id
WHERE hu.hk_user_id IS NOT NULL 
    AND hg.hk_group_id IS NOT NULL
    AND hash(hu.hk_user_id, hg.hk_group_id) NOT IN (
        SELECT hk_l_user_group_activity 
        FROM VT26082774B67B__DWH.l_user_group_activity
    );

-- Проверяем количество загруженных записей
SELECT COUNT(*) FROM VT26082774B67B__DWH.l_user_group_activity;

-- Создаем сателлит для истории авторизаций
DROP TABLE IF EXISTS VT26082774B67B__DWH.s_auth_history;

CREATE TABLE VT26082774B67B__DWH.s_auth_history
(
    hk_l_user_group_activity bigint NOT NULL 
        CONSTRAINT fk_s_auth_history_l_user_group_activity 
        REFERENCES VT26082774B67B__DWH.l_user_group_activity (hk_l_user_group_activity),
    user_id_from INT,
    event VARCHAR(20),
    event_dt TIMESTAMP,
    load_dt datetime,
    load_src varchar(20)
)
ORDER BY load_dt
SEGMENTED BY hk_l_user_group_activity ALL NODES
PARTITION BY load_dt::DATE
GROUP BY calendar_hierarchy_day(load_dt::DATE, 3, 2);

-- Проверяем структуру
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM v_catalog.columns
WHERE table_schema = 'VT26082774B67B__DWH'
    AND table_name = 's_auth_history'
ORDER BY ordinal_position;


-- Заполняем сателлит историей событий
INSERT INTO VT26082774B67B__DWH.s_auth_history(
    hk_l_user_group_activity, 
    user_id_from, 
    event, 
    event_dt, 
    load_dt, 
    load_src
)
SELECT 
    luga.hk_l_user_group_activity,
    gl.user_id_from,
    gl.event,
    gl.datetime as event_dt,
    NOW() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.group_log AS gl
LEFT JOIN VT26082774B67B__DWH.h_users AS hu ON gl.user_id = hu.user_id
LEFT JOIN VT26082774B67B__DWH.h_groups AS hg ON gl.group_id = hg.group_id
LEFT JOIN VT26082774B67B__DWH.l_user_group_activity AS luga 
    ON hu.hk_user_id = luga.hk_user_id 
    AND hg.hk_group_id = luga.hk_group_id
WHERE luga.hk_l_user_group_activity IS NOT NULL
    AND hash(hu.hk_user_id, hg.hk_group_id) NOT IN (
        SELECT hk_l_user_group_activity 
        FROM VT26082774B67B__DWH.s_auth_history
    );

-- Проверяем количество загруженных записей
SELECT COUNT(*) FROM VT26082774B67B__DWH.s_auth_history;

-- Проверяем распределение по событиям
SELECT event, COUNT(*) 
FROM VT26082774B67B__DWH.s_auth_history 
GROUP BY event 
ORDER BY COUNT(*) DESC;


-- Временная таблица: количество пользователей, писавших в группах
WITH user_group_messages AS (
    SELECT 
        lgd.hk_group_id,
        COUNT(DISTINCT lum.hk_user_id) AS cnt_users_in_group_with_messages
    FROM VT26082774B67B__DWH.l_groups_dialogs AS lgd
    JOIN VT26082774B67B__DWH.l_user_message AS lum 
        ON lgd.hk_message_id = lum.hk_message_id
    GROUP BY lgd.hk_group_id
)
SELECT 
    hk_group_id,
    cnt_users_in_group_with_messages
FROM user_group_messages
ORDER BY cnt_users_in_group_with_messages DESC
LIMIT 10;

-- Временная таблица: количество пользователей, вступивших в группы
WITH user_group_log AS (
    SELECT 
        luga.hk_group_id,
        COUNT(DISTINCT luga.hk_user_id) AS cnt_added_users
    FROM VT26082774B67B__DWH.l_user_group_activity AS luga
    JOIN VT26082774B67B__DWH.s_auth_history AS sah 
        ON luga.hk_l_user_group_activity = sah.hk_l_user_group_activity
    WHERE sah.event = 'add'
        AND luga.hk_group_id IN (
            SELECT hk_group_id 
            FROM VT26082774B67B__DWH.h_groups 
            ORDER BY registration_dt 
            LIMIT 10
        )
    GROUP BY luga.hk_group_id
)
SELECT 
    hk_group_id,
    cnt_added_users
FROM user_group_log
ORDER BY cnt_added_users DESC
LIMIT 10;

-- Итоговый запрос: конверсия для 10 самых старых групп
WITH user_group_log AS (
    SELECT 
        luga.hk_group_id,
        COUNT(DISTINCT luga.hk_user_id) AS cnt_added_users
    FROM VT26082774B67B__DWH.l_user_group_activity AS luga
    JOIN VT26082774B67B__DWH.s_auth_history AS sah 
        ON luga.hk_l_user_group_activity = sah.hk_l_user_group_activity
    WHERE sah.event = 'add'
        AND luga.hk_group_id IN (
            SELECT hk_group_id 
            FROM VT26082774B67B__DWH.h_groups 
            ORDER BY registration_dt 
            LIMIT 10
        )
    GROUP BY luga.hk_group_id
),
user_group_messages AS (
    SELECT 
        lgd.hk_group_id,
        COUNT(DISTINCT lum.hk_user_id) AS cnt_users_in_group_with_messages
    FROM VT26082774B67B__DWH.l_groups_dialogs AS lgd
    JOIN VT26082774B67B__DWH.l_user_message AS lum 
        ON lgd.hk_message_id = lum.hk_message_id
    WHERE lgd.hk_group_id IN (
        SELECT hk_group_id 
        FROM VT26082774B67B__DWH.h_groups 
        ORDER BY registration_dt 
        LIMIT 10
    )
    GROUP BY lgd.hk_group_id
)
SELECT 
    ugl.hk_group_id,
    ugl.cnt_added_users,
    COALESCE(ugm.cnt_users_in_group_with_messages, 0) AS cnt_users_in_group_with_messages,
    COALESCE(
        ROUND(
            ugm.cnt_users_in_group_with_messages::DECIMAL / NULLIF(ugl.cnt_added_users, 0) * 100, 
            2
        ), 
        0
    ) AS group_conversion
FROM user_group_log AS ugl
LEFT JOIN user_group_messages AS ugm 
    ON ugl.hk_group_id = ugm.hk_group_id
ORDER BY group_conversion DESC;
