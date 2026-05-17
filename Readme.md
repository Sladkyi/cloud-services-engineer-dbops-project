# dbops-project

Проектная работа по DBOps. Сосисочная.

## Шаг 3. Создание пользователя и БД

Подключился к Postgres от админа:

    psql "postgresql://user:password@localhost:5432/postgres"

Выполнил:

    CREATE USER store_user WITH PASSWORD 'store_password';
    CREATE DATABASE store OWNER store_user;
    GRANT ALL PRIVILEGES ON DATABASE store TO store_user;

После этого зашёл в саму базу store и докинул права на схему public
(в postgres 15+ это обязательно, иначе Flyway не сможет создать таблицы):

    psql "postgresql://user:password@localhost:5432/store"

    GRANT ALL ON SCHEMA public TO store_user;
    ALTER SCHEMA public OWNER TO store_user;

## Шаг 10. Запрос по продажам за неделю

Считаем сколько сосисок продано за каждый день последней недели
(берём только доставленные заказы):

    SELECT o.date_created, SUM(op.quantity)
    FROM orders AS o
    JOIN order_product AS op ON o.id = op.order_id
    WHERE o.status = 'shipped' AND o.date_created > NOW() - INTERVAL '7 DAY'
    GROUP BY o.date_created;

Прогон на исходной БД store_default (там 10М заказов, индексов нет):

     date_created |  sum
    --------------+--------
     2026-05-11   | 940516
     2026-05-12   | 942143
     2026-05-13   | 945063
     2026-05-14   | 948678
     2026-05-15   | 943455
     2026-05-16   | 945886
     2026-05-17   | 781964

    Time: 34982.8 ms (~35 секунд)

Без индексов запрос пилит два seq scan по 10М строк — отсюда тормоза.
## Шаг 11. Индексы

Создал в V004:

CREATE INDEX order_product_order_id_idx ON order_product(order_id);
CREATE INDEX orders_status_date_idx ON orders(status, date_created);

Замеры на store_default (10М заказов).

### Без индексов

Time: 33555 ms
```sql
EXPLAIN (ANALYZE, BUFFERS):
  Finalize GroupAggregate  ... (actual time=33461..33467 rows=7)
    Parallel Hash Join  (actual time=14003..33419 rows=84283)
      Parallel Seq Scan on order_product  (actual time=18..18324)
      Parallel Hash
        Parallel Seq Scan on orders_date
          Filter: status='shipped' AND date_created > NOW()-INTERVAL '7 DAY'
          Rows Removed by Filter: 3 249 050
  Execution Time: 33 555 ms
```
### С индексами

Time: 21810 ms
```sql
EXPLAIN (ANALYZE, BUFFERS):
  Finalize GroupAggregate  ... (actual time=21787..21792 rows=7)
    Parallel Hash Join  (actual time=92..21738 rows=84283)
      Parallel Seq Scan on order_product  (actual time=20..20635)
      Parallel Hash
        Parallel Bitmap Heap Scan on orders_date  (actual time=16..40 rows=84283)
          Recheck Cond: status='shipped' AND date_created > NOW()-INTERVAL '7 DAY'
          Bitmap Index Scan on orders_date_status_date_idx  (actual time=15..15)
  Execution Time: 21 810 ms
```
### Вывод

Общее время сократилось в ~1.5 раза (33.5 → 21.8 сек).
Главный эффект — на фильтре orders_date: 13.9 сек → 40 мс (×350) благодаря
композитному индексу. Join по order_product всё равно делается через
parallel seq scan + hash join — постгресу так дешевле по cost-модели,
чем nested loop с индексом, поэтому 20 сек остаются в join.
