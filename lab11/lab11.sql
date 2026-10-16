-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9

BEGIN;

-- Одна строка на заказ с числом позиций и полной стоимостью.
CREATE VIEW lab.v_order_summary AS
WITH item_totals AS (
    SELECT order_id, count(*) AS item_count, sum(price + freight_value) AS order_total
    FROM olist.order_items
    GROUP BY order_id
)
SELECT o.order_id, o.order_purchase_timestamp, c.customer_state,
       coalesce(i.item_count, 0) AS item_count,
       coalesce(i.order_total, 0::numeric) AS order_total
FROM olist.orders o
JOIN olist.customers c ON c.customer_id = o.customer_id
LEFT JOIN item_totals i ON i.order_id = o.order_id;

-- Месячные итоги продаж по штатам.
CREATE MATERIALIZED VIEW lab.mv_monthly_state_sales AS
SELECT date_trunc('month', order_purchase_timestamp)::date AS month,
       customer_state, count(*) AS order_count, sum(order_total) AS sales
FROM lab.v_order_summary
GROUP BY date_trunc('month', order_purchase_timestamp)::date, customer_state;

-- Обновление сохранённых месячных итогов.
REFRESH MATERIALIZED VIEW lab.mv_monthly_state_sales;

-- Проверка уникальности заказов и итоговых сумм.
SELECT count(*) AS orders, count(DISTINCT order_id) AS unique_orders,
       sum(item_count) AS items, sum(order_total) AS total
FROM lab.v_order_summary;

-- Рост месячных продаж и место CE среди штатов.
WITH monthly AS (
    SELECT month, customer_state, order_count, sales
    FROM lab.mv_monthly_state_sales
), with_previous AS (
    SELECT *, lag(sales) OVER (PARTITION BY customer_state ORDER BY month) AS previous_sales
    FROM monthly
), growth AS (
    SELECT *, round(100 * (sales - previous_sales) / nullif(previous_sales, 0), 2) AS growth_pct
    FROM with_previous
), ranked AS (
    SELECT *, row_number() OVER (PARTITION BY month ORDER BY sales DESC, customer_state) AS sales_rank
    FROM growth
)
SELECT month, customer_state, order_count, sales, previous_sales, growth_pct, sales_rank
FROM ranked
WHERE customer_state = 'CE'
ORDER BY month;

-- Иерархия страны, штатов и городов.
CREATE TABLE lab.geo_tree (
    node_id text CONSTRAINT pk_geo_tree PRIMARY KEY,
    parent_id text CONSTRAINT fk_geo_tree_parent REFERENCES lab.geo_tree(node_id),
    node_type text NOT NULL CONSTRAINT ck_geo_tree_type CHECK (node_type IN ('country', 'state', 'city')),
    node_name text NOT NULL
);

-- Корневой узел страны.
INSERT INTO lab.geo_tree VALUES ('BR', NULL, 'country', 'Brazil');

-- Узлы реальных штатов покупателей.
INSERT INTO lab.geo_tree
SELECT 'ST:' || customer_state, 'BR', 'state', customer_state
FROM olist.customers
GROUP BY customer_state;

-- До двадцати крупнейших городов каждого штата по числу клиентов.
WITH city_counts AS (
    SELECT customer_state, customer_city, count(*) AS customers
    FROM olist.customers
    GROUP BY customer_state, customer_city
), ranked AS (
    SELECT *, row_number() OVER (
        PARTITION BY customer_state ORDER BY customers DESC, customer_city
    ) AS city_rank
    FROM city_counts
)
INSERT INTO lab.geo_tree
SELECT 'CT:' || customer_state || ':' || customer_city,
       'ST:' || customer_state, 'city', customer_city
FROM ranked
WHERE city_rank <= 20;

-- Все узлы поддерева CE с глубиной и путём.
WITH RECURSIVE subtree AS (
    SELECT 0 AS depth, node_id, parent_id, ARRAY[node_id] AS path, node_name
    FROM lab.geo_tree
    WHERE node_id = 'ST:CE'
    UNION ALL
    SELECT p.depth + 1, c.node_id, c.parent_id, p.path || c.node_id, c.node_name
    FROM lab.geo_tree c
    JOIN subtree p ON c.parent_id = p.node_id
    WHERE NOT c.node_id = ANY(p.path)
)
SELECT depth, node_id, path, node_name FROM subtree ORDER BY path;

-- Предки города fortaleza до страны BR.
WITH RECURSIVE ancestors AS (
    SELECT 0 AS depth, node_id, parent_id, ARRAY[node_id] AS path, node_name
    FROM lab.geo_tree
    WHERE node_id = 'CT:CE:fortaleza'
    UNION ALL
    SELECT c.depth + 1, p.node_id, p.parent_id, c.path || p.node_id, p.node_name
    FROM lab.geo_tree p
    JOIN ancestors c ON c.parent_id = p.node_id
    WHERE NOT p.node_id = ANY(c.path)
)
SELECT depth, node_id, path, node_name FROM ancestors ORDER BY depth;

-- Число потомков каждого штата без самого корня.
WITH RECURSIVE descendants AS (
    SELECT node_id AS state_id, node_id, ARRAY[node_id] AS path, 0 AS depth
    FROM lab.geo_tree WHERE node_type = 'state'
    UNION ALL
    SELECT d.state_id, c.node_id, d.path || c.node_id, d.depth + 1
    FROM descendants d JOIN lab.geo_tree c ON c.parent_id = d.node_id
    WHERE NOT c.node_id = ANY(d.path)
)
SELECT state_id, count(*) FILTER (WHERE depth > 0) AS descendant_count
FROM descendants GROUP BY state_id ORDER BY state_id;

-- Число узлов каждого уровня иерархии.
SELECT node_type, count(*) AS nodes FROM lab.geo_tree GROUP BY node_type ORDER BY node_type;

COMMIT;
