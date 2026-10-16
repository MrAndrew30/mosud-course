-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9

BEGIN;

DROP INDEX IF EXISTS olist.idx_lab13_status_date;
DROP INDEX IF EXISTS olist.idx_lab13_unfinished;

-- Исходные индексы заказов; PK не изменяется.
SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = 'olist' AND tablename = 'orders'
ORDER BY indexname;

ANALYZE olist.orders;

-- План селективного запроса без вторичного индекса.
\echo BEFORE_INDEX
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
-- Отменённые заказы за январь 2018 года.
SELECT order_id, order_status, order_purchase_timestamp
FROM olist.orders
WHERE order_status = 'canceled'
  AND order_purchase_timestamp >= TIMESTAMP '2018-01-01'
  AND order_purchase_timestamp < TIMESTAMP '2018-02-01';

-- Сначала равенство статуса, затем диапазон даты.
CREATE INDEX idx_lab13_status_date
ON olist.orders (order_status, order_purchase_timestamp);
ANALYZE olist.orders;

-- План того же запроса с составным B-tree.
\echo COMPOSITE_INDEX
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT order_id, order_status, order_purchase_timestamp
FROM olist.orders
WHERE order_status = 'canceled'
  AND order_purchase_timestamp >= TIMESTAMP '2018-01-01'
  AND order_purchase_timestamp < TIMESTAMP '2018-02-01';

-- Массовая выборка доставленных заказов для проверки выбора scan.
\echo LOW_SELECTIVITY
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT order_id, order_status, order_purchase_timestamp
FROM olist.orders
WHERE order_status = 'delivered';

-- Размер полного составного индекса.
SELECT 'idx_lab13_status_date' AS index_name,
       pg_relation_size('olist.idx_lab13_status_date') AS bytes,
       pg_size_pretty(pg_relation_size('olist.idx_lab13_status_date')) AS size;

-- Частичный индекс содержит только недоставленные заказы.
CREATE INDEX idx_lab13_unfinished
ON olist.orders (order_status, order_purchase_timestamp)
WHERE order_status <> 'delivered';
ANALYZE olist.orders;

-- План селективного запроса с частичным индексом.
\echo PARTIAL_INDEX
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT order_id, order_status, order_purchase_timestamp
FROM olist.orders
WHERE order_status = 'canceled'
  AND order_purchase_timestamp >= TIMESTAMP '2018-01-01'
  AND order_purchase_timestamp < TIMESTAMP '2018-02-01';

-- Размер частичного индекса.
SELECT 'idx_lab13_unfinished' AS index_name,
       pg_relation_size('olist.idx_lab13_unfinished') AS bytes,
       pg_size_pretty(pg_relation_size('olist.idx_lab13_unfinished')) AS size;

-- Фактические строки селективной выборки для сверки результата.
SELECT order_id, order_status, order_purchase_timestamp
FROM olist.orders
WHERE order_status = 'canceled'
  AND order_purchase_timestamp >= TIMESTAMP '2018-01-01'
  AND order_purchase_timestamp < TIMESTAMP '2018-02-01'
ORDER BY order_purchase_timestamp, order_id;

DROP INDEX IF EXISTS olist.idx_lab13_status_date;
DROP INDEX IF EXISTS olist.idx_lab13_unfinished;

-- Для отдельного повторения опыта создаются те же два индекса.
-- CREATE INDEX idx_lab13_status_date ON olist.orders (order_status, order_purchase_timestamp);
-- CREATE INDEX idx_lab13_unfinished ON olist.orders (order_status, order_purchase_timestamp) WHERE order_status <> 'delivered';

COMMIT;
