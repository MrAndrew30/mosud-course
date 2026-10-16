-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9

BEGIN;

-- Споры по заказам с платежами.
CREATE TABLE lab.disputes (
    dispute_id bigint CONSTRAINT pk_disputes PRIMARY KEY,
    order_id text NOT NULL CONSTRAINT uq_disputes_order UNIQUE,
    customer_id text NOT NULL,
    payment_sequential integer NOT NULL,
    reason text NOT NULL,
    opened_at timestamp NOT NULL,
    CONSTRAINT uq_disputes_customer UNIQUE (dispute_id, customer_id),
    CONSTRAINT fk_disputes_order FOREIGN KEY (order_id) REFERENCES olist.orders(order_id),
    CONSTRAINT fk_disputes_customer FOREIGN KEY (customer_id) REFERENCES olist.customers(customer_id),
    CONSTRAINT fk_disputes_payment FOREIGN KEY (order_id, payment_sequential)
        REFERENCES olist.order_payments(order_id, payment_sequential),
    CONSTRAINT ck_disputes_reason CHECK (length(btrim(reason)) > 0)
);

-- Сообщения заявителя в рамках спора.
CREATE TABLE lab.dispute_messages (
    message_id bigint CONSTRAINT pk_dispute_messages PRIMARY KEY,
    dispute_id bigint NOT NULL,
    customer_id text NOT NULL,
    message_no integer NOT NULL,
    message_text text NOT NULL,
    created_at timestamp NOT NULL,
    CONSTRAINT uq_dispute_messages_number UNIQUE (dispute_id, message_no),
    CONSTRAINT fk_dispute_messages_dispute FOREIGN KEY (dispute_id, customer_id)
        REFERENCES lab.disputes(dispute_id, customer_id),
    CONSTRAINT fk_dispute_messages_customer FOREIGN KEY (customer_id)
        REFERENCES olist.customers(customer_id),
    CONSTRAINT ck_dispute_messages_number CHECK (message_no > 0),
    CONSTRAINT ck_dispute_messages_text CHECK (length(btrim(message_text)) > 0)
);

-- История статусов с уникальными номерами событий.
CREATE TABLE lab.dispute_status_history (
    dispute_id bigint NOT NULL,
    event_no integer NOT NULL,
    status_code text NOT NULL,
    changed_at timestamp NOT NULL,
    CONSTRAINT pk_dispute_status_history PRIMARY KEY (dispute_id, event_no),
    CONSTRAINT fk_dispute_status_history_dispute FOREIGN KEY (dispute_id)
        REFERENCES lab.disputes(dispute_id),
    CONSTRAINT ck_dispute_status_history_number CHECK (event_no > 0),
    CONSTRAINT ck_dispute_status_history_code CHECK (status_code IN ('open', 'review', 'resolved'))
);

-- Проверка покупателя, положительной оплаты и даты открытия.
CREATE FUNCTION lab.validate_dispute() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM olist.orders o
        JOIN olist.order_payments p ON p.order_id = o.order_id
        WHERE o.order_id = NEW.order_id
          AND o.customer_id = NEW.customer_id
          AND p.payment_sequential = NEW.payment_sequential
          AND p.payment_value > 0
          AND NEW.opened_at >= o.order_purchase_timestamp
    ) THEN
        RAISE EXCEPTION 'Спор должен относиться к оплаченному заказу его покупателя и открываться после покупки';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_dispute
BEFORE INSERT OR UPDATE ON lab.disputes
FOR EACH ROW EXECUTE FUNCTION lab.validate_dispute();

-- Пять тестовых споров по реальным оплаченным заказам.
WITH paid_orders AS (
    SELECT o.order_id, o.customer_id, o.order_purchase_timestamp,
           min(p.payment_sequential) AS payment_sequential
    FROM olist.orders o
    JOIN olist.order_payments p ON p.order_id = o.order_id AND p.payment_value > 0
    GROUP BY o.order_id, o.customer_id, o.order_purchase_timestamp
    ORDER BY o.order_id
    LIMIT 5
)
INSERT INTO lab.disputes
SELECT row_number() OVER (ORDER BY order_id), order_id, customer_id,
       payment_sequential, 'Повреждение упаковки', order_purchase_timestamp + interval '30 days'
FROM paid_orders;

-- По одному сообщению заявителя в каждом споре.
INSERT INTO lab.dispute_messages
SELECT dispute_id, dispute_id, customer_id, 1,
       'Прошу рассмотреть повреждение упаковки.', opened_at
FROM lab.disputes;

-- Начальное событие открытия каждого спора.
INSERT INTO lab.dispute_status_history
SELECT dispute_id, 1, 'open', opened_at FROM lab.disputes;

-- ck_dispute_messages_text отклонит пустой текст.
-- UPDATE lab.dispute_messages SET message_text = ' ' WHERE message_id = 1;

-- ck_dispute_status_history_code отклонит неизвестный статус.
-- INSERT INTO lab.dispute_status_history VALUES (1, 2, 'unknown', TIMESTAMP '2026-01-01');

-- uq_dispute_messages_number отклонит повтор номера сообщения в споре.
-- INSERT INTO lab.dispute_messages SELECT 99, dispute_id, customer_id, 1, 'Повтор', opened_at FROM lab.disputes WHERE dispute_id = 1;

-- Число тестовых строк в новых таблицах.
SELECT 'disputes' AS table_name, count(*) AS rows FROM lab.disputes
UNION ALL SELECT 'dispute_messages', count(*) FROM lab.dispute_messages
UNION ALL SELECT 'dispute_status_history', count(*) FROM lab.dispute_status_history;

-- Типы ограничений в information_schema.
SELECT tc.table_name, tc.constraint_name, tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'lab'
  AND tc.table_name IN ('disputes', 'dispute_messages', 'dispute_status_history')
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- Определения ключей и проверок в pg_catalog.
SELECT conrelid::regclass AS table_name, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN ('lab.disputes'::regclass, 'lab.dispute_messages'::regclass,
                  'lab.dispute_status_history'::regclass)
ORDER BY conrelid::regclass::text, conname;

COMMIT;
