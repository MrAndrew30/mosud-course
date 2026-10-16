-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант 9

-- Кратности связей основного запроса:
-- один клиент может иметь несколько заказов (customers и orders, 1:N);
-- один заказ может содержать несколько позиций (orders и order_items, 1:N);
-- каждой позиции соответствует один товар (order_items и products, N:1);
-- клиент может покупать разные товары, а товар могут покупать разные клиенты
-- (customers и products, M:N через orders и order_items).

-- Основной запрос: стоимость доставки по категориям и штатам клиентов.
SELECT c.customer_state,
       COALESCE(p.product_category_name, 'без категории') AS product_category,
       count(*) AS item_count,
       count(DISTINCT o.order_id) AS order_count,
       round(sum(oi.freight_value), 2) AS total_freight_value,
       round(avg(oi.freight_value), 2) AS avg_freight_value
FROM olist.customers AS c
JOIN olist.orders AS o ON o.customer_id = c.customer_id
JOIN olist.order_items AS oi ON oi.order_id = o.order_id
JOIN olist.products AS p ON p.product_id = oi.product_id
GROUP BY c.customer_state, p.product_category_name
ORDER BY c.customer_state, product_category;

-- Композиция операций реляционной алгебры для основного запроса:
-- 1. Соединить customers с orders по customer_id.
-- 2. Соединить результат с order_items по order_id и с products по product_id.
-- 3. Сгруппировать строки по штату клиента и категории товара.
-- 4. Рассчитать количество позиций и заказов, сумму и среднюю стоимость доставки.
-- 5. Оставить в результате только рассчитанные столбцы.

-- LEFT JOIN сохраняет заказы, для которых нет отзыва.
-- Связь orders с order_reviews — 1:N; заказ может не иметь отзыва.
SELECT o.order_id,
       o.order_status,
       count(r.review_id) AS review_count
FROM olist.orders AS o
LEFT JOIN olist.order_reviews AS r ON r.order_id = o.order_id
GROUP BY o.order_id, o.order_status
ORDER BY review_count, o.order_id;

-- Антисоединение: заказы, для которых нет ни одного отзыва.
-- В антисоединении orders и order_reviews также имеют связь 1:N.
SELECT o.order_id,
       o.order_status
FROM olist.orders AS o
LEFT JOIN olist.order_reviews AS r ON r.order_id = o.order_id
WHERE r.order_id IS NULL
ORDER BY o.order_id;

-- Ошибочный запрос. В заказе может быть несколько позиций и несколько платежей.
-- При прямом соединении каждая позиция повторяется для каждого платежа,
-- поэтому количество строк и сумма доставки становятся больше правильных значений.
-- Позиции и платежи по order_id образуют M:N; итоговые строки correct_result и wrong_result соединяются 1:1.
WITH correct_result AS (
    SELECT count(*) AS item_rows,
           round(sum(freight_value), 2) AS total_freight_value
    FROM olist.order_items
),
wrong_result AS (
    SELECT count(*) AS joined_rows,
           round(sum(oi.freight_value), 2) AS total_freight_value
    FROM olist.order_items AS oi
    JOIN olist.order_payments AS op ON op.order_id = oi.order_id
)
SELECT c.item_rows,
       w.joined_rows,
       c.total_freight_value AS correct_freight_value,
       w.total_freight_value AS wrong_freight_value,
       w.total_freight_value - c.total_freight_value AS overstatement
FROM correct_result AS c
CROSS JOIN wrong_result AS w;

-- Исправленный запрос. Сначала получаем по одной строке на заказ для позиций
-- и платежей, а затем соединяем полученные результаты.
-- После агрегации связь items_by_order с payments_by_order — 1:0..1 по order_id.
WITH items_by_order AS (
    SELECT order_id,
           count(*) AS item_count,
           sum(freight_value) AS freight_value
    FROM olist.order_items
    GROUP BY order_id
),
payments_by_order AS (
    SELECT order_id,
           count(*) AS payment_count,
           sum(payment_value) AS payment_value
    FROM olist.order_payments
    GROUP BY order_id
)
SELECT count(*) AS order_count,
       sum(i.item_count) AS item_count,
       sum(p.payment_count) AS payment_count,
       round(sum(i.freight_value), 2) AS total_freight_value,
       round(sum(p.payment_value), 2) AS total_payment_value
FROM items_by_order AS i
LEFT JOIN payments_by_order AS p ON p.order_id = i.order_id;
