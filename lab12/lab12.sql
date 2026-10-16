-- Карпов А.С.
-- Группа ИНБО-20-23
-- Вариант не предусмотрен

-- Учебные остатки товаров с запретом отрицательного количества.
CREATE TABLE IF NOT EXISTS lab.inventory (
    product_id text CONSTRAINT pk_inventory PRIMARY KEY
        CONSTRAINT fk_inventory_product REFERENCES olist.products(product_id),
    qty integer NOT NULL CONSTRAINT ck_inventory_qty CHECK (qty >= 0),
    version integer NOT NULL DEFAULT 0
);

-- Сто наиболее часто встречающихся товаров Olist.
INSERT INTO lab.inventory(product_id, qty)
SELECT product_id, 10 FROM olist.order_items
GROUP BY product_id ORDER BY count(*) DESC, product_id LIMIT 100
ON CONFLICT DO NOTHING;

-- Движения товаров для опыта с фантомами.
CREATE TABLE IF NOT EXISTS lab.inventory_movements (
    movement_id bigint GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_inventory_movements PRIMARY KEY,
    product_id text NOT NULL CONSTRAINT fk_inventory_movements_product REFERENCES lab.inventory(product_id),
    qty_delta integer NOT NULL CONSTRAINT ck_inventory_movements_delta CHECK (qty_delta <> 0),
    created_at timestamp NOT NULL DEFAULT current_timestamp
);

-- Атомарное резервирование одной единицы; результат примера откатывается.
BEGIN;
UPDATE lab.inventory
SET qty = qty - 1, version = version + 1
WHERE product_id = (SELECT product_id FROM lab.inventory ORDER BY product_id LIMIT 1)
  AND qty > 0
RETURNING product_id, qty, version;
ROLLBACK;
