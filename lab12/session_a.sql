-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант не предусмотрен

-- A01. Запустить в сеансе A после lab12.sql. Далее выполнять блоки по порядку из README.
\set VERBOSITY verbose
SET application_name = 'mosud_lab12_a';
SELECT product_id AS p1 FROM lab.inventory ORDER BY product_id LIMIT 1 \gset
SELECT product_id AS p2 FROM lab.inventory ORDER BY product_id OFFSET 1 LIMIT 1 \gset
SELECT pg_backend_pid() AS session_a_pid;
CREATE TEMP TABLE initial_inventory AS
SELECT * FROM lab.inventory WHERE product_id IN (:'p1', :'p2');

-- A02. Запустить; ожидать чтение B02.
UPDATE lab.inventory SET qty = 10, version = 0 WHERE product_id IN (:'p1', :'p2');
BEGIN;
SELECT qty AS read_qty FROM lab.inventory WHERE product_id = :'p1' \gset
SELECT :read_qty AS read_qty_a;

-- A03. Запустить после B02; затем выполнить B03.
UPDATE lab.inventory SET qty = :read_qty - 1, version = version + 1 WHERE product_id = :'p1';
COMMIT;

-- A04. Запустить после B03; затем B04 будет ожидать эту блокировку.
SELECT qty AS lost_update_qty, version FROM lab.inventory WHERE product_id = :'p1';
UPDATE lab.inventory SET qty = 10 WHERE product_id = :'p1';
BEGIN;
SELECT qty FROM lab.inventory WHERE product_id = :'p1' FOR UPDATE;

-- A05. Запустить, когда B04 ожидает. После COMMIT дождаться окончания B04.
SELECT pid AS waiting_pid, wait_event_type, wait_event, pg_blocking_pids(pid) AS blockers
FROM pg_stat_activity WHERE application_name = 'mosud_lab12_b';
UPDATE lab.inventory SET qty = qty - 1 WHERE product_id = :'p1' RETURNING qty;
COMMIT;

-- A06. Запустить после B05. Затем B06 будет ожидать фиксации A07.
SELECT qty AS locked_result FROM lab.inventory WHERE product_id = :'p1';
UPDATE lab.inventory SET qty = 1 WHERE product_id = :'p1';
BEGIN;
UPDATE lab.inventory SET qty = qty - 1, version = version + 1
WHERE product_id = :'p1' AND qty > 0 RETURNING qty;

-- A07. Запустить, когда B06 ожидает. Дождаться B06 и выполнить B07.
COMMIT;

-- A08. Запустить после B07; ожидать B08.
SELECT qty AS atomic_result FROM lab.inventory WHERE product_id = :'p1';
UPDATE lab.inventory SET qty = 10 WHERE product_id = :'p1';
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT qty AS first_read_rc FROM lab.inventory WHERE product_id = :'p1';

-- A09. Запустить после B08.
SELECT qty AS second_read_rc FROM lab.inventory WHERE product_id = :'p1';
COMMIT;

-- A10. Запустить; ожидать B09.
UPDATE lab.inventory SET qty = 10 WHERE product_id = :'p1';
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT qty AS first_read_rr FROM lab.inventory WHERE product_id = :'p1';

-- A11. Запустить после B09.
SELECT qty AS second_read_rr FROM lab.inventory WHERE product_id = :'p1';
COMMIT;
SELECT qty AS after_commit_rr FROM lab.inventory WHERE product_id = :'p1';

-- A12. Запустить; ожидать вставку B10.
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT count(*) AS first_count FROM lab.inventory_movements
WHERE product_id = :'p1' AND qty_delta > 0;

-- A13. Запустить после B10.
SELECT count(*) AS second_count FROM lab.inventory_movements
WHERE product_id = :'p1' AND qty_delta > 0;
COMMIT;

-- A14. Запустить; затем B11.
UPDATE lab.inventory SET qty = 10 WHERE product_id IN (:'p1', :'p2');
BEGIN;
UPDATE lab.inventory SET qty = qty - 1 WHERE product_id = :'p1';

-- A15. Запустить после B11. Пока запрос ожидает, запустить B12; сохранить сообщение о deadlock.
UPDATE lab.inventory SET qty = qty - 1 WHERE product_id = :'p2';

-- A16. Запустить после завершения A15 и B12 независимо от того, какой сеанс прерван.
ROLLBACK;

-- A17. Запустить после B13 и B14; восстановить исходные qty и version.
UPDATE lab.inventory i SET qty = s.qty, version = s.version
FROM initial_inventory s WHERE i.product_id = s.product_id;
SELECT bool_and(i.qty = s.qty AND i.version = s.version) AS restored
FROM lab.inventory i JOIN initial_inventory s USING (product_id);
