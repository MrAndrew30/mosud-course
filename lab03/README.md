# Практическая работа № 3

**Исходное отношение:** `olist.orders`.

**Используемые атрибуты:** `order_id`, `order_delivered_customer_date`, `order_estimated_delivery_date`.

## Реляционное выражение

Обозначения: `σ` — выборка строк, `ρ` — переименование столбцов, `π` — выбор нужных столбцов.

```text
π [order_id, delivered_date, estimated_date]
  ρ [order_delivered_customer_date → delivered_date,
     order_estimated_delivery_date → estimated_date]
    σ [order_delivered_customer_date IS NOT NULL AND
       order_estimated_delivery_date IS NOT NULL AND
       order_delivered_customer_date > order_estimated_delivery_date]
      (orders)
```

Выражение читается снизу вверх: сначала из `orders` выбираются заказы, доставленные позже плановой даты, затем столбцы с датами переименовываются и в результате оставляются только три требуемых столбца.

Эквивалентное выражение с двумя последовательными выборками:

```text
π [order_id, delivered_date, estimated_date]
  ρ [order_delivered_customer_date → delivered_date,
     order_estimated_delivery_date → estimated_date]
    σ [order_delivered_customer_date > order_estimated_delivery_date]
      σ [order_delivered_customer_date IS NOT NULL AND
         order_estimated_delivery_date IS NOT NULL]
        (orders)
```

Исходный запрос, две последовательные выборки и вариант ранней проекции возвращают 7827 строк. Симметрические разности между результатами равны нулю, поэтому SQL-варианты эквивалентны. Дубликаты в проекции не возникают, поскольку в ней сохраняется `order_id`, являющийся первичным ключом `orders`. Поэтому `SELECT` и `SELECT DISTINCT` возвращают одинаковые 7827 строк.
