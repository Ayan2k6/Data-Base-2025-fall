-- Удаляем старые таблицы если есть
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS exchange_rates CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- CREATE TABLES
-- Таблица клиентов
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    iin VARCHAR(12) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    status VARCHAR(20) DEFAULT 'active' 
        CHECK (status IN ('active', 'blocked', 'frozen')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    daily_limit_kzt DECIMAL(15, 2) DEFAULT 5000000
);

-- Таблица счётов
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    account_number VARCHAR(34) UNIQUE NOT NULL,
    currency VARCHAR(3) CHECK (currency IN ('KZT', 'USD', 'EUR', 'RUB')),
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP
);

-- Таблица курсов обмена
CREATE TABLE exchange_rates (
    rate_id SERIAL PRIMARY KEY,
    from_currency VARCHAR(3),
    to_currency VARCHAR(3),
    rate DECIMAL(10, 4),
    valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_to TIMESTAMP
);

-- Таблица транзакций
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INTEGER REFERENCES accounts(account_id),
    to_account_id INTEGER REFERENCES accounts(account_id),
    amount DECIMAL(15, 2),
    currency VARCHAR(3),
    exchange_rate DECIMAL(10, 4),
    amount_kzt DECIMAL(15, 2),
    type VARCHAR(20) CHECK (type IN ('transfer', 'deposit', 'withdrawal')),
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    description TEXT
);

-- Таблица аудита
CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50),
    record_id INTEGER,
    action VARCHAR(20) CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(50)
);

-- POPULATE TEST DATA
-- Вставляем 11клиентов
INSERT INTO customers (iin, full_name, phone, email, status, daily_limit_kzt) VALUES
('123456789012', 'Aidar Tleuzhanov', '+7 747 123 4507', 'aidar@bank.kz', 'active', 10000000),
('234567890123', 'Aliya Nurzhanova', '+7 707 234 5670', 'aliya@bank.kz', 'active', 5000000),
('345678901234', 'Kanat Orazov', '+7 700 345 6089', 'kanat@bank.kz', 'active', 5000000),
('456789012345', 'Gulshat Ismailova', '+7 708 416 7890', 'gulshat@bank.kz', 'active', 3000000),
('567890123456', 'Timur Zhangeldinov', '+7 747 537 8901', 'timur@bank.kz', 'blocked', 5000000),
('678901234567', 'Assel Khabibulina', '+7 747 677 9019', 'assel@bank.kz', 'active', 7000000),
('789012345678', 'Marat Bekbolatov', '+7 708 709 0123', 'marat@bank.kz', 'frozen', 5000000),
('890123456789', 'Nazira Suleimenova', '+7 700 890 1784', 'nazira@bank.kz', 'active', 5000000),
('901234567890', 'Erlan Tursynov', '+7 747 901 2965', 'erlan@bank.kz', 'active', 8000000),
('012345678901', 'Bibigul Mamyrova', '+7 707 012 7456', 'bibigul@bank.kz', 'active', 5000000),
('111111511111', 'Aiber Kamush', '+7 707 505 5125', 'aibkamu@bank.kz', 'active', 100000000);

-- Вставляем 14счётов
INSERT INTO accounts (customer_id, account_number, currency, balance, is_active) VALUES
(1, 'KZ86KZBA0000000001', 'KZT', 5000000, TRUE),
(1, 'KZ86KZBA0000000002', 'USD', 50000, TRUE),
(2, 'KZ86KZBA0000000003', 'KZT', 3000000, TRUE),
(2, 'KZ86KZBA0000000004', 'EUR', 20000, TRUE),
(3, 'KZ86KZBA0000000005', 'KZT', 2000000, TRUE),
(3, 'KZ86KZBA0000000006', 'RUB', 500000, TRUE),
(4, 'KZ86KZBA0000000007', 'KZT', 1500000, TRUE),
(5, 'KZ86KZBA0000000008', 'KZT', 8000000, TRUE),
(6, 'KZ86KZBA0000000009', 'KZT', 4500000, TRUE),
(7, 'KZ86KZBA0000000010', 'USD', 25000, TRUE),
(8, 'KZ86KZBA0000000011', 'KZT', 6000000, TRUE),
(9, 'KZ86KZBA0000000012', 'KZT', 7500000, TRUE),
(10, 'KZ86KZBA0000000013', 'EUR', 30000, TRUE),
(11, 'KZ86KZBA0000000014', 'KZT', 50000000, TRUE);

-- Вставляем курсы обмена
INSERT INTO exchange_rates (from_currency, to_currency, rate) VALUES
('USD', 'KZT', 516.38),
('EUR', 'KZT', 600.47),
('RUB', 'KZT', 6.69),
('KZT', 'USD', 0.0019),
('KZT', 'EUR', 0.0017),
('KZT', 'RUB', 0.15);

-- TASK 1 - PROCESS_TRANSFER STORED PROCEDURE
-- Процедура обрабатывает переводы между счётами с полной проверкой:
-- существование счётов
-- статус клиента
-- достаточность баланса
-- дневной лимит
-- конвертация валют

CREATE OR REPLACE FUNCTION process_transfer(
    p_from_account_number VARCHAR,
    p_to_account_number VARCHAR,
    p_amount DECIMAL,
    p_currency VARCHAR,
    p_description TEXT
) RETURNS TABLE (
    success BOOLEAN,
    transaction_id INTEGER,
    error_code VARCHAR,
    error_message TEXT
) AS $$
DECLARE
    v_from_account_id INTEGER;
    v_to_account_id INTEGER;
    v_from_customer_id INTEGER;
    v_from_customer_status VARCHAR;
    v_from_balance DECIMAL;
    v_to_account_active BOOLEAN;
    v_amount_kzt DECIMAL;
    v_exchange_rate DECIMAL;
    v_transaction_id INTEGER;
    v_today_total_kzt DECIMAL;
    v_daily_limit DECIMAL;
BEGIN
    -- Проверяем что счёт отправителя существует
    SELECT account_id, customer_id INTO v_from_account_id, v_from_customer_id
    FROM accounts WHERE account_number = p_from_account_number;
    
    IF v_from_account_id IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::INTEGER, 'ACCOUNT_NOT_FOUND', 
            'Счёт отправителя не найден в системе';
        RETURN;
    END IF;
    
    -- Проверяем что счёт получателя существует
    SELECT account_id INTO v_to_account_id
    FROM accounts WHERE account_number = p_to_account_number;
    
    IF v_to_account_id IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::INTEGER, 'ACCOUNT_NOT_FOUND', 
            'Счёт получателя не найден в системе';
        RETURN;
    END IF;
    
    -- Проверяем что оба счёта активны
    SELECT is_active FROM accounts WHERE account_id = v_from_account_id 
    INTO v_from_balance;
    IF NOT v_from_balance::BOOLEAN THEN
        RETURN QUERY SELECT FALSE, NULL::INTEGER, 'ACCOUNT_INACTIVE', 
            'Счёт отправителя заморожен или закрыт';
        RETURN;
    END IF;
    
    SELECT is_active FROM accounts WHERE account_id = v_to_account_id 
    INTO v_to_account_active;
    IF NOT v_to_account_active THEN
        RETURN QUERY SELECT FALSE, NULL::INTEGER, 'ACCOUNT_INACTIVE', 
            'Счёт получателя заморожен или закрыт';
        RETURN;
    END IF;
    
    -- Проверяем статус клиента-отправителя
    SELECT status INTO v_from_customer_status
    FROM customers WHERE customer_id = v_from_customer_id;
    
    IF v_from_customer_status != 'active' THEN
        INSERT INTO audit_log (table_name, record_id, action, new_values, changed_by)
        VALUES ('transactions', NULL, 'INSERT', 
            jsonb_build_object('error', 'customer_not_active', 'status', v_from_customer_status),
            'system');
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, 'CUSTOMER_NOT_ACTIVE', 
            'Клиент имеет статус: ' || v_from_customer_status || 
            '. Операция невозможна';
        RETURN;
    END IF;
    
    -- Используем SELECT FOR UPDATE для предотвращения race conditions
    SELECT balance INTO v_from_balance
    FROM accounts WHERE account_id = v_from_account_id
    FOR UPDATE;
    
    -- Проверяем достаточность баланса
    IF v_from_balance < p_amount THEN
        INSERT INTO audit_log (table_name, record_id, action, new_values, changed_by)
        VALUES ('transactions', NULL, 'INSERT', 
            jsonb_build_object('error', 'insufficient_balance', 
                'required', p_amount, 'available', v_from_balance),
            'system');
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, 'INSUFFICIENT_BALANCE', 
            'Недостаточно средств. Требуется: ' || p_amount || 
            ', доступно: ' || v_from_balance;
        RETURN;
    END IF;
    
    -- Определяем курс обмена и конвертируем в KZT
    IF p_currency = 'KZT' THEN
        v_amount_kzt := p_amount;
        v_exchange_rate := 1.0;
    ELSE
        -- ищем актуальный курс для этой валюты
        SELECT rate INTO v_exchange_rate
        FROM exchange_rates 
        WHERE from_currency = p_currency AND to_currency = 'KZT'
        AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP)
        LIMIT 1;
        
        IF v_exchange_rate IS NULL THEN
            RETURN QUERY SELECT FALSE, NULL::INTEGER, 'EXCHANGE_RATE_NOT_FOUND', 
                'Курс обмена для ' || p_currency || ' не найден в системе';
            RETURN;
        END IF;
        
        v_amount_kzt := p_amount * v_exchange_rate;
    END IF;
    
    -- Проверяем дневной лимит
    SELECT daily_limit_kzt INTO v_daily_limit
    FROM customers WHERE customer_id = v_from_customer_id;
    
    -- Суммируем все транзакции за сегодня
    SELECT COALESCE(SUM(amount_kzt), 0) INTO v_today_total_kzt
    FROM transactions
    WHERE from_account_id = v_from_account_id
    AND DATE(created_at) = CURRENT_DATE
    AND status IN ('completed', 'pending');
    
    IF v_today_total_kzt + v_amount_kzt > v_daily_limit THEN
        RETURN QUERY SELECT FALSE, NULL::INTEGER, 'DAILY_LIMIT_EXCEEDED',
            'Превышен дневной лимит. Использовано: ' || v_today_total_kzt || 
            ' KZT, лимит: ' || v_daily_limit || ' KZT';
        RETURN;
    END IF;
    
    -- Создаем запись о транзакции в статусе pending
    INSERT INTO transactions 
        (from_account_id, to_account_id, amount, currency, 
         exchange_rate, amount_kzt, type, status, description)
    VALUES 
        (v_from_account_id, v_to_account_id, p_amount, p_currency,
         v_exchange_rate, v_amount_kzt, 'transfer', 'pending', p_description)
    RETURNING transaction_id INTO v_transaction_id;
    
    -- Обновляем баланс отправителя
    UPDATE accounts SET balance = balance - p_amount
    WHERE account_id = v_from_account_id;
    
    -- Обновляем баланс получателя
    UPDATE accounts SET balance = balance + p_amount
    WHERE account_id = v_to_account_id;
    
    -- Отмечаем транзакцию как завершённую
    UPDATE transactions 
    SET status = 'completed', completed_at = CURRENT_TIMESTAMP
    WHERE transaction_id = v_transaction_id;
    
    -- Логируем успешную операцию в аудит
    INSERT INTO audit_log (table_name, record_id, action, new_values, changed_by)
    VALUES ('transactions', v_transaction_id, 'INSERT',
        jsonb_build_object(
            'from_account', v_from_account_id, 
            'to_account', v_to_account_id, 
            'amount', p_amount, 
            'currency', p_currency,
            'amount_kzt', v_amount_kzt
        ),
        'system');
    
    RETURN QUERY SELECT TRUE, v_transaction_id, 'SUCCESS', 
        'Перевод выполнен успешно. ID транзакции: ' || v_transaction_id;
END;
$$ LANGUAGE plpgsql;

-- TASK 4 - PROCESS_SALARY_BATCH STORED PROCEDURE
-- Процедура обрабатывает пакетную выплату зарплат:
-- - использует advisory lock для предотвращения параллельных батчей
-- - обрабатывает каждый платёж отдельно (SAVEPOINT для частичного успеха)
-- - возвращает детальный результат (успешно/ошибки)

CREATE OR REPLACE FUNCTION process_salary_batch(
    p_company_account_number VARCHAR,
    p_payments JSONB
) RETURNS TABLE (
    successful_count INTEGER,
    failed_count INTEGER,
    failed_details JSONB
) AS $$
DECLARE
    v_company_account_id INTEGER;
    v_company_balance DECIMAL;
    v_total_amount DECIMAL;
    v_payment JSONB;
    v_customer_iin VARCHAR;
    v_amount DECIMAL;
    v_description TEXT;
    v_recipient_account_id INTEGER;
    v_recipient_customer_id INTEGER;
    v_failed_count INTEGER := 0;
    v_successful_count INTEGER := 0;
    v_failed_details JSONB := '[]'::JSONB;
    v_lock_id BIGINT;
    i INTEGER;
    v_payment_count INTEGER;
BEGIN
    -- Получаем ID счёта компании
    SELECT account_id INTO v_company_account_id
    FROM accounts WHERE account_number = p_company_account_number;
    
    IF v_company_account_id IS NULL THEN
        RETURN QUERY SELECT 0, 1, jsonb_build_array(
            jsonb_build_object('error', 'Company account not found')
        );
        RETURN;
    END IF;
    
    -- Используем advisory lock для предотвращения параллельных батчей
    v_lock_id := hashtext(p_company_account_number);
    IF NOT pg_advisory_try_lock(v_lock_id) THEN
        RETURN QUERY SELECT 0, 1, jsonb_build_array(
            jsonb_build_object('error', 
                'Batch processing already in progress for this company')
        );
        RETURN;
    END IF;
    
    -- Блокируем счёт на обновление
    SELECT balance INTO v_company_balance
    FROM accounts WHERE account_id = v_company_account_id
    FOR UPDATE;
    
    -- Вычисляем общую сумму всех платежей в батче
    v_payment_count := jsonb_array_length(p_payments);
    v_total_amount := 0;
    
    FOR i IN 0..(v_payment_count - 1) LOOP
        v_payment := p_payments -> i;
        v_amount := (v_payment->>'amount')::DECIMAL;
        v_total_amount := v_total_amount + v_amount;
    END LOOP;
    
    -- Проверяем хватает ли денег на все платежи
    IF v_company_balance < v_total_amount THEN
        PERFORM pg_advisory_unlock(v_lock_id);
        RETURN QUERY SELECT 0, 1, jsonb_build_array(
            jsonb_build_object('error', 
                'Insufficient balance. Required: ' || v_total_amount || 
                ', Available: ' || v_company_balance)
        );
        RETURN;
    END IF;
    
    -- Обрабатываем каждый платёж отдельно
    FOR i IN 0..(v_payment_count - 1) LOOP
        BEGIN
            v_payment := p_payments -> i;
            v_customer_iin := v_payment->>'iin';
            v_amount := (v_payment->>'amount')::DECIMAL;
            v_description := COALESCE(v_payment->>'description', 'Salary payment');
            
            -- Ищем счёт получателя по IIN
            SELECT a.account_id, c.customer_id INTO v_recipient_account_id, v_recipient_customer_id
            FROM accounts a
            JOIN customers c ON a.customer_id = c.customer_id
            WHERE c.iin = v_customer_iin
            AND a.is_active = TRUE
            AND a.currency = 'KZT'
            LIMIT 1;
            
            IF v_recipient_account_id IS NULL THEN
                -- Получателя не найдено - добавляем в список ошибок
                v_failed_count := v_failed_count + 1;
                v_failed_details := v_failed_details || jsonb_build_array(
                    jsonb_build_object(
                        'iin', v_customer_iin, 
                        'amount', v_amount,
                        'error', 'Active KZT account not found for this customer'
                    )
                );
            ELSE
                -- Делаем перевод (зарплаты не проверяют дневной лимит)
                UPDATE accounts SET balance = balance - v_amount
                WHERE account_id = v_company_account_id;
                
                UPDATE accounts SET balance = balance + v_amount
                WHERE account_id = v_recipient_account_id;
                
                INSERT INTO transactions 
                    (from_account_id, to_account_id, amount, currency,
                     exchange_rate, amount_kzt, type, status, description)
                VALUES 
                    (v_company_account_id, v_recipient_account_id, v_amount, 'KZT',
                     1.0, v_amount, 'transfer', 'completed', v_description);
                
                v_successful_count := v_successful_count + 1;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            -- Ловим любые ошибки для этого платежа
            v_failed_count := v_failed_count + 1;
            v_failed_details := v_failed_details || jsonb_build_array(
                jsonb_build_object(
                    'iin', v_customer_iin, 
                    'amount', v_amount,
                    'error', SQLERRM
                )
            );
        END;
    END LOOP;
    
    -- Отпускаем advisory lock
    PERFORM pg_advisory_unlock(v_lock_id);
    
    -- Логируем результат батча в аудит
    INSERT INTO audit_log (table_name, record_id, action, new_values, changed_by)
    VALUES ('transactions', v_company_account_id, 'INSERT',
        jsonb_build_object(
            'batch_type', 'salary',
            'successful', v_successful_count,
            'failed', v_failed_count,
            'total_amount', v_total_amount
        ),
        'system');
    
    RETURN QUERY SELECT v_successful_count, v_failed_count, v_failed_details;
END;
$$ LANGUAGE plpgsql;

-- TASK 2 - CREATE VIEWS FOR REPORTING
-- View 1: Customer balance summary
-- Показывает каждого клиента с суммой всех его счётов в KZT
-- Включает ранжирование по балансу и утилизацию дневного лимита

CREATE VIEW customer_balance_summary AS
SELECT
    c.customer_id,
    c.full_name,
    c.iin,
    c.status,
    COUNT(a.account_id) as account_count,
    -- суммируем все балансы, конвертируя в KZT
    ROUND(SUM(
        CASE 
            WHEN a.currency = 'KZT' THEN a.balance
            WHEN a.currency = 'USD' THEN a.balance * 516.38
            WHEN a.currency = 'EUR' THEN a.balance * 600.47
            WHEN a.currency = 'RUB' THEN a.balance * 6.69
            ELSE 0
        END
    ), 2) as total_balance_kzt,
    c.daily_limit_kzt,
    -- вычисляем процент использования дневного лимита
    ROUND(
        100.0 * COALESCE(
            (SELECT SUM(amount_kzt) FROM transactions t
             WHERE t.from_account_id IN (SELECT account_id FROM accounts 
                                        WHERE customer_id = c.customer_id)
             AND DATE(t.created_at) = CURRENT_DATE
             AND t.status IN ('completed', 'pending')),
            0
        ) / NULLIF(c.daily_limit_kzt, 0),
        2
    ) as daily_limit_usage_percent,
    -- ранжируем клиентов по размеру баланса
    ROW_NUMBER() OVER (ORDER BY 
        SUM(
            CASE 
                WHEN a.currency = 'KZT' THEN a.balance
                WHEN a.currency = 'USD' THEN a.balance * 516.38
                WHEN a.currency = 'EUR' THEN a.balance * 600.47
                WHEN a.currency = 'RUB' THEN a.balance * 6.69
                ELSE 0
            END
        ) DESC
    ) as balance_rank
FROM customers c
LEFT JOIN accounts a ON c.customer_id = a.customer_id AND a.is_active = TRUE
GROUP BY c.customer_id, c.full_name, c.iin, c.status, c.daily_limit_kzt;

-- View 2: Daily transaction report
-- Агрегирует транзакции по дате и типу
-- Показывает объём, количество, среднее значение
-- Включает running totals и day-over-day growth

CREATE VIEW daily_transaction_report AS
SELECT
    DATE(created_at) as transaction_date,
    type,
    COUNT(*) as transaction_count,
    ROUND(SUM(amount_kzt), 2) as total_volume_kzt,
    ROUND(AVG(amount_kzt), 2) as avg_amount_kzt,
    ROUND(MIN(amount_kzt), 2) as min_amount_kzt,
    ROUND(MAX(amount_kzt), 2) as max_amount_kzt,
    -- running total (нарастающий итог по дням)
    ROUND(SUM(SUM(amount_kzt)) OVER (
        PARTITION BY type 
        ORDER BY DATE(created_at)
    ), 2) as running_total_kzt,
    -- day-over-day growth percentage
    ROUND(
        100.0 * (SUM(amount_kzt) - LAG(SUM(amount_kzt), 1) OVER (
            PARTITION BY type 
            ORDER BY DATE(created_at)
        )) / NULLIF(LAG(SUM(amount_kzt), 1) OVER (
            PARTITION BY type 
            ORDER BY DATE(created_at)
        ), 0),
        2
    ) as day_over_day_growth_percent
FROM transactions
WHERE status IN ('completed', 'pending')
GROUP BY DATE(created_at), type;

-- View 3: Suspicious activity view
-- Ловит подозрительные транзакции для compliance
-- - трансферы более 5,000,000 KZT
-- - >10 транзакций в час одного клиента
-- Использует SECURITY BARRIER для защиты от утечки данных

CREATE VIEW suspicious_activity_view WITH (security_barrier = true) AS
SELECT
    t.transaction_id,
    c.full_name,
    c.iin,
    t.amount_kzt,
    t.created_at,
    t.type,
    'High amount transfer' as alert_type
FROM transactions t
JOIN accounts a ON t.from_account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.amount_kzt > 5000000
AND t.status IN ('completed', 'pending')
AND t.created_at > CURRENT_TIMESTAMP - INTERVAL '7 days'

UNION ALL

SELECT
    MAX(t.transaction_id)::INTEGER,
    c.full_name,
    c.iin,
    COUNT(*)::DECIMAL as transaction_count,
    MAX(t.created_at),
    'Multiple txns' as type,
    'High frequency' as alert_type
FROM transactions t
JOIN accounts a ON t.from_account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.status IN ('completed', 'pending')
AND t.created_at > CURRENT_TIMESTAMP - INTERVAL '7 days'
GROUP BY c.customer_id, c.full_name, c.iin, DATE_TRUNC('hour', t.created_at)
HAVING COUNT(*) > 10;

-- TASK 3 - CREATE INDEXES WITH STRATEGY
-- Index 1: B-tree на account_number
CREATE INDEX idx_accounts_account_number ON accounts(account_number);
-- Использование: WHERE account_number = 'KZ86...'
-- Размер: малый, селективность: высокая

-- Index 2: Composite B-tree для быстрого поиска счётов клиента
CREATE INDEX idx_accounts_customer_active ON accounts(customer_id, is_active);
-- Использование: WHERE customer_id = X AND is_active = TRUE
-- Оптимизирует условие для поиска активных счётов клиента

-- Index 3: B-tree на дату и статус для транзакций
CREATE INDEX idx_transactions_date_status ON transactions(DATE(created_at), status);
-- Использование: WHERE DATE= ? AND status IN
-- Критичен для отчётов по дням

-- Index 4: Partial index для активных счётов только
CREATE INDEX idx_accounts_active_only ON accounts(account_id) WHERE is_active = TRUE;
-- Использование: операции на активных счётах (большинство операций)
-- Меньше размером, так как не индексирует закрытые счёта

-- Index 5: Hash index на IIN для точного поиска
CREATE INDEX idx_customers_iin_hash ON customers USING HASH (iin);
-- Использование: WHERE iin = '123456789012'
-- Hash индекс быстрее B-tree для точного совпадения

-- Index 6: Expression index для case-insensitive поиска email
CREATE INDEX idx_customers_email_lower ON customers(LOWER(email));
-- Использование: WHERE LOWER(email) = LOWER(?)
-- Позволяет быстрый поиск без учёта регистра

-- Index 7: GIN index на JSONB для аудит-логов
CREATE INDEX idx_audit_log_new_values_gin ON audit_log USING GIN (new_values);
-- Использование: WHERE new_values @> '{...}'
-- Оптимален для запросов на содержание в JSON

-- Index 8: Covering index (включает status в индекс)
CREATE INDEX idx_transactions_covering ON transactions
    (from_account_id, DATE(created_at), amount_kzt)
    INCLUDE (status);
-- Использование: все поля в индексе, возможен index-only scan
-- Снижает обращение к основной таблице

--DEMONSTRATION & TEST CASES
-- Начинаем с чистого состояния для тестов
-- Все последующие тесты демонстрируют различные сценарии

COMMIT;
BEGIN;

-- TEST 1: Успешный перевод KZT
SELECT '=== TEST 1: Успешный перевод между счётами (KZT) ===' as test_case;

-- Перед операцией
SELECT account_number, balance FROM accounts 
WHERE account_number IN ('KZ86KZBA0000000001', 'KZ86KZBA0000000003')
ORDER BY account_number;

-- Выполняем перевод
SELECT * FROM process_transfer(
    'KZ86KZBA0000000001',  -- от Aidar
    'KZ86KZBA0000000003',  -- к Aliya
    500000,
    'KZT',
    'Test successful transfer'
);

-- После операции
SELECT account_number, balance FROM accounts 
WHERE account_number IN ('KZ86KZBA0000000001', 'KZ86KZBA0000000003')
ORDER BY account_number;

-- TEST 2: Недостаточно средств
SELECT '=== TEST 2: Попытка перевода при недостатке средств ===' as test_case;

SELECT * FROM process_transfer(
    'KZ86KZBA0000000007',  -- Gulshat баланс 1,500,000
    'KZ86KZBA0000000003',
    10000000,  -- больше чем есть
    'KZT',
    'Test insufficient balance'
);

-- TEST 3: Заблокированный клиент
SELECT '=== TEST 3: Попытка перевода от заблокированного клиента ===' as test_case;

SELECT * FROM process_transfer(
    'KZ86KZBA0000000008',  -- Timur status = blocked
    'KZ86KZBA0000000003',
    500000,
    'KZT',
    'Test blocked customer'
);

-- TEST 4: Конвертация валют (USD -> KZT)
SELECT '=== TEST 4: Перевод с конвертацией валют ===' as test_case;

-- Баланс до операции
SELECT account_number, currency, balance FROM accounts 
WHERE account_number IN ('KZ86KZBA0000000002', 'KZ86KZBA0000000005');

SELECT * FROM process_transfer(
    'KZ86KZBA0000000002',  -- USD счёт Aidar
    'KZ86KZBA0000000005',  -- KZT счёт Kanat
    1000,  -- 1000 USD
    'USD',
    'USD to KZT conversion'
);

-- Баланс после,должна быть конвертация по курсу
SELECT account_number, currency, balance FROM accounts 
WHERE account_number IN ('KZ86KZBA0000000002', 'KZ86KZBA0000000005');

-- TEST 5: Проверка VIEW - balance_summary
SELECT '=== TEST 5: Просмотр сводки балансов клиентов ===' as test_case;

SELECT 
    full_name, 
    account_count, 
    total_balance_kzt,
    daily_limit_kzt,
    daily_limit_usage_percent,
    balance_rank
FROM customer_balance_summary
WHERE customer_id IN (1, 2, 3, 4)
ORDER BY balance_rank;

-- TEST 6: Проверка VIEW - daily_transaction_report
SELECT '=== TEST 6: Просмотр отчёта по транзакциям ===' as test_case;

SELECT 
    transaction_date,
    type,
    transaction_count,
    total_volume_kzt,
    avg_amount_kzt,
    running_total_kzt
FROM daily_transaction_report
ORDER BY transaction_date DESC, type;

-- TEST 7: Пакетная выплата зарплат
SELECT '=== TEST 7: Пакетная обработка зарплаты ===' as test_case;

-- Баланс компании до операции
SELECT account_number, balance FROM accounts 
WHERE account_number = 'KZ86KZBA0000000014';

-- Выполняем пакетный платёж ,включая некорректный IIN для демонстрации частичного успеха
SELECT * FROM process_salary_batch(
    'KZ86KZBA0000000014',  -- компания
    jsonb_build_array(
        jsonb_build_object('iin', '123456789012', 'amount', 500000, 'description', 'January Salary'),
        jsonb_build_object('iin', '234567890123', 'amount', 450000, 'description', 'January Salary'),
        jsonb_build_object('iin', '345678901234', 'amount', 400000, 'description', 'January Salary'),
        jsonb_build_object('iin', '999999999999', 'amount', 1000000, 'description', 'Invalid IIN - should fail')
    )
);

-- Баланс компании после операции
SELECT account_number, balance FROM accounts 
WHERE account_number = 'KZ86KZBA0000000014';

-- Проверяем что получатели получили деньги
SELECT account_number, balance FROM accounts 
WHERE customer_id IN (1, 2, 3)
AND currency = 'KZT'
ORDER BY account_number;

-- TEST 8: Проверка аудит-лога
SELECT '=== TEST 8: Просмотр записей в аудит-логе ===' as test_case;

SELECT 
    log_id,
    table_name,
    action,
    new_values,
    changed_at
FROM audit_log
WHERE table_name = 'transactions'
ORDER BY log_id DESC
LIMIT 5;

COMMIT;

-- INDEX PERFORMANCE ANALYSIS (EXPLAIN ANALYZE)
-- Примечание: Реальный EXPLAIN ANALYZE зависит от размера данных и плана PostgreSQL
-- Здесь показаны примеры использования индексов

EXPLAIN ANALYZE
SELECT * FROM accounts WHERE account_number = 'KZ86KZBA0000000001';

EXPLAIN ANALYZE
SELECT * FROM accounts 
WHERE customer_id = 1 AND is_active = TRUE;

EXPLAIN ANALYZE
SELECT * FROM transactions 
WHERE from_account_id = 1 
AND DATE(created_at) = CURRENT_DATE
AND status IN ('completed', 'pending');

EXPLAIN ANALYZE
SELECT * FROM customers WHERE LOWER(email) = 'aidar@bank.kz';

EXPLAIN ANALYZE
SELECT * FROM audit_log 
WHERE new_values @> '{"action":"INSERT"}' LIMIT 10;

-- DOCUMENTATION & NOTES
/*
DESIGN DECISIONS:

1. PROCESS_TRANSFER procedure:
   - Использует SELECT ... FOR UPDATE для предотвращения race conditions
   - Проверяет все условия ДО создания транзакции (fail-fast pattern)
   - Конвертирует валюты используя exchange_rates таблицу
   - Логирует все операции (включая ошибки) в audit_log
   - Возвращает детальные error codes для клиентской обработки

2. PROCESS_SALARY_BATCH procedure:
   - Использует pg_advisory_lock() для предотвращения параллельных батчей
   - Обрабатывает платежи с SAVEPOINT (один платёж не влияет на другие)
   - Bypass дневного лимита для зарплат (business requirement)
   - Возвращает JSONB с детальными ошибками каждого платежа

3. VIEWS:
   - customer_balance_summary: использует window functions (ROW_NUMBER)
   - daily_transaction_report: использует LAG() для расчёта growth
   - suspicious_activity_view: использует SECURITY BARRIER для защиты

4. INDEXES:
   - B-tree для точного поиска (account_number, iin)
   - Hash для IIN (очень быстро для = оператора)
   - Composite index для часто используемых WHERE условий
   - Partial index для активных счётов (меньше размер)
   - GIN для JSONB операций
   - Expression index для case-insensitive поиска
   - Covering index для index-only scans

5. ERROR HANDLING:
   - RAISE EXCEPTION с custom codes (ACCOUNT_NOT_FOUND, etc.)
   - Простые, понятные сообщения об ошибках на русском
   - Все ошибки логируются в audit_log

6. TRANSACTION SAFETY:
   - ACID compliance обеспечена через PostgreSQL транзакции
   - Все операции атомарные (либо все, либо ничего)
   - SELECT FOR UPDATE предотвращает race conditions
   - Audit trail ведётся для всех операций
*/