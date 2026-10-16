-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9

-- Штаты со средней фактической длительностью доставки выше общей средней.
-- Коррелированные подзапросы рассчитывают показатели для текущего штата.
SELECT s.customer_state,
       (
           SELECT count(*)
           FROM olist.customers AS c
           JOIN olist.orders AS o ON o.customer_id = c.customer_id
           WHERE c.customer_state = s.customer_state
             AND o.order_status = 'delivered'
             AND o.order_purchase_timestamp IS NOT NULL
             AND o.order_delivered_customer_date IS NOT NULL
       ) AS delivery_count,
       (
           SELECT avg(o.order_delivered_customer_date
                      - o.order_purchase_timestamp)
           FROM olist.customers AS c
           JOIN olist.orders AS o ON o.customer_id = c.customer_id
           WHERE c.customer_state = s.customer_state
             AND o.order_status = 'delivered'
             AND o.order_purchase_timestamp IS NOT NULL
             AND o.order_delivered_customer_date IS NOT NULL
       ) AS avg_delivery_time
FROM (
    SELECT DISTINCT customer_state
    FROM olist.customers
) AS s
WHERE EXISTS (
    SELECT 1
    FROM olist.customers AS c
    JOIN olist.orders AS o ON o.customer_id = c.customer_id
    WHERE c.customer_state = s.customer_state
      AND o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
)
  AND (
      SELECT avg(o.order_delivered_customer_date
                 - o.order_purchase_timestamp)
      FROM olist.customers AS c
      JOIN olist.orders AS o ON o.customer_id = c.customer_id
      WHERE c.customer_state = s.customer_state
        AND o.order_status = 'delivered'
        AND o.order_purchase_timestamp IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
  ) > (
      SELECT avg(o.order_delivered_customer_date
                 - o.order_purchase_timestamp)
      FROM olist.orders AS o
      WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
  )
ORDER BY s.customer_state;

-- То же условие через предварительную агрегацию в CTE.
WITH deliveries AS (
    SELECT c.customer_state,
           o.order_delivered_customer_date
               - o.order_purchase_timestamp AS delivery_time
    FROM olist.customers AS c
    JOIN olist.orders AS o ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
),
state_stats AS (
    SELECT customer_state,
           count(*) AS delivery_count,
           avg(delivery_time) AS avg_delivery_time
    FROM deliveries
    GROUP BY customer_state
),
overall_stats AS (
    SELECT avg(delivery_time) AS avg_delivery_time
    FROM deliveries
)
SELECT ss.customer_state,
       ss.delivery_count,
       ss.avg_delivery_time
FROM state_stats AS ss
CROSS JOIN overall_stats AS os
WHERE ss.avg_delivery_time > os.avg_delivery_time
ORDER BY ss.customer_state;

-- EXCEPT сравнивает в обе стороны штат, число доставок и среднюю длительность.
WITH deliveries AS (
    SELECT c.customer_state,
           o.order_delivered_customer_date
               - o.order_purchase_timestamp AS delivery_time
    FROM olist.customers AS c
    JOIN olist.orders AS o ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
),
states AS (
    SELECT DISTINCT customer_state
    FROM olist.customers
),
main_result AS (
    SELECT s.customer_state,
           (SELECT count(*) FROM deliveries d
            WHERE d.customer_state = s.customer_state) AS delivery_count,
           (SELECT avg(d.delivery_time) FROM deliveries d
            WHERE d.customer_state = s.customer_state) AS avg_delivery_time
    FROM states AS s
    WHERE EXISTS (
        SELECT 1
        FROM deliveries AS d
        WHERE d.customer_state = s.customer_state
    )
      AND (
          SELECT avg(d.delivery_time)
          FROM deliveries AS d
          WHERE d.customer_state = s.customer_state
      ) > (
          SELECT avg(d.delivery_time)
          FROM deliveries AS d
      )
),
state_stats AS (
    SELECT customer_state,
           count(*) AS delivery_count,
           avg(delivery_time) AS avg_delivery_time
    FROM deliveries
    GROUP BY customer_state
),
overall_stats AS (
    SELECT avg(delivery_time) AS avg_delivery_time
    FROM deliveries
),
alternative_result AS (
    SELECT ss.customer_state, ss.delivery_count, ss.avg_delivery_time
    FROM state_stats AS ss
    CROSS JOIN overall_stats AS os
    WHERE ss.avg_delivery_time > os.avg_delivery_time
)
SELECT
    (
        SELECT count(*)
        FROM (
            SELECT * FROM main_result
            EXCEPT
            SELECT * FROM alternative_result
        ) AS difference
    ) AS main_minus_alternative,
    (
        SELECT count(*)
        FROM (
            SELECT * FROM alternative_result
            EXCEPT
            SELECT * FROM main_result
        ) AS difference
    ) AS alternative_minus_main;

-- ALL сравнивает длительность каждой доставки с общей средней.
WITH deliveries AS (
    SELECT o.order_delivered_customer_date
               - o.order_purchase_timestamp AS delivery_time
    FROM olist.orders AS o
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT count(*) AS deliveries_above_overall_average
FROM deliveries AS d
WHERE d.delivery_time > ALL (
    SELECT avg(delivery_time)
    FROM deliveries
);
