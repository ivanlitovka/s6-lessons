create table VT26082774B67B.dialogs
(
    message_id   int PRIMARY KEY,
    message_ts   timestamp(6),
    message_from int REFERENCES members(id),
    message_to int REFERENCES members(id),
    message varchar(1000),
    message_type varchar(100)
)
SEGMENTED BY hash(message_id) all nodes;