-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9

BEGIN;

-- Город покупателя хранится в отдельном справочнике.
CREATE TABLE lab.nf_9_customers (
    customer_id text CONSTRAINT pk_nf_9_customers PRIMARY KEY,
    customer_city text NOT NULL
);

-- Название статуса хранится один раз по его коду.
CREATE TABLE lab.nf_9_statuses (
    status_code text CONSTRAINT pk_nf_9_statuses PRIMARY KEY,
    status_name text NOT NULL
);

-- Данные спора отделены от сообщений.
CREATE TABLE lab.nf_9_disputes (
    dispute_id bigint CONSTRAINT pk_nf_9_disputes PRIMARY KEY,
    order_id text NOT NULL,
    customer_id text NOT NULL,
    status_code text NOT NULL,
    CONSTRAINT fk_nf_9_disputes_customer FOREIGN KEY (customer_id)
        REFERENCES lab.nf_9_customers(customer_id),
    CONSTRAINT fk_nf_9_disputes_status FOREIGN KEY (status_code)
        REFERENCES lab.nf_9_statuses(status_code)
);

-- Сообщение определяет спор и момент создания.
CREATE TABLE lab.nf_9_messages (
    message_id bigint CONSTRAINT pk_nf_9_messages PRIMARY KEY,
    dispute_id bigint NOT NULL,
    created_at timestamp NOT NULL,
    CONSTRAINT uq_nf_9_messages_dispute UNIQUE (dispute_id, message_id),
    CONSTRAINT fk_nf_9_messages_dispute FOREIGN KEY (dispute_id)
        REFERENCES lab.nf_9_disputes(dispute_id)
);

-- Пять строк исходного плоского отношения для нормализации.
CREATE TEMP TABLE nf9_flat ON COMMIT DROP AS
WITH chosen AS (
    SELECT row_number() OVER (ORDER BY o.order_id) AS dispute_id,
           o.order_id, o.customer_id, c.customer_city, o.order_purchase_timestamp
    FROM olist.orders o
    JOIN olist.customers c ON c.customer_id = o.customer_id
    ORDER BY o.order_id
    LIMIT 3
), statuses(status_code, status_name, dispute_id) AS (
    VALUES ('open', 'Открыт', 1), ('review', 'На рассмотрении', 2), ('resolved', 'Решён', 3)
), messages(message_id, dispute_id) AS (
    VALUES (1, 1), (2, 1), (3, 2), (4, 2), (5, 3)
)
SELECT c.dispute_id, c.order_id, c.customer_id, c.customer_city,
       s.status_code, s.status_name, m.message_id,
       c.order_purchase_timestamp + interval '30 days' + m.message_id * interval '1 minute' AS created_at
FROM chosen c
JOIN statuses s USING (dispute_id)
JOIN messages m USING (dispute_id);

-- Заполнение справочников и нормализованных отношений без повторов.
INSERT INTO lab.nf_9_customers SELECT DISTINCT customer_id, customer_city FROM nf9_flat;
INSERT INTO lab.nf_9_statuses SELECT DISTINCT status_code, status_name FROM nf9_flat;
INSERT INTO lab.nf_9_disputes SELECT DISTINCT dispute_id, order_id, customer_id, status_code FROM nf9_flat;
INSERT INTO lab.nf_9_messages SELECT message_id, dispute_id, created_at FROM nf9_flat;

-- Сравнение количества строк до и после декомпозиции.
SELECT 'flat' AS relation, count(*) AS rows FROM nf9_flat
UNION ALL SELECT 'customers', count(*) FROM lab.nf_9_customers
UNION ALL SELECT 'statuses', count(*) FROM lab.nf_9_statuses
UNION ALL SELECT 'disputes', count(*) FROM lab.nf_9_disputes
UNION ALL SELECT 'messages', count(*) FROM lab.nf_9_messages;

-- Проверка однократного хранения названий статусов.
SELECT f.status_code, f.status_name, count(*) AS flat_occurrences,
       (SELECT count(*) FROM lab.nf_9_statuses s WHERE s.status_code = f.status_code) AS normalized_occurrences
FROM nf9_flat f
GROUP BY f.status_code, f.status_name
ORDER BY f.status_code;

-- Восстановление плоского отношения и EXCEPT в обе стороны.
WITH restored AS (
    SELECT d.dispute_id, d.order_id, d.customer_id, c.customer_city,
           d.status_code, s.status_name, m.message_id, m.created_at
    FROM lab.nf_9_messages m
    JOIN lab.nf_9_disputes d USING (dispute_id)
    JOIN lab.nf_9_customers c USING (customer_id)
    JOIN lab.nf_9_statuses s USING (status_code)
)
SELECT 'flat_minus_restored' AS direction, count(*) AS differences
FROM (SELECT * FROM nf9_flat EXCEPT SELECT * FROM restored) a
UNION ALL
SELECT 'restored_minus_flat', count(*)
FROM (SELECT * FROM restored EXCEPT SELECT * FROM nf9_flat) b;

COMMIT;
