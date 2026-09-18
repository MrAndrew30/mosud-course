-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9: штат X = PA, штат Y = AM

-- Практическая работа № 2. Множества и мультимножества в SQL.
-- Учитываются только позиции заказов со статусом delivered.

-- Исходные выборки сохраняют повторения и поэтому являются мультимножествами.
CREATE TEMP VIEW lab02_a_rows AS
SELECT oi.product_id
FROM olist.customers AS c
JOIN olist.orders AS o ON o.customer_id = c.customer_id
JOIN olist.order_items AS oi ON oi.order_id = o.order_id
WHERE c.customer_state = 'PA'
  AND o.order_status = 'delivered';

CREATE TEMP VIEW lab02_b_rows AS
SELECT oi.product_id
FROM olist.customers AS c
JOIN olist.orders AS o ON o.customer_id = c.customer_id
JOIN olist.order_items AS oi ON oi.order_id = o.order_id
WHERE c.customer_state = 'AM'
  AND o.order_status = 'delivered';

-- Математические множества A и B не содержат повторяющихся product_id.
CREATE TEMP VIEW lab02_a AS
SELECT DISTINCT product_id
FROM lab02_a_rows;

CREATE TEMP VIEW lab02_b AS
SELECT DISTINCT product_id
FROM lab02_b_rows;

-- 1. Количество строк и различных товаров в исходных выборках A и B.
-- Результат: PA — 1054 строки и 864 товара; AM — 163 строки и 145 товаров.
SELECT 'A (PA)' AS set_name,
       count(*) AS row_count,
       count(DISTINCT product_id) AS distinct_product_count
FROM lab02_a_rows
UNION ALL
SELECT 'B (AM)',
       count(*),
       count(DISTINCT product_id)
FROM lab02_b_rows
ORDER BY set_name;

-- 2. Объединение A ∪ B с удалением дубликатов: 986 строк.
SELECT product_id
FROM lab02_a
UNION
SELECT product_id
FROM lab02_b
ORDER BY product_id;

-- UNION ALL не устраняет 23 товара, встречающихся в обоих множествах,
-- поэтому возвращает 864 + 145 = 1009 строк.
SELECT product_id
FROM lab02_a
UNION ALL
SELECT product_id
FROM lab02_b
ORDER BY product_id;

-- Сравнение мощностей UNION и UNION ALL.
SELECT
    (SELECT count(*)
     FROM (
         SELECT product_id FROM lab02_a
         UNION
         SELECT product_id FROM lab02_b
     ) AS union_set) AS union_count,
    (SELECT count(*)
     FROM (
         SELECT product_id FROM lab02_a
         UNION ALL
         SELECT product_id FROM lab02_b
     ) AS union_bag) AS union_all_count;

-- 3. Пересечение A ∩ B: 23 товара.
SELECT product_id
FROM lab02_a
INTERSECT
SELECT product_id
FROM lab02_b
ORDER BY product_id;

-- 4. Разность A − B: 841 товар.
SELECT product_id
FROM lab02_a
EXCEPT
SELECT product_id
FROM lab02_b
ORDER BY product_id;

-- Разность B − A: 122 товара.
SELECT product_id
FROM lab02_b
EXCEPT
SELECT product_id
FROM lab02_a
ORDER BY product_id;

-- 5. Коммутативность объединения: симметрическая разность
-- результатов A ∪ B и B ∪ A пуста.
WITH ab AS (
    SELECT product_id FROM lab02_a
    UNION
    SELECT product_id FROM lab02_b
),
ba AS (
    SELECT product_id FROM lab02_b
    UNION
    SELECT product_id FROM lab02_a
),
differences AS (
    (SELECT product_id FROM ab EXCEPT SELECT product_id FROM ba)
    UNION ALL
    (SELECT product_id FROM ba EXCEPT SELECT product_id FROM ab)
)
SELECT count(*) AS union_symmetric_difference
FROM differences;

-- Коммутативность пересечения: симметрическая разность
-- результатов A ∩ B и B ∩ A также пуста.
WITH ab AS (
    SELECT product_id FROM lab02_a
    INTERSECT
    SELECT product_id FROM lab02_b
),
ba AS (
    SELECT product_id FROM lab02_b
    INTERSECT
    SELECT product_id FROM lab02_a
),
differences AS (
    (SELECT product_id FROM ab EXCEPT SELECT product_id FROM ba)
    UNION ALL
    (SELECT product_id FROM ba EXCEPT SELECT product_id FROM ab)
)
SELECT count(*) AS intersection_symmetric_difference
FROM differences;

-- 6. Разность некоммутативна: A − B и B − A имеют разные мощности,
-- а их симметрическая разность содержит 963 товара.
SELECT
    (SELECT count(*)
     FROM (
         SELECT product_id FROM lab02_a
         EXCEPT
         SELECT product_id FROM lab02_b
     ) AS a_minus_b) AS a_minus_b_count,
    (SELECT count(*)
     FROM (
         SELECT product_id FROM lab02_b
         EXCEPT
         SELECT product_id FROM lab02_a
     ) AS b_minus_a) AS b_minus_a_count,
    (SELECT count(*)
     FROM (
         (SELECT product_id FROM lab02_a
          EXCEPT
          SELECT product_id FROM lab02_b)
         UNION ALL
         (SELECT product_id FROM lab02_b
          EXCEPT
          SELECT product_id FROM lab02_a)
     ) AS differences) AS difference_symmetric_difference;

-- 7. Пересечение без INTERSECT с помощью EXISTS: те же 23 товара.
SELECT a.product_id
FROM lab02_a AS a
WHERE EXISTS (
    SELECT 1
    FROM lab02_b AS b
    WHERE b.product_id = a.product_id
)
ORDER BY a.product_id;

-- Проверка эквивалентности INTERSECT и EXISTS:
-- симметрическая разность результатов пуста.
WITH intersect_result AS (
    SELECT product_id FROM lab02_a
    INTERSECT
    SELECT product_id FROM lab02_b
),
exists_result AS (
    SELECT a.product_id
    FROM lab02_a AS a
    WHERE EXISTS (
        SELECT 1
        FROM lab02_b AS b
        WHERE b.product_id = a.product_id
    )
),
differences AS (
    (SELECT product_id FROM intersect_result
     EXCEPT
     SELECT product_id FROM exists_result)
    UNION ALL
    (SELECT product_id FROM exists_result
     EXCEPT
     SELECT product_id FROM intersect_result)
)
SELECT count(*) AS intersect_exists_symmetric_difference
FROM differences;

-- 8. Намеренно используем исходные выборки без DISTINCT и UNION ALL.
-- Получается мультимножество: 1217 строк, 986 различных товаров
-- и 231 повторная строка сверх одного экземпляра каждого товара.
WITH bag_result AS (
    SELECT product_id FROM lab02_a_rows
    UNION ALL
    SELECT product_id FROM lab02_b_rows
)
SELECT count(*) AS row_count,
       count(DISTINCT product_id) AS distinct_product_count,
       count(*) - count(DISTINCT product_id) AS duplicate_row_count
FROM bag_result;

-- Примеры товаров, которые повторяются в полученном мультимножестве.
WITH bag_result AS (
    SELECT product_id FROM lab02_a_rows
    UNION ALL
    SELECT product_id FROM lab02_b_rows
)
SELECT product_id, count(*) AS occurrences
FROM bag_result
GROUP BY product_id
HAVING count(*) > 1
ORDER BY occurrences DESC, product_id
LIMIT 10;

-- Итоговые мощности математических множеств.
SELECT
    (SELECT count(*) FROM lab02_a) AS a_count,
    (SELECT count(*) FROM lab02_b) AS b_count,
    (SELECT count(*) FROM (
        SELECT product_id FROM lab02_a
        UNION
        SELECT product_id FROM lab02_b
    ) AS union_result) AS union_count,
    (SELECT count(*) FROM (
        SELECT product_id FROM lab02_a
        INTERSECT
        SELECT product_id FROM lab02_b
    ) AS intersection_result) AS intersection_count,
    (SELECT count(*) FROM (
        SELECT product_id FROM lab02_a
        EXCEPT
        SELECT product_id FROM lab02_b
    ) AS a_minus_b_result) AS a_minus_b_count,
    (SELECT count(*) FROM (
        SELECT product_id FROM lab02_b
        EXCEPT
        SELECT product_id FROM lab02_a
    ) AS b_minus_a_result) AS b_minus_a_count;

-- 9. UNION, INTERSECT и EXCEPT без ALL возвращают множество: они
-- устраняют повторяющиеся строки. SELECT и варианты операций с ALL
-- могут вернуть мультимножество, если источник содержит дубликаты.

