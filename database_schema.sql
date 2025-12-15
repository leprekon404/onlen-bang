-- ============================================
-- database_schema_full.sql для online-banking-simple
-- (PostgreSQL версия)
-- ============================================

-- 1. БАЗА ДАННЫХ

CREATE DATABASE online_banking_db
  WITH ENCODING='UTF8'
       LC_COLLATE='ru_RU.UTF-8'
       LC_CTYPE='ru_RU.UTF-8'
       TEMPLATE=template0;

\c online_banking_db;

-- 2. ПОЛЬЗОВАТЕЛЬ ДЛЯ ПРИЛОЖЕНИЯ

DROP USER IF EXISTS banking_app_user;
CREATE USER banking_app_user WITH PASSWORD 'SecureP@ssw0rd2025!';
GRANT ALL PRIVILEGES ON DATABASE online_banking_db TO banking_app_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO banking_app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO banking_app_user;

-- 3. ОЧИСТКА ТАБЛИЦ (можно запускать скрипт повторно)

DROP TABLE IF EXISTS biometric_credentials CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 4. ТАБЛИЦА ПОЛЬЗОВАТЕЛЕЙ

CREATE TABLE users (
  user_id BIGSERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  email VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(100),
  phone_number VARCHAR(20),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_locked BOOLEAN NOT NULL DEFAULT FALSE,
  failed_login_attempts INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP
);

CREATE INDEX idx_username ON users(username);
CREATE INDEX idx_email ON users(email);

-- 5. ТАБЛИЦА СЧЕТОВ / КАРТ

CREATE TABLE accounts (
  account_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  account_number VARCHAR(20) NOT NULL UNIQUE,
  account_type VARCHAR(20) NOT NULL DEFAULT 'debit' CHECK (account_type IN ('debit', 'credit', 'savings')),
  balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  currency VARCHAR(3) NOT NULL DEFAULT 'RUB',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  daily_limit DECIMAL(15,2),
  is_frozen BOOLEAN NOT NULL DEFAULT FALSE,
  pin_hash VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_accounts_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE
);

CREATE INDEX idx_user_id ON accounts(user_id);
CREATE INDEX idx_account_number ON accounts(account_number);

-- 6. ТАБЛИЦА ТРАНЗАКЦИЙ

CREATE TABLE transactions (
  transaction_id BIGSERIAL PRIMARY KEY,
  from_account_id BIGINT,
  to_account_id BIGINT,
  amount DECIMAL(15,2) NOT NULL,
  transaction_type VARCHAR(50) NOT NULL,
  description VARCHAR(255),
  status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tx_from
    FOREIGN KEY (from_account_id) REFERENCES accounts(account_id)
    ON DELETE SET NULL,
  CONSTRAINT fk_tx_to
    FOREIGN KEY (to_account_id) REFERENCES accounts(account_id)
    ON DELETE SET NULL
);

CREATE INDEX idx_from_account ON transactions(from_account_id);
CREATE INDEX idx_to_account ON transactions(to_account_id);
CREATE INDEX idx_created_at ON transactions(created_at);

-- 7. ТАБЛИЦА БИОМЕТРИИ (на будущее)

CREATE TABLE biometric_credentials (
  credential_id VARCHAR(255) PRIMARY KEY,
  user_id BIGINT NOT NULL,
  public_key TEXT,
  counter INTEGER NOT NULL DEFAULT 0,
  device_name VARCHAR(100),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used TIMESTAMP,
  CONSTRAINT fk_bio_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE
);

CREATE INDEX idx_bio_user ON biometric_credentials(user_id);

-- 8. ТЕСТОВЫЕ ПОЛЬЗОВАТЕЛИ
-- Пароль: Password123! (bcrypt-хеш уже готов)

INSERT INTO users (username, email, password_hash, full_name, phone_number) VALUES
  ('ivanov', 'ivanov@bank.ru',
   '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIVj7rWXKy',
   'Иванов Иван Иванович', '+7 900 123-45-67'),
  ('petrov', 'petrov@bank.ru',
   '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIVj7rWXKy',
   'Петров Пётр Петрович', '+7 900 234-56-78'),
  ('sidorov', 'sidorov@bank.ru',
   '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIVj7rWXKy',
   'Сидоров Сидор Сидорович', '+7 900 345-67-89');

-- 9. ТЕСТОВЫЕ СЧЕТА / КАРТЫ
-- У Петрова (user_id = 2) сразу две карты.

INSERT INTO accounts (user_id, account_number, account_type, balance, currency) VALUES
  (1, '4276123456789012', 'debit',   150000.00, 'RUB'),
  (2, '4276555512349876', 'debit',    75000.00, 'RUB'),
  (2, '4276555598765432', 'savings',  25000.00, 'RUB'),
  (3, '4276444498761234', 'debit',    25000.00, 'RUB');

-- 10. ТЕСТОВЫЕ ТРАНЗАКЦИИ
-- Примеры переводов между картами Петрова.

INSERT INTO transactions (from_account_id, to_account_id, amount, transaction_type, description) VALUES
  (2, 3, 1000.00, 'transfer', 'Тестовый перевод с карты 1 на карту 2'),
  (3, 2,  500.00, 'transfer', 'Тестовый перевод с карты 2 на карту 1');

-- 11. ПРОВЕРКА

DO $$
BEGIN
  RAISE NOTICE '✅ online_banking_db создана';
END $$;

SELECT COUNT(*) AS users_count FROM users;
SELECT COUNT(*) AS accounts_count FROM accounts;
SELECT COUNT(*) AS tx_count FROM transactions;

-- Обновлённый пароль только для petrov

UPDATE users
SET password_hash = '$2a$12$GyOhDSSummiqMgt8fcTJaOE615OvmwmKgJ59bg2D0nGu1FRxIR3/e'
WHERE username = 'petrov';

-- Права для banking_app_user на новые таблицы
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO banking_app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO banking_app_user;
