drop table if exists VT26082774B67B__DWH.h_users;

create table VT26082774B67B__DWH.h_users
(
    hk_user_id bigint primary key,
    user_id int,
    registration_dt datetime,
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_user_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

drop table if exists VT26082774B67B__DWH.h_dialogs;

create table VT26082774B67B__DWH.h_dialogs
(
    hk_message_id bigint primary key,
    message_id int,
    message_ts datetime,
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_message_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

drop table if exists VT26082774B67B__DWH.h_groups;

create table VT26082774B67B__DWH.h_groups
(
    hk_group_id bigint primary key,
    group_id int,
    registration_dt datetime,
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_group_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

INSERT INTO VT26082774B67B__DWH.h_users(hk_user_id, user_id, registration_dt, load_dt, load_src)
SELECT
    hash(id) as hk_user_id,
    id as user_id,
    registration_dt,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.users
WHERE hash(id) NOT IN (SELECT hk_user_id FROM VT26082774B67B__DWH.h_users);

INSERT INTO VT26082774B67B__DWH.h_dialogs(hk_message_id, message_id, message_ts, load_dt, load_src)
SELECT
    hash(message_id) as hk_message_id,
    message_id,
    message_ts,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.dialogs
WHERE hash(message_id) NOT IN (SELECT hk_message_id FROM VT26082774B67B__DWH.h_dialogs);

INSERT INTO VT26082774B67B__DWH.h_groups(hk_group_id, group_id, registration_dt, load_dt, load_src)
SELECT
    hash(id) as hk_group_id,
    id as group_id,
    registration_dt,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.groups
WHERE hash(id) NOT IN (SELECT hk_group_id FROM VT26082774B67B__DWH.h_groups);

drop table if exists VT26082774B67B__DWH.l_user_message;

create table VT26082774B67B__DWH.l_user_message
(
    hk_l_user_message bigint primary key,
    hk_user_id bigint not null CONSTRAINT fk_l_user_message_user REFERENCES VT26082774B67B__DWH.h_users (hk_user_id),
    hk_message_id bigint not null CONSTRAINT fk_l_user_message_message REFERENCES VT26082774B67B__DWH.h_dialogs (hk_message_id),
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_user_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

drop table if exists VT26082774B67B__DWH.l_admins;

create table VT26082774B67B__DWH.l_admins
(
    hk_l_admin_id bigint primary key,
    hk_user_id bigint not null CONSTRAINT fk_l_admin_user REFERENCES VT26082774B67B__DWH.h_users (hk_user_id),
    hk_group_id bigint not null CONSTRAINT fk_l_admin_group REFERENCES VT26082774B67B__DWH.h_groups (hk_group_id),
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_l_admin_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

--drop table if exists VT26082774B67B__DWH.l_user_group;
--
--create table VT26082774B67B__DWH.l_user_group
--(
--    hk_l_user_group bigint primary key,
--    hk_user_id bigint not null CONSTRAINT fk_l_user_group_user REFERENCES VT26082774B67B__DWH.h_users (hk_user_id),
--    hk_group_id bigint not null CONSTRAINT fk_l_user_group_group REFERENCES VT26082774B67B__DWH.h_groups (hk_group_id),
--    load_dt datetime,
--    load_src varchar(20)
--)
--order by load_dt
--SEGMENTED BY hk_user_id all nodes
--PARTITION BY load_dt::dateINSERT INTO VT26082774B67B__DWH.l_admins(hk_l_admin_id, hk_group_id, hk_user_id, load_dt, load_src)
SELECT
    hash(hg.hk_group_id, hu.hk_user_id),
    hg.hk_group_id,
    hu.hk_user_id,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.groups as g
LEFT JOIN VT26082774B67B__DWH.h_users as hu ON g.admin_id = hu.user_id
LEFT JOIN VT26082774B67B__DWH.h_groups as hg ON g.id = hg.group_id
WHERE hash(hg.hk_group_id, hu.hk_user_id) NOT IN (SELECT hk_l_admin_id FROM VT26082774B67B__DWH.l_admins);
--GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

drop table if exists VT26082774B67B__DWH.l_groups_dialogs;

create table VT26082774B67B__DWH.l_groups_dialogs
(
    hk_l_groups_dialogs bigint primary key,
    hk_group_id bigint not null CONSTRAINT fk_l_groups_dialogs_group REFERENCES VT26082774B67B__DWH.h_groups (hk_group_id),
    hk_message_id bigint not null CONSTRAINT fk_l_groups_dialogs_message REFERENCES VT26082774B67B__DWH.h_dialogs (hk_message_id),
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_l_groups_dialogs all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);


--ГРУЗИМ ЛИНКИ
INSERT INTO VT26082774B67B__DWH.l_admins(hk_l_admin_id, hk_group_id, hk_user_id, load_dt, load_src)
SELECT
    hash(hg.hk_group_id, hu.hk_user_id),
    hg.hk_group_id,
    hu.hk_user_id,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.groups as g
LEFT JOIN VT26082774B67B__DWH.h_users as hu ON g.admin_id = hu.user_id
LEFT JOIN VT26082774B67B__DWH.h_groups as hg ON g.id = hg.group_id
WHERE hash(hg.hk_group_id, hu.hk_user_id) NOT IN (SELECT hk_l_admin_id FROM VT26082774B67B__DWH.l_admins);

INSERT INTO VT26082774B67B__DWH.l_groups_dialogs(hk_l_groups_dialogs, hk_group_id, hk_message_id, load_dt, load_src)
SELECT
    hash(hg.hk_group_id, hd.hk_message_id),
    hg.hk_group_id,
    hd.hk_message_id,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.dialogs as d
LEFT JOIN VT26082774B67B__DWH.h_groups as hg ON d.message_group = hg.group_id
LEFT JOIN VT26082774B67B__DWH.h_dialogs as hd ON d.message_id = hd.message_id
WHERE d.message_group IS NOT NULL
    AND hash(hg.hk_group_id, hd.hk_message_id) NOT IN (SELECT hk_l_groups_dialogs FROM VT26082774B67B__DWH.l_groups_dialogs);

INSERT INTO VT26082774B67B__DWH.l_user_message(hk_l_user_message, hk_user_id, hk_message_id, load_dt, load_src)
SELECT
    hash(hu.hk_user_id, hd.hk_message_id),
    hu.hk_user_id,
    hd.hk_message_id,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.dialogs as d
LEFT JOIN VT26082774B67B__DWH.h_users as hu ON d.message_from = hu.user_id
LEFT JOIN VT26082774B67B__DWH.h_dialogs as hd ON d.message_id = hd.message_id
WHERE hu.hk_user_id IS NOT NULL
    AND hash(hu.hk_user_id, hd.hk_message_id) NOT IN (SELECT hk_l_user_message FROM VT26082774B67B__DWH.l_user_message);

--СОЗДАЕМ САТЕЛИТЫ и ЗАПОЛНЯЕМ

drop table if exists VT26082774B67B__DWH.s_admins;

create table VT26082774B67B__DWH.s_admins
(
    hk_admin_id bigint not null CONSTRAINT fk_s_admins_l_admins REFERENCES VT26082774B67B__DWH.l_admins (hk_l_admin_id),
    is_admin boolean,
    admin_from datetime,
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_admin_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

INSERT INTO VT26082774B67B__DWH.s_admins(hk_admin_id, is_admin, admin_from, load_dt, load_src)
SELECT 
    la.hk_l_admin_id,
    True as is_admin,
    hg.registration_dt,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__DWH.l_admins as la
LEFT JOIN VT26082774B67B__DWH.h_groups as hg ON la.hk_group_id = hg.hk_group_id;


--

drop table if exists VT26082774B67B__DWH.s_user_socdem;

create table VT26082774B67B__DWH.s_user_socdem
(
    hk_user_id bigint not null CONSTRAINT fk_s_user_socdem_h_users REFERENCES VT26082774B67B__DWH.h_users (hk_user_id),
    country varchar(100),
    age int,
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_user_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

INSERT INTO VT26082774B67B__DWH.s_user_socdem(hk_user_id, country, age, load_dt, load_src)
SELECT 
    hu.hk_user_id,
    u.country,
    u.age,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.users as u
LEFT JOIN VT26082774B67B__DWH.h_users as hu ON u.id = hu.user_id;

--
drop table if exists VT26082774B67B__DWH.s_user_chatinfo;

create table VT26082774B67B__DWH.s_user_chatinfo
(
    hk_user_id bigint not null CONSTRAINT fk_s_user_chatinfo_h_users REFERENCES VT26082774B67B__DWH.h_users (hk_user_id),
    chat_name varchar(255),
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_user_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

INSERT INTO VT26082774B67B__DWH.s_user_chatinfo(hk_user_id, chat_name, load_dt, load_src)
SELECT 
    hu.hk_user_id,
    u.chat_name,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.users as u
LEFT JOIN VT26082774B67B__DWH.h_users as hu ON u.id = hu.user_id;

--
drop table if exists VT26082774B67B__DWH.s_group_name;

create table VT26082774B67B__DWH.s_group_name
(
    hk_group_id bigint not null CONSTRAINT fk_s_group_name_h_groups REFERENCES VT26082774B67B__DWH.h_groups (hk_group_id),
    group_name varchar(255),
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_group_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

INSERT INTO VT26082774B67B__DWH.s_group_name(hk_group_id, group_name, load_dt, load_src)
SELECT 
    hg.hk_group_id,
    g.group_name,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.groups as g
LEFT JOIN VT26082774B67B__DWH.h_groups as hg ON g.id = hg.group_id;

--
drop table if exists VT26082774B67B__DWH.s_group_private_status;

create table VT26082774B67B__DWH.s_group_private_status
(
    hk_group_id bigint not null CONSTRAINT fk_s_group_private_status_h_groups REFERENCES VT26082774B67B__DWH.h_groups (hk_group_id),
    is_private boolean,
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_group_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

INSERT INTO VT26082774B67B__DWH.s_group_private_status(hk_group_id, is_private, load_dt, load_src)
SELECT 
    hg.hk_group_id,
    CASE WHEN g.is_private = 1 THEN True ELSE False END as is_private,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.groups as g
LEFT JOIN VT26082774B67B__DWH.h_groups as hg ON g.id = hg.group_id;

--
drop table if exists VT26082774B67B__DWH.s_dialog_info;

create table VT26082774B67B__DWH.s_dialog_info
(
    hk_message_id bigint not null CONSTRAINT fk_s_dialog_info_h_dialogs REFERENCES VT26082774B67B__DWH.h_dialogs (hk_message_id),
    message varchar(1000),
    message_from int,
    message_to int,
    load_dt datetime,
    load_src varchar(20)
)
order by load_dt
SEGMENTED BY hk_message_id all nodes
PARTITION BY load_dt::date
GROUP BY calendar_hierarchy_day(load_dt::date, 3, 2);

INSERT INTO VT26082774B67B__DWH.s_dialog_info(hk_message_id, message, message_from, message_to, load_dt, load_src)
SELECT 
    hd.hk_message_id,
    d.message,
    d.message_from,
    d.message_to,
    now() as load_dt,
    's3' as load_src
FROM VT26082774B67B__STAGING.dialogs as d
LEFT JOIN VT26082774B67B__DWH.h_dialogs as hd ON d.message_id = hd.message_id;