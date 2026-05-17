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

Замеры на store_default (10М заказов):

Без индексов — 33555 мс
С индексами  — 21810 мс

Получилось в ~1.5 раза быстрее. Основной выигрыш на фильтре orders_date —
там было 13.9 сек, стало 40 мс. Join по order_product всё равно делается
сегскан + хэшджойн, отсюда оставшиеся 20 сек.
