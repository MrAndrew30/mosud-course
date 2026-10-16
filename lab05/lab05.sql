-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9

-- Категории, которые встречались в доставленных заказах каждого штата,
-- через двойной NOT EXISTS.
WITH target_states(customer_state) AS (
    VALUES ('PB'::text), ('RN'::text), ('PE'::text)
),
category_states AS (
    SELECT DISTINCT p.product_category_name,
                    c.customer_state
    FROM olist.customers AS c
    JOIN olist.orders AS o ON o.customer_id = c.customer_id
    JOIN olist.order_items AS oi ON oi.order_id = o.order_id
    JOIN olist.products AS p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL
),
categories AS (
    SELECT DISTINCT product_category_name
    FROM category_states
)
SELECT c.product_category_name
FROM categories AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM target_states AS ts
    WHERE NOT EXISTS (
        SELECT 1
        FROM category_states AS cs
        WHERE cs.product_category_name = c.product_category_name
          AND cs.customer_state = ts.customer_state
    )
)
ORDER BY c.product_category_name;

-- То же условие через GROUP BY и HAVING.
WITH target_states(customer_state) AS (
    VALUES ('PB'::text), ('RN'::text), ('PE'::text)
),
category_states AS (
    SELECT DISTINCT p.product_category_name,
                    c.customer_state
    FROM olist.customers AS c
    JOIN olist.orders AS o ON o.customer_id = c.customer_id
    JOIN olist.order_items AS oi ON oi.order_id = o.order_id
    JOIN olist.products AS p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL
),
categories AS (
    SELECT DISTINCT product_category_name
    FROM category_states
)
SELECT c.product_category_name
FROM categories AS c
LEFT JOIN category_states AS cs
    ON cs.product_category_name = c.product_category_name
   AND cs.customer_state IN (
       SELECT customer_state
       FROM target_states
   )
GROUP BY c.product_category_name
HAVING count(DISTINCT cs.customer_state) = (
    SELECT count(*)
    FROM target_states
)
ORDER BY c.product_category_name;

-- То же условие через EXCEPT и NOT EXISTS.
WITH target_states(customer_state) AS (
    VALUES ('PB'::text), ('RN'::text), ('PE'::text)
),
category_states AS (
    SELECT DISTINCT p.product_category_name,
                    c.customer_state
    FROM olist.customers AS c
    JOIN olist.orders AS o ON o.customer_id = c.customer_id
    JOIN olist.order_items AS oi ON oi.order_id = o.order_id
    JOIN olist.products AS p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL
),
categories AS (
    SELECT DISTINCT product_category_name
    FROM category_states
)
SELECT c.product_category_name
FROM categories AS c
WHERE NOT EXISTS (
    SELECT customer_state
    FROM target_states
    EXCEPT
    SELECT cs.customer_state
    FROM category_states AS cs
    WHERE cs.product_category_name = c.product_category_name
)
ORDER BY c.product_category_name;

-- Проверка эквивалентности трёх результатов с помощью EXCEPT в обе стороны.
WITH target_states(customer_state) AS (
    VALUES ('PB'::text), ('RN'::text), ('PE'::text)
),
category_states AS (
    SELECT DISTINCT p.product_category_name,
                    c.customer_state
    FROM olist.customers AS c
    JOIN olist.orders AS o ON o.customer_id = c.customer_id
    JOIN olist.order_items AS oi ON oi.order_id = o.order_id
    JOIN olist.products AS p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL
),
categories AS (
    SELECT DISTINCT product_category_name
    FROM category_states
),
not_exists_result AS (
    SELECT c.product_category_name
    FROM categories AS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM target_states AS ts
        WHERE NOT EXISTS (
            SELECT 1
            FROM category_states AS cs
            WHERE cs.product_category_name = c.product_category_name
              AND cs.customer_state = ts.customer_state
        )
    )
),
group_result AS (
    SELECT c.product_category_name
    FROM categories AS c
    LEFT JOIN category_states AS cs
        ON cs.product_category_name = c.product_category_name
       AND cs.customer_state IN (
           SELECT customer_state
           FROM target_states
       )
    GROUP BY c.product_category_name
    HAVING count(DISTINCT cs.customer_state) = (
        SELECT count(*)
        FROM target_states
    )
),
except_result AS (
    SELECT c.product_category_name
    FROM categories AS c
    WHERE NOT EXISTS (
        SELECT customer_state
        FROM target_states
        EXCEPT
        SELECT cs.customer_state
        FROM category_states AS cs
        WHERE cs.product_category_name = c.product_category_name
    )
)
SELECT
    (SELECT count(*) FROM (
        SELECT product_category_name FROM not_exists_result
        EXCEPT
        SELECT product_category_name FROM group_result
    ) AS difference) AS not_exists_minus_group,
    (SELECT count(*) FROM (
        SELECT product_category_name FROM group_result
        EXCEPT
        SELECT product_category_name FROM not_exists_result
    ) AS difference) AS group_minus_not_exists,
    (SELECT count(*) FROM (
        SELECT product_category_name FROM not_exists_result
        EXCEPT
        SELECT product_category_name FROM except_result
    ) AS difference) AS not_exists_minus_except,
    (SELECT count(*) FROM (
        SELECT product_category_name FROM except_result
        EXCEPT
        SELECT product_category_name FROM not_exists_result
    ) AS difference) AS except_minus_not_exists;

-- Число доставленных заказов по каждому штату для первой найденной категории.
WITH target_states(customer_state) AS (
    VALUES ('PB'::text), ('RN'::text), ('PE'::text)
),
category_orders AS (
    SELECT DISTINCT p.product_category_name,
                    c.customer_state,
                    o.order_id
    FROM olist.customers AS c
    JOIN olist.orders AS o ON o.customer_id = c.customer_id
    JOIN olist.order_items AS oi ON oi.order_id = o.order_id
    JOIN olist.products AS p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL
),
categories AS (
    SELECT DISTINCT product_category_name
    FROM category_orders
),
matching_categories AS (
    SELECT c.product_category_name
    FROM categories AS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM target_states AS ts
        WHERE NOT EXISTS (
            SELECT 1
            FROM category_orders AS co
            WHERE co.product_category_name = c.product_category_name
              AND co.customer_state = ts.customer_state
        )
    )
),
selected_category AS (
    SELECT min(product_category_name) AS product_category_name
    FROM matching_categories
)
SELECT sc.product_category_name,
       ts.customer_state,
       count(co.order_id) AS order_count
FROM selected_category AS sc
CROSS JOIN target_states AS ts
LEFT JOIN category_orders AS co
    ON co.product_category_name = sc.product_category_name
   AND co.customer_state = ts.customer_state
GROUP BY sc.product_category_name, ts.customer_state
ORDER BY ts.customer_state;

-- При пустом target_states подходят все категории, потому что нет обязательного
-- штата, для которого нужно искать соответствие.
WITH target_states(customer_state) AS (
    SELECT NULL::text
    WHERE false
),
category_states AS (
    SELECT DISTINCT p.product_category_name,
                    c.customer_state
    FROM olist.customers AS c
    JOIN olist.orders AS o ON o.customer_id = c.customer_id
    JOIN olist.order_items AS oi ON oi.order_id = o.order_id
    JOIN olist.products AS p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL
),
categories AS (
    SELECT DISTINCT product_category_name
    FROM category_states
),
not_exists_result AS (
    SELECT c.product_category_name
    FROM categories AS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM target_states AS ts
        WHERE NOT EXISTS (
            SELECT 1
            FROM category_states AS cs
            WHERE cs.product_category_name = c.product_category_name
              AND cs.customer_state = ts.customer_state
        )
    )
),
group_result AS (
    SELECT c.product_category_name
    FROM categories AS c
    LEFT JOIN category_states AS cs
        ON cs.product_category_name = c.product_category_name
       AND cs.customer_state IN (
           SELECT customer_state
           FROM target_states
       )
    GROUP BY c.product_category_name
    HAVING count(DISTINCT cs.customer_state) = (
        SELECT count(*)
        FROM target_states
    )
),
except_result AS (
    SELECT c.product_category_name
    FROM categories AS c
    WHERE NOT EXISTS (
        SELECT customer_state
        FROM target_states
        EXCEPT
        SELECT cs.customer_state
        FROM category_states AS cs
        WHERE cs.product_category_name = c.product_category_name
    )
)
SELECT (SELECT count(*) FROM not_exists_result) AS not_exists_count,
       (SELECT count(*) FROM group_result) AS group_count,
       (SELECT count(*) FROM except_result) AS except_count;
