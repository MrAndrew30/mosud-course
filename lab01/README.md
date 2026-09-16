# Практическая работа № 1

PostgreSQL 17 развёрнут с помощью Docker Compose.
Подключение: `localhost:5432`, база `olist`, пользователь `student`.
Данные импортированы из девяти CSV-файлов командой `psql \copy`.
Строки: `customers` — 99441, `orders` — 99441, `order_items` — 112650.
Строки: `order_payments` — 103886, `order_reviews` — 99224, `products` — 32951.
Строки: `sellers` — 3095, `geolocation` — 1000163, `product_category_name_translation` — 71.
NULL в ключевых полях и осиротевшие ссылки не обнаружены.
