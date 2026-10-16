-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант не предусмотрен

-- Количество NULL в необязательных полях заказов.
SELECT 'orders' AS table_name,
       'order_status' AS column_name,
       count(*) FILTER (WHERE order_status IS NULL) AS null_count
FROM olist.orders
UNION ALL
SELECT 'orders', 'order_purchase_timestamp',
       count(*) FILTER (WHERE order_purchase_timestamp IS NULL)
FROM olist.orders
UNION ALL
SELECT 'orders', 'order_approved_at',
       count(*) FILTER (WHERE order_approved_at IS NULL)
FROM olist.orders
UNION ALL
SELECT 'orders', 'order_delivered_carrier_date',
       count(*) FILTER (WHERE order_delivered_carrier_date IS NULL)
FROM olist.orders
UNION ALL
SELECT 'orders', 'order_delivered_customer_date',
       count(*) FILTER (WHERE order_delivered_customer_date IS NULL)
FROM olist.orders
UNION ALL
SELECT 'orders', 'order_estimated_delivery_date',
       count(*) FILTER (WHERE order_estimated_delivery_date IS NULL)
FROM olist.orders
ORDER BY column_name;

-- Количество NULL в необязательных полях товаров.
SELECT 'products' AS table_name,
       'product_category_name' AS column_name,
       count(*) FILTER (WHERE product_category_name IS NULL) AS null_count
FROM olist.products
UNION ALL
SELECT 'products', 'product_name_lenght',
       count(*) FILTER (WHERE product_name_lenght IS NULL)
FROM olist.products
UNION ALL
SELECT 'products', 'product_description_lenght',
       count(*) FILTER (WHERE product_description_lenght IS NULL)
FROM olist.products
UNION ALL
SELECT 'products', 'product_photos_qty',
       count(*) FILTER (WHERE product_photos_qty IS NULL)
FROM olist.products
UNION ALL
SELECT 'products', 'product_weight_g',
       count(*) FILTER (WHERE product_weight_g IS NULL)
FROM olist.products
UNION ALL
SELECT 'products', 'product_length_cm',
       count(*) FILTER (WHERE product_length_cm IS NULL)
FROM olist.products
UNION ALL
SELECT 'products', 'product_height_cm',
       count(*) FILTER (WHERE product_height_cm IS NULL)
FROM olist.products
UNION ALL
SELECT 'products', 'product_width_cm',
       count(*) FILTER (WHERE product_width_cm IS NULL)
FROM olist.products
ORDER BY column_name;

-- Количество NULL в необязательных полях отзывов.
SELECT 'order_reviews' AS table_name,
       'review_score' AS column_name,
       count(*) FILTER (WHERE review_score IS NULL) AS null_count
FROM olist.order_reviews
UNION ALL
SELECT 'order_reviews', 'review_comment_title',
       count(*) FILTER (WHERE review_comment_title IS NULL)
FROM olist.order_reviews
UNION ALL
SELECT 'order_reviews', 'review_comment_message',
       count(*) FILTER (WHERE review_comment_message IS NULL)
FROM olist.order_reviews
UNION ALL
SELECT 'order_reviews', 'review_creation_date',
       count(*) FILTER (WHERE review_creation_date IS NULL)
FROM olist.order_reviews
UNION ALL
SELECT 'order_reviews', 'review_answer_timestamp',
       count(*) FILTER (WHERE review_answer_timestamp IS NULL)
FROM olist.order_reviews
ORDER BY column_name;

-- COUNT(*) учитывает все заказы, а COUNT по полю пропускает строки с NULL.
SELECT count(*) AS all_orders,
       count(order_delivered_customer_date) AS orders_with_delivery_date,
       count(*) - count(order_delivered_customer_date) AS orders_without_delivery_date
FROM olist.orders;

-- Сравнение с NULL даёт UNKNOWN, поэтому условия с = и <> не отбирают строки.
SELECT
    (SELECT count(*)
     FROM olist.orders
     WHERE order_delivered_customer_date = NULL) AS equal_null,
    (SELECT count(*)
     FROM olist.orders
     WHERE order_delivered_customer_date <> NULL) AS not_equal_null,
    (SELECT count(*)
     FROM olist.orders
     WHERE order_delivered_customer_date IS NULL) AS is_null,
    (SELECT count(*)
     FROM olist.orders
     WHERE order_delivered_customer_date IS NOT NULL) AS is_not_null;

-- IS DISTINCT FROM корректно сравнивает значения, даже если одно из них NULL.
SELECT NULL::text AS first_value,
       'delivered'::text AS second_value,
       NULL::text IS DISTINCT FROM 'delivered'::text AS values_are_distinct;

-- Таблица содержит существующий идентификатор заказа и NULL.
CREATE TEMP TABLE temp_ids (
    id text
);

INSERT INTO temp_ids (id)
SELECT order_id::text
FROM olist.orders
ORDER BY order_id
LIMIT 1;

INSERT INTO temp_ids (id)
VALUES (NULL);

-- NULL в подзапросе делает NOT IN неизвестным, а NOT EXISTS работает ожидаемо.
SELECT
    (SELECT count(*)
     FROM olist.orders AS o
     WHERE o.order_id::text NOT IN (
         SELECT id
         FROM temp_ids
     )) AS not_in_count,
    (SELECT count(*)
     FROM olist.orders AS o
     WHERE NOT EXISTS (
         SELECT 1
         FROM temp_ids AS t
         WHERE t.id = o.order_id::text
     )) AS not_exists_count;

-- Условие в ON сохраняет все заказы, даже если подходящего отзыва нет.
SELECT count(DISTINCT o.order_id) AS order_count
FROM olist.orders AS o
LEFT JOIN olist.order_reviews AS r
    ON r.order_id = o.order_id
   AND r.review_score >= 4;

-- Условие в WHERE оставляет только заказы с отзывом не ниже четырёх.
SELECT count(DISTINCT o.order_id) AS order_count
FROM olist.orders AS o
LEFT JOIN olist.order_reviews AS r ON r.order_id = o.order_id
WHERE r.review_score >= 4;

-- COALESCE заменяет отсутствующий текст отзыва понятной подписью.
SELECT review_id,
       order_id,
       coalesce(review_comment_message, 'Комментарий отсутствует') AS review_text
FROM olist.order_reviews
ORDER BY review_id
LIMIT 10;

-- NULLIF защищает деление от нулевой суммы числа платежей.
SELECT round(
           sum(payment_value) / NULLIF(sum(payment_installments), 0),
           2
       ) AS average_value_per_installment
FROM olist.order_payments;

-- Профиль показывает число и долю записей с пропущенными данными.
SELECT 'orders without actual delivery date' AS quality_check,
       count(*) AS total_count,
       count(*) FILTER (
           WHERE order_delivered_customer_date IS NULL
       ) AS missing_count,
       round(
           100.0 * count(*) FILTER (
               WHERE order_delivered_customer_date IS NULL
           ) / NULLIF(count(*), 0),
           2
       ) AS missing_percent
FROM olist.orders
UNION ALL
SELECT 'products without category',
       count(*),
       count(*) FILTER (WHERE product_category_name IS NULL),
       round(
           100.0 * count(*) FILTER (
               WHERE product_category_name IS NULL
           ) / NULLIF(count(*), 0),
           2
       )
FROM olist.products
UNION ALL
SELECT 'reviews without text',
       count(*),
       count(*) FILTER (
           WHERE NULLIF(btrim(review_comment_message), '') IS NULL
       ),
       round(
           100.0 * count(*) FILTER (
               WHERE NULLIF(btrim(review_comment_message), '') IS NULL
           ) / NULLIF(count(*), 0),
           2
       )
FROM olist.order_reviews;

-- NULL в order_delivered_customer_date естественен для отменённых и ещё не
-- доставленных заказов. NULL в product_category_name означает, что товар не
-- классифицирован, и указывает на проблему качества данных.
