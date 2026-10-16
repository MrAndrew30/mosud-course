-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант не предусмотрен

-- B01. Запустить в независимом сеансе B после lab12.sql.
\set VERBOSITY verbose
SET application_name = 'mosud_lab12_b';
SELECT product_id AS p1 FROM lab.inventory ORDER BY product_id LIMIT 1 \gset
SELECT product_id AS p2 FROM lab.inventory ORDER BY product_id OFFSET 1 LIMIT 1 \gset
SELECT pg_backend_pid() AS session_b_pid;

-- B02. Запустить после A02; затем A03.
BEGIN;
SELECT qty AS read_qty FROM lab.inventory WHERE product_id = :'p1' \gset
SELECT :read_qty AS read_qty_b;

-- B03. Запустить после A03; оба сеанса вычислили константу 9 из прочитанного 10.
UPDATE lab.inventory SET qty = :read_qty - 1, version = version + 1 WHERE product_id = :'p1';
COMMIT;

-- B04. Запустить после A04. Ожидать A05; SELECT вернёт уже обновлённый остаток.
BEGIN;
SELECT qty FROM lab.inventory WHERE product_id = :'p1' FOR UPDATE;

-- B05. Запустить после завершения B04.
UPDATE lab.inventory SET qty = qty - 1 WHERE product_id = :'p1' RETURNING qty;
COMMIT;

-- B06. Запустить после A06; ожидать A07. После освобождения строки условие qty > 0 проверяется повторно.
BEGIN;
UPDATE lab.inventory SET qty = qty - 1, version = version + 1
WHERE product_id = :'p1' AND qty > 0 RETURNING qty;

-- B07. Запустить после завершения B06; резервирование второй единицы не изменит ни одной строки.
COMMIT;

-- B08. Запустить после A08; затем A09.
BEGIN;
UPDATE lab.inventory SET qty = 9 WHERE product_id = :'p1';
COMMIT;

-- B09. Запустить после A10; затем A11.
BEGIN;
UPDATE lab.inventory SET qty = 9 WHERE product_id = :'p1';
COMMIT;

-- B10. Запустить после A12; затем A13.
BEGIN;
INSERT INTO lab.inventory_movements(product_id, qty_delta)
VALUES (:'p1', 1) RETURNING movement_id AS phantom_id \gset
COMMIT;

-- B11. Запустить после A14; затем A15.
BEGIN;
UPDATE lab.inventory SET qty = qty - 1 WHERE product_id = :'p2';

-- B12. Запустить, когда A15 ожидает; дождаться ошибки deadlock в одном из сеансов.
UPDATE lab.inventory SET qty = qty - 1 WHERE product_id = :'p1';

-- B13. Запустить после завершения A15 и B12.
ROLLBACK;

-- B14. Запустить после A16; удалить только движение, добавленное в B10. Затем выполнить A17.
DELETE FROM lab.inventory_movements WHERE movement_id = :phantom_id;
