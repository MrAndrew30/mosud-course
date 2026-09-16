-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант не предусмотрен

-- Проверка количества строк во всех девяти таблицах.
SELECT 'customers' AS table_name, count(*) AS row_count FROM olist.customers
UNION ALL SELECT 'geolocation', count(*) FROM olist.geolocation
UNION ALL SELECT 'orders', count(*) FROM olist.orders
UNION ALL SELECT 'order_items', count(*) FROM olist.order_items
UNION ALL SELECT 'order_payments', count(*) FROM olist.order_payments
UNION ALL SELECT 'order_reviews', count(*) FROM olist.order_reviews
UNION ALL SELECT 'products', count(*) FROM olist.products
UNION ALL SELECT 'sellers', count(*) FROM olist.sellers
UNION ALL SELECT 'product_category_name_translation', count(*)
FROM olist.product_category_name_translation;

-- Проверка NULL во всех полях первичных и внешних ключей.
SELECT 'customers.customer_id' AS field_name, count(*) AS null_count
FROM olist.customers WHERE customer_id IS NULL
UNION ALL SELECT 'orders.order_id', count(*)
FROM olist.orders WHERE order_id IS NULL
UNION ALL SELECT 'orders.customer_id', count(*)
FROM olist.orders WHERE customer_id IS NULL
UNION ALL SELECT 'order_items.order_id', count(*)
FROM olist.order_items WHERE order_id IS NULL
UNION ALL SELECT 'order_items.order_item_id', count(*)
FROM olist.order_items WHERE order_item_id IS NULL
UNION ALL SELECT 'order_items.product_id', count(*)
FROM olist.order_items WHERE product_id IS NULL
UNION ALL SELECT 'order_items.seller_id', count(*)
FROM olist.order_items WHERE seller_id IS NULL
UNION ALL SELECT 'order_payments.order_id', count(*)
FROM olist.order_payments WHERE order_id IS NULL
UNION ALL SELECT 'order_payments.payment_sequential', count(*)
FROM olist.order_payments WHERE payment_sequential IS NULL
UNION ALL SELECT 'order_reviews.review_id', count(*)
FROM olist.order_reviews WHERE review_id IS NULL
UNION ALL SELECT 'order_reviews.order_id', count(*)
FROM olist.order_reviews WHERE order_id IS NULL
UNION ALL SELECT 'products.product_id', count(*)
FROM olist.products WHERE product_id IS NULL
UNION ALL SELECT 'sellers.seller_id', count(*)
FROM olist.sellers WHERE seller_id IS NULL
UNION ALL SELECT 'product_category_name_translation.product_category_name', count(*)
FROM olist.product_category_name_translation WHERE product_category_name IS NULL;

-- Проверка отсутствия заказов без существующего клиента.
SELECT 'orders_without_customer' AS check_name, count(*) AS orphan_count
FROM olist.orders o
LEFT JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL
-- Проверка отсутствия позиций без существующего заказа.
SELECT 'items_without_order', count(*)
FROM olist.order_items oi
LEFT JOIN olist.orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL
UNION ALL
-- Проверка отсутствия позиций без существующего товара.
SELECT 'items_without_product', count(*)
FROM olist.order_items oi
LEFT JOIN olist.products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL
UNION ALL
-- Проверка отсутствия позиций без существующего продавца.
SELECT 'items_without_seller', count(*)
FROM olist.order_items oi
LEFT JOIN olist.sellers s ON s.seller_id = oi.seller_id
WHERE s.seller_id IS NULL
UNION ALL
-- Проверка отсутствия платежей без существующего заказа.
SELECT 'payments_without_order', count(*)
FROM olist.order_payments op
LEFT JOIN olist.orders o ON o.order_id = op.order_id
WHERE o.order_id IS NULL
UNION ALL
-- Проверка отсутствия отзывов без существующего заказа.
SELECT 'reviews_without_order', count(*)
FROM olist.order_reviews r
LEFT JOIN olist.orders o ON o.order_id = r.order_id
WHERE o.order_id IS NULL;
