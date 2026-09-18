-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9

-- Исходная SQL-реализация.
SELECT order_id,
       order_delivered_customer_date AS delivered_date,
       order_estimated_delivery_date AS estimated_date
FROM olist.orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_delivered_customer_date > order_estimated_delivery_date
ORDER BY order_id;

-- Эквивалентный вариант с двумя последовательными выборками.
WITH orders_with_dates AS (
    SELECT *
    FROM olist.orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT order_id,
       order_delivered_customer_date AS delivered_date,
       order_estimated_delivery_date AS estimated_date
FROM orders_with_dates
WHERE order_delivered_customer_date > order_estimated_delivery_date
ORDER BY order_id;

-- Вариант с ранним исключением ненужных столбцов.
WITH projected_orders AS (
    SELECT order_id,
           order_delivered_customer_date,
           order_estimated_delivery_date
    FROM olist.orders
),
late_orders AS (
    SELECT *
    FROM projected_orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date > order_estimated_delivery_date
)
SELECT order_id,
       order_delivered_customer_date AS delivered_date,
       order_estimated_delivery_date AS estimated_date
FROM late_orders
ORDER BY order_id;

-- Проверка эквивалентности трёх вариантов.
WITH original_result AS (
    SELECT order_id,
           order_delivered_customer_date AS delivered_date,
           order_estimated_delivery_date AS estimated_date
    FROM olist.orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date > order_estimated_delivery_date
),
orders_with_dates AS (
    SELECT *
    FROM olist.orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
),
split_result AS (
    SELECT order_id,
           order_delivered_customer_date AS delivered_date,
           order_estimated_delivery_date AS estimated_date
    FROM orders_with_dates
    WHERE order_delivered_customer_date > order_estimated_delivery_date
),
projected_orders AS (
    SELECT order_id,
           order_delivered_customer_date,
           order_estimated_delivery_date
    FROM olist.orders
),
early_projection_result AS (
    SELECT order_id,
           order_delivered_customer_date AS delivered_date,
           order_estimated_delivery_date AS estimated_date
    FROM projected_orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date > order_estimated_delivery_date
)
SELECT
    (SELECT count(*)
     FROM (
         (SELECT * FROM original_result
          EXCEPT
          SELECT * FROM split_result)
         UNION ALL
         (SELECT * FROM split_result
          EXCEPT
          SELECT * FROM original_result)
     ) AS differences) AS original_split_difference,
    (SELECT count(*)
     FROM (
         (SELECT * FROM original_result
          EXCEPT
          SELECT * FROM early_projection_result)
         UNION ALL
         (SELECT * FROM early_projection_result
          EXCEPT
          SELECT * FROM original_result)
     ) AS differences) AS original_early_projection_difference;

-- Проверка дубликатов в проекции.
WITH result AS (
    SELECT order_id,
           order_delivered_customer_date AS delivered_date,
           order_estimated_delivery_date AS estimated_date
    FROM olist.orders
    WHERE order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date > order_estimated_delivery_date
)
SELECT
    (SELECT count(*) FROM result) AS select_count,
    (SELECT count(*) FROM (SELECT DISTINCT * FROM result) AS distinct_result)
        AS select_distinct_count,
    (SELECT count(*) FROM result)
        - (SELECT count(*) FROM (SELECT DISTINCT * FROM result) AS distinct_result)
        AS duplicate_count;
