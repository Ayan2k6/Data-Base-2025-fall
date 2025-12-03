-- 3.1 Setup: Create Test Database (tables + начальные данные)
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    balance DECIMAL(10,2) DEFAULT 0.00
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    shop VARCHAR(100) NOT NULL,
    product VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL
);

INSERT INTO accounts (name, balance) VALUES
    ('Alice', 1000.00),
    ('Bob', 500.00),
    ('Wally', 750.00);

INSERT INTO products (shop, product, price) VALUES
    ('Joe''s Shop', 'Coke', 2.50),
    ('Joe''s Shop', 'Pepsi', 3.00);

-- Просмотр начальных данных
SELECT * FROM accounts ORDER BY id;
SELECT * FROM products ORDER BY id;

-- Task 1: Basic Transaction with COMMIT
-- Перевод 100 от Alice к Bob в одной транзакции
BEGIN;
UPDATE accounts SET balance = balance - 100.00 WHERE name = 'Alice';
UPDATE accounts SET balance = balance + 100.00 WHERE name = 'Bob';
COMMIT;

-- Результат:
SELECT name, balance FROM accounts WHERE name IN ('Alice','Bob');

-- Task 2: Using ROLLBACK
-- Попытка списания 500 с Alice, затем откат
BEGIN;
UPDATE accounts SET balance = balance - 500.00 WHERE name = 'Alice';
-- показать промежуточное значение (в той же сессии)
SELECT name, balance FROM accounts WHERE name = 'Alice';
ROLLBACK;
-- после ROLLBACK баланс должен вернуться
SELECT name, balance FROM accounts WHERE name = 'Alice';

-- Task 3: Working with SAVEPOINTs
-- Перевод 100 от Alice -> (попытка к Bob), затем откат к savepoint и перевод к Wally
BEGIN;
UPDATE accounts SET balance = balance - 100.00 WHERE name = 'Alice';
SAVEPOINT my_savepoint;
-- неверно: переводим к Bob (потом откатим)
UPDATE accounts SET balance = balance + 100.00 WHERE name = 'Bob';
-- Откат к savepoint (удаляет эффект начисления Bob)
ROLLBACK TO my_savepoint;
-- Теперь правильно переводим к Wally
UPDATE accounts SET balance = balance + 100.00 WHERE name = 'Wally';
COMMIT;

-- Итого:
SELECT name, balance FROM accounts ORDER BY id;

-- Task 4: Isolation Level Demonstration (инструкции для двух сессий)
-- Ниже — команды, которые нужно выполнять в двух отдельных сессиях (Terminal 1 и Terminal 2).
-- Сценарий A: READ COMMITTED
-- Terminal 1:
-- BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- (ждать изменения из Terminal 2)
-- SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- COMMIT;
--
-- Terminal 2:
-- BEGIN;
-- DELETE FROM products WHERE shop = 'Joe''s Shop';
-- INSERT INTO products (shop, product, price) VALUES ('Joe''s Shop', 'Fanta', 3.50);
-- COMMIT;
--
-- Сценарий B: SERIALIZABLE
-- Terminal 1:
-- BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- (ждать)
-- SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- COMMIT;
--
-- Terminal 2: как выше (DELETE + INSERT + COMMIT)
--
-- (Комментарий: выполняйте вручную в двух сессиях, чтобы увидеть разницу.)

-- Task 5: Phantom Read Demonstration (REPEATABLE READ)
-- Инструкции для двух сессий:
-- Terminal 1:
-- BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- SELECT MAX(price) AS maxp, MIN(price) AS minp FROM products WHERE shop = 'Joe''s Shop';
-- (ждать)
-- SELECT MAX(price) AS maxp, MIN(price) AS minp FROM products WHERE shop = 'Joe''s Shop';
-- COMMIT;
--
-- Terminal 2:
-- BEGIN;
-- INSERT INTO products (shop, product, price) VALUES ('Joe''s Shop', 'Sprite', 4.00);
-- COMMIT;

-- ========================
-- Task 6: Dirty Read Demonstration (READ UNCOMMITTED)
-- ========================
-- В PostgreSQL READ UNCOMMITTED ведёт себя как READ COMMITTED (Postgres не даёт реальных dirty reads).
-- Тем не менее, для учебных целей:
-- Terminal 1:
-- BEGIN TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
-- SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- (ждать изменения клиенты 2)
-- SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- (ждать отката в Terminal 2)
-- SELECT * FROM products WHERE shop = 'Joe''s Shop';
-- COMMIT;
--
-- Terminal 2:
-- BEGIN;
-- UPDATE products SET price = 99.99 WHERE product = 'Fanta';
-- -- НЕ КОМИТИТЬ, потом ROLLBACK;
-- ROLLBACK;

-- ========================
-- Independent Exercise 1
-- Transfer $200 from Bob to Wally only if Bob has sufficient funds (with error handling)
-- ========================
-- Вариант 1: используя UPDATE ... WHERE + проверка row_count
BEGIN;
-- атомарный вариант: отнять 200 только если хватает средств
UPDATE accounts
SET balance = balance - 200.00
WHERE name = 'Bob' AND balance >= 200.00;

-- Проверить, обновилась ли строка
-- В psql можно проверить GET DIAGNOSTICS, но здесь используем явную проверку:
-- (в PL/pgSQL блоке ниже будет exception)
-- Делаем начисление Wally только если предыдущий UPDATE затронул строку
-- Ниже - PL/pgSQL блок, который кидает исключение при нехватке средств
ROLLBACK; -- откатим начатую транзакцию и запустим безопасный DO-блок

DO $$
DECLARE
  rows_affected INTEGER;
BEGIN
  PERFORM pg_sleep(0); -- no-op
  -- Начинаем транзакцию внутри DO (в PostgreSQL DO сам выполняется в отдельной транзакции)
  IF (SELECT balance FROM accounts WHERE name='Bob') >= 200.00 THEN
    UPDATE accounts SET balance = balance - 200.00 WHERE name='Bob';
    UPDATE accounts SET balance = balance + 200.00 WHERE name='Wally';
    RAISE NOTICE 'Transfer of $200 from Bob to Wally completed.';
  ELSE
    RAISE EXCEPTION 'Insufficient funds in Bob''s account. Transfer aborted.';
  END IF;
END$$;

-- Проверка:
SELECT name, balance FROM accounts WHERE name IN ('Bob','Wally');

-- ========================
-- Independent Exercise 2
-- Multiple savepoints sequence (insert -> savepoint -> update price -> savepoint -> delete -> rollback to first savepoint -> commit)
-- ========================
BEGIN;
INSERT INTO products (shop, product, price) VALUES ('New Shop', 'NewProduct', 10.00);
SAVEPOINT sp1;
-- обновляем цену
UPDATE products SET price = 12.50 WHERE shop = 'New Shop' AND product = 'NewProduct';
SAVEPOINT sp2;
-- удаляем товар
DELETE FROM products WHERE shop = 'New Shop' AND product = 'NewProduct';
-- откатываемся к первому savepoint (sp1): удаление отменится, а будет состояние после первой вставки (но до удаления)
ROLLBACK TO sp1;
COMMIT;

-- Итоговое состояние таблицы products (должен быть NewProduct с price = 12.50)
SELECT * FROM products WHERE shop = 'New Shop';

-- ========================
-- Independent Exercise 3
-- Banking scenario: два пользователя одновременно пытаются снять деньги с одного счёта.
-- Показываем варианты команд для двух сессий (Terminal 1 и Terminal 2).
-- ========================
-- Подготовка: создадим тестовый аккаунт "Shared"
INSERT INTO accounts (name, balance) VALUES ('Shared', 100.00)
ON CONFLICT DO NOTHING;

-- Вариант A - без блокировок (может возникнуть потеря средств)
-- Terminal 1:
-- BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SELECT balance FROM accounts WHERE name = 'Shared';
-- -- предположим, видим 100, хотим снять 80
-- UPDATE accounts SET balance = balance - 80 WHERE name = 'Shared';
-- -- (не коммитим)
--
-- Terminal 2 (параллельно):
-- BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SELECT balance FROM accounts WHERE name = 'Shared';
-- -- Тоже видит 100 -> снимает 80
-- UPDATE accounts SET balance = balance - 80 WHERE name = 'Shared';
-- COMMIT;  -- в результате может утечь баланс в отрицательное значение
-- Terminal 1 COMMIT;
--
-- Вариант B - с SELECT FOR UPDATE (локирует строку)
-- Terminal 1:
-- BEGIN;
-- SELECT balance FROM accounts WHERE name = 'Shared' FOR UPDATE;
-- -- теперь строка заблокирована, Terminal 2 будет ждать
-- UPDATE accounts SET balance = balance - 80 WHERE name = 'Shared' AND balance >= 80;
-- COMMIT;
--
-- Terminal 2:
-- BEGIN;
-- SELECT balance FROM accounts WHERE name = 'Shared' FOR UPDATE;
-- -- после освобождения блокировки сможет выполнить корректную проверку и снять средства только если они есть
-- UPDATE accounts SET balance = balance - 80 WHERE name = 'Shared' AND balance >= 80;
-- COMMIT;
--
-- Этот подход предотвращает гонки и гарантирует корректность.

-- ========================
-- Independent Exercise 4
-- Пример Sells(shop, product, price) демонстрирующий MAX < MIN при некорректных транзакциях
-- ========================
DROP TABLE IF EXISTS sells;
CREATE TABLE sells (
  shop VARCHAR(100),
  product VARCHAR(100),
  price NUMERIC
);

INSERT INTO sells VALUES ('SallyShop','A',10),('SallyShop','B',20);

-- Демонстрация (в двух сессиях):
-- Terminal Joe:
-- BEGIN;
-- UPDATE sells SET price = 100 WHERE shop='SallyShop' AND product='A';
-- -- не коммитит
--
-- Terminal Sally:
-- BEGIN;
-- -- читает агрегаты без транзакций/без согласованных уровней
-- SELECT MAX(price), MIN(price) FROM sells WHERE shop='SallyShop';
-- -- в этом случае может увидеть старое мин и новое макс, в итоге MAX < MIN может показаться (в специальных interleaving)
-- COMMIT;
--
-- Решение: использовать транзакции с SERIALIZABLE или блокировки, чтобы агрегаты были согласованы.

-- Для полноты: покажем текущую содержимое sells
SELECT * FROM sells ORDER BY product;

-- Self-check queries (вопросы отчёта можно заполнить результатами этих запросов)
-- Балансы после всех операций:
SELECT * FROM accounts ORDER BY id;

-- Полная таблица продуктов:
SELECT * FROM products ORDER BY id;
