-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9

BEGIN;
SET LOCAL max_parallel_workers_per_gather = 0;
DROP INDEX IF EXISTS olist.idx_lab14_price;
ANALYZE olist.order_items;

-- Исходный запрос преобразует цену в текст для каждой строки.
\echo ORIGINAL_BEFORE_INDEX
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT order_id, order_item_id, product_id, price
FROM olist.order_items
WHERE price::text = '100.00';

-- Числовой B-tree для поиска по исходному столбцу price.
CREATE INDEX idx_lab14_price ON olist.order_items (price);
ANALYZE olist.order_items;

-- Проверка: создание индекса само по себе не устраняет приведение к text.
\echo ORIGINAL_WITH_INDEX
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT order_id, order_item_id, product_id, price
FROM olist.order_items
WHERE price::text = '100.00';

-- Типизированное условие позволяет применить индексный доступ.
\echo OPTIMIZED_WITH_INDEX
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT order_id, order_item_id, product_id, price
FROM olist.order_items
WHERE price = NUMERIC '100.00';

-- Доказательство равенства всех столбцов результата через EXCEPT в обе стороны.
WITH original AS (
    SELECT order_id, order_item_id, product_id, price
    FROM olist.order_items WHERE price::text = '100.00'
), optimized AS (
    SELECT order_id, order_item_id, product_id, price
    FROM olist.order_items WHERE price = NUMERIC '100.00'
)
SELECT 'original_minus_optimized' AS direction, count(*) AS differences
FROM (SELECT * FROM original EXCEPT SELECT * FROM optimized) a
UNION ALL
SELECT 'optimized_minus_original', count(*)
FROM (SELECT * FROM optimized EXCEPT SELECT * FROM original) b;

-- Количество найденных позиций с ценой 100,00.
SELECT count(*) AS result_rows FROM olist.order_items WHERE price = NUMERIC '100.00';

-- Анализ плана для варианта 9, PostgreSQL 17.5, Olist.
-- Исходный дорогой узел — Seq Scan: проверено 112650 строк, отброшено 112478.
-- Исходный план: estimated rows = 563, actual rows = 172.
-- Новый план: estimated rows = 17, actual rows = 172.
-- Зафиксированный запуск: исходный запрос 8.048 мс, новый 0.077 мс.
-- Shared hit/read: 2320/0 до, 135/3 после.
-- Новый Bitmap Scan получает из индекса 172 ссылки вместо фильтрации всей таблицы.
-- В обе стороны EXCEPT получено 0 различий; PK (order_id, order_item_id) исключает дубликаты.
-- При numeric(10,2) текст '100.00' соответствует ровно числовому 100.00; NULL исключается обоими условиями.
-- Использовано эквивалентное преобразование выборки к условию над исходным атрибутом.
-- Проекция и выбранные строки сохранены, фильтрация выполняется при индексном доступе.
-- Ускорение связано с устранением преобразований и сокращением буферных обращений.
-- Оценка числа строк остаётся неточной; время зависит от состояния кэша и может меняться.

DROP INDEX IF EXISTS olist.idx_lab14_price;
COMMIT;
