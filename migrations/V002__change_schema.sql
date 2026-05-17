-- мержим product_info в product
ALTER TABLE product ADD COLUMN price numeric(10,2);

UPDATE product p
   SET price = pi.price
  FROM product_info pi
 WHERE pi.product_id = p.id;

DROP TABLE product_info;

-- мержим orders_date в orders
ALTER TABLE orders ADD COLUMN date_created date DEFAULT CURRENT_DATE;

UPDATE orders o
   SET date_created = od.date_created
  FROM orders_date od
 WHERE od.order_id = o.id;

DROP TABLE orders_date;

-- первичные ключи
ALTER TABLE product ADD CONSTRAINT product_pkey PRIMARY KEY (id);
ALTER TABLE orders  ADD CONSTRAINT orders_pkey  PRIMARY KEY (id);

-- внешние ключи на order_product
ALTER TABLE order_product
    ADD CONSTRAINT order_product_order_id_fkey
    FOREIGN KEY (order_id) REFERENCES orders(id);

ALTER TABLE order_product
    ADD CONSTRAINT order_product_product_id_fkey
    FOREIGN KEY (product_id) REFERENCES product(id);
