-- Создание схемы для staging-слоя
CREATE SCHEMA IF NOT EXISTS VT26082774B67B__STAGING;

-- Удаление таблиц, если они существуют
DROP TABLE IF EXISTS VT26082774B67B__STAGING.users CASCADE;
DROP TABLE IF EXISTS VT26082774B67B__STAGING.groups CASCADE;
DROP TABLE IF EXISTS VT26082774B67B__STAGING.dialogs CASCADE;

-- ============================================
-- Таблица пользователей (staging)
-- ============================================
CREATE TABLE VT26082774B67B__STAGING.users (
    id INT PRIMARY KEY,
    chat_name VARCHAR(200) NOT NULL,
    registration_dt TIMESTAMP NOT NULL,
    country VARCHAR(200) NOT NULL,
    age INT NOT NULL CHECK (age >= 0 AND age <= 120)
)
ORDER BY id;

COMMENT ON TABLE VT26082774B67B__STAGING.users IS 'Staging-слой для данных о пользователях';
COMMENT ON COLUMN VT26082774B67B__STAGING.users.id IS 'Уникальный идентификатор пользователя';
COMMENT ON COLUMN VT26082774B67B__STAGING.users.chat_name IS 'Имя пользователя (ошибочное название поля)';
COMMENT ON COLUMN VT26082774B67B__STAGING.users.registration_dt IS 'Дата и время регистрации пользователя';
COMMENT ON COLUMN VT26082774B67B__STAGING.users.country IS 'Страна проживания пользователя';
COMMENT ON COLUMN VT26082774B67B__STAGING.users.age IS 'Возраст пользователя на момент выгрузки';

-- ============================================
-- Таблица групп (staging) с партиционированием
-- ============================================
CREATE TABLE VT26082774B67B__STAGING.groups (
    id INT PRIMARY KEY,
    admin_id INT NOT NULL,
    group_name VARCHAR(100) NOT NULL,
    registration_dt TIMESTAMP NOT NULL,
    is_private INT NOT NULL CHECK (is_private IN (0, 1))
)
ORDER BY id, admin_id
PARTITION BY registration_dt::date
GROUP BY calendar_hierarchy_day(registration_dt::date, 3, 2);

COMMENT ON TABLE VT26082774B67B__STAGING.groups IS 'Staging-слой для данных о группах с партиционированием по дате регистрации';
COMMENT ON COLUMN VT26082774B67B__STAGING.groups.id IS 'Идентификатор группы';
COMMENT ON COLUMN VT26082774B67B__STAGING.groups.admin_id IS 'Идентификатор администратора группы';
COMMENT ON COLUMN VT26082774B67B__STAGING.groups.group_name IS 'Название группы';
COMMENT ON COLUMN VT26082774B67B__STAGING.groups.registration_dt IS 'Дата и время создания группы';
COMMENT ON COLUMN VT26082774B67B__STAGING.groups.is_private IS 'Флаг приватности: 1 - только участники могут писать, 0 - все';

-- ============================================
-- Таблица диалогов (staging) с партиционированием
-- ============================================
CREATE TABLE VT26082774B67B__STAGING.dialogs (
    message_id INT PRIMARY KEY,
    message_ts TIMESTAMP NOT NULL,
    message_from INT NOT NULL,
    message_to INT NOT NULL,
    message VARCHAR(1000),
    message_group INT
)
ORDER BY message_id
PARTITION BY message_ts::date
GROUP BY calendar_hierarchy_day(message_ts::date, 3, 2);

COMMENT ON TABLE VT26082774B67B__STAGING.dialogs IS 'Staging-слой для данных о диалогах с партиционированием по дате';
COMMENT ON COLUMN VT26082774B67B__STAGING.dialogs.message_id IS 'Идентификатор сообщения';
COMMENT ON COLUMN VT26082774B67B__STAGING.dialogs.message_ts IS 'Время отправки сообщения (со стороны отправителя)';
COMMENT ON COLUMN VT26082774B67B__STAGING.dialogs.message_from IS 'Идентификатор отправителя';
COMMENT ON COLUMN VT26082774B67B__STAGING.dialogs.message_to IS 'Идентификатор получателя';
COMMENT ON COLUMN VT26082774B67B__STAGING.dialogs.message IS 'Текст сообщения';
COMMENT ON COLUMN VT26082774B67B__STAGING.dialogs.message_group IS 'Идентификатор группы (NULL - личное сообщение)';

-- ============================================
-- Добавление внешних ключей
-- ============================================
ALTER TABLE VT26082774B67B__STAGING.groups 
    ADD CONSTRAINT fk_groups_admin_id 
    FOREIGN KEY (admin_id) REFERENCES VT26082774B67B__STAGING.users(id);

ALTER TABLE VT26082774B67B__STAGING.dialogs 
    ADD CONSTRAINT fk_dialogs_message_from 
    FOREIGN KEY (message_from) REFERENCES VT26082774B67B__STAGING.users(id);

ALTER TABLE VT26082774B67B__STAGING.dialogs 
    ADD CONSTRAINT fk_dialogs_message_to 
    FOREIGN KEY (message_to) REFERENCES VT26082774B67B__STAGING.users(id);

ALTER TABLE VT26082774B67B__STAGING.dialogs 
    ADD CONSTRAINT fk_dialogs_message_group 
    FOREIGN KEY (message_group) REFERENCES VT26082774B67B__STAGING.groups(id);

-- ============================================
-- Создание проекций для оптимизации
-- ============================================
CREATE PROJECTION VT26082774B67B__STAGING.users_super 
AS SELECT * FROM VT26082774B67B__STAGING.users 
ORDER BY id 
SEGMENTED BY HASH(id) ALL NODES;

CREATE PROJECTION VT26082774B67B__STAGING.groups_super 
AS SELECT * FROM VT26082774B67B__STAGING.groups 
ORDER BY id, admin_id 
SEGMENTED BY HASH(id) ALL NODES;

CREATE PROJECTION VT26082774B67B__STAGING.dialogs_super 
AS SELECT * FROM VT26082774B67B__STAGING.dialogs 
ORDER BY message_id 
SEGMENTED BY HASH(message_id) ALL NODES;

-- ============================================
-- Дополнительные проекции для оптимизации запросов
-- ============================================
-- Проекция для users по стране (для аналитики)
CREATE PROJECTION VT26082774B67B__STAGING.users_by_country 
AS SELECT 
    id,
    chat_name,
    registration_dt,
    country,
    age
FROM VT26082774B67B__STAGING.users 
ORDER BY country, age 
SEGMENTED BY HASH(id) ALL NODES;

-- Проекция для groups по дате регистрации (с учетом партиционирования)
CREATE PROJECTION VT26082774B67B__STAGING.groups_by_registration 
AS SELECT 
    id,
    admin_id,
    group_name,
    registration_dt,
    registration_dt::date AS registration_date,
    is_private
FROM VT26082774B67B__STAGING.groups 
ORDER BY registration_dt 
SEGMENTED BY HASH(id) ALL NODES;

-- Проекция для groups по администратору
CREATE PROJECTION VT26082774B67B__STAGING.groups_by_admin 
AS SELECT 
    id,
    admin_id,
    group_name,
    registration_dt,
    is_private
FROM VT26082774B67B__STAGING.groups 
ORDER BY admin_id, registration_dt 
SEGMENTED BY HASH(admin_id) ALL NODES;

-- Проекция для dialogs по дате (с учетом партиционирования)
CREATE PROJECTION VT26082774B67B__STAGING.dialogs_by_date 
AS SELECT 
    message_id,
    message_ts,
    message_ts::date AS message_date,
    message_from,
    message_to,
    message,
    message_group
FROM VT26082774B67B__STAGING.dialogs 
ORDER BY message_ts, message_id 
SEGMENTED BY HASH(message_id) ALL NODES;

-- Проекция для dialogs по отправителю
CREATE PROJECTION VT26082774B67B__STAGING.dialogs_by_sender 
AS SELECT 
    message_id,
    message_ts,
    message_from,
    message_to,
    message,
    message_group
FROM VT26082774B67B__STAGING.dialogs 
ORDER BY message_from, message_ts 
SEGMENTED BY HASH(message_from) ALL NODES;

-- ============================================
-- Проверка создания таблиц
-- ============================================
SELECT 
    table_schema,
    table_name,
    column_name,
    data_type,
    is_nullable
FROM columns 
WHERE table_schema = 'VT26082774B67B__STAGING'
ORDER BY table_name, ordinal_position;

-- ============================================
-- Проверка партиций для таблиц
-- ============================================
-- Партиции для groups
SELECT 
    partition_key,
    partition_value,
    segment_id,
    projection_name,
    row_count
FROM partitions 
WHERE table_schema = 'VT26082774B67B__STAGING' 
  AND table_name = 'groups'
ORDER BY partition_value;

-- Партиции для dialogs
SELECT 
    partition_key,
    partition_value,
    segment_id,
    projection_name,
    row_count
FROM partitions 
WHERE table_schema = 'VT26082774B67B__STAGING' 
  AND table_name = 'dialogs'
ORDER BY partition_value;

-- ============================================
-- Примеры запросов с использованием партиций
-- ============================================
-- Быстрый запрос по дате регистрации группы
SELECT COUNT(*) 
FROM VT26082774B67B__STAGING.groups 
WHERE registration_dt::date = '2021-02-10';

-- Группировка по месяцам (использует партиции)
SELECT 
    DATE_TRUNC('month', registration_dt) AS month,
    COUNT(*) AS group_count,
    AVG(is_private) AS private_ratio
FROM VT26082774B67B__STAGING.groups 
WHERE registration_dt >= '2021-01-01'
GROUP BY DATE_TRUNC('month', registration_dt)
ORDER BY month;

ALTER TABLE VT26082774B67B__STAGING.users 
DROP CONSTRAINT C_CHECK;