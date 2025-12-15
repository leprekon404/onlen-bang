-- ============================================
-- ПОЛНАЯ УСТАНОВКА ONLINE BANKING DATABASE
-- Единый скрипт для установки всей системы
-- ============================================
-- Выполнять в pgAdmin Query Tool после создания БД
-- и подключения к online_banking_db
-- ============================================

\echo '========================================'
\echo 'Начало установки Online Banking DB'
\echo '========================================'

-- ============================================
-- 1. СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ
-- ============================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'banking_app_user') THEN
    CREATE USER banking_app_user WITH PASSWORD 'SecureP@ssw0rd2025!';
    RAISE NOTICE '✅ Пользователь banking_app_user создан';
  ELSE
    RAISE NOTICE '⚠️ Пользователь banking_app_user уже существует';
  END IF;
END
$$;

-- Выдача прав
GRANT ALL PRIVILEGES ON DATABASE online_banking_db TO banking_app_user;
ALTER DATABASE online_banking_db OWNER TO banking_app_user;
GRANT ALL ON SCHEMA public TO banking_app_user;

-- ============================================
-- 2. ОСНОВНЫЕ ТАБЛИЦЫ
-- ============================================

DROP TABLE IF EXISTS biometric_credentials CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Таблица пользователей
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

-- Таблица счетов
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
  CONSTRAINT fk_accounts_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX idx_user_id ON accounts(user_id);
CREATE INDEX idx_account_number ON accounts(account_number);

-- Таблица транзакций
CREATE TABLE transactions (
  transaction_id BIGSERIAL PRIMARY KEY,
  from_account_id BIGINT,
  to_account_id BIGINT,
  amount DECIMAL(15,2) NOT NULL,
  transaction_type VARCHAR(50) NOT NULL,
  description VARCHAR(255),
  status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tx_from FOREIGN KEY (from_account_id) REFERENCES accounts(account_id) ON DELETE SET NULL,
  CONSTRAINT fk_tx_to FOREIGN KEY (to_account_id) REFERENCES accounts(account_id) ON DELETE SET NULL
);

CREATE INDEX idx_from_account ON transactions(from_account_id);
CREATE INDEX idx_to_account ON transactions(to_account_id);
CREATE INDEX idx_created_at ON transactions(created_at);

-- Таблица биометрии
CREATE TABLE biometric_credentials (
  credential_id VARCHAR(255) PRIMARY KEY,
  user_id BIGINT NOT NULL,
  public_key TEXT,
  counter INTEGER NOT NULL DEFAULT 0,
  device_name VARCHAR(100),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used TIMESTAMP,
  CONSTRAINT fk_bio_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX idx_bio_user ON biometric_credentials(user_id);

DO $$ BEGIN RAISE NOTICE '✅ Основные таблицы созданы'; END $$;

-- ============================================
-- 3. МОДУЛЬ АНАЛИТИКИ
-- ============================================

-- Категории транзакций
CREATE TABLE IF NOT EXISTS transaction_categories (
  category_id SERIAL PRIMARY KEY,
  category_name VARCHAR(100) NOT NULL,
  category_type VARCHAR(10) NOT NULL CHECK (category_type IN ('income', 'expense')),
  icon VARCHAR(50),
  color VARCHAR(7),
  parent_category_id INTEGER,
  is_system BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_parent_category FOREIGN KEY (parent_category_id) REFERENCES transaction_categories(category_id) ON DELETE SET NULL
);

CREATE INDEX idx_category_type ON transaction_categories(category_type);
CREATE INDEX idx_parent_category ON transaction_categories(parent_category_id);

-- Связь транзакций с категориями
CREATE TABLE IF NOT EXISTS transaction_category_mapping (
  mapping_id BIGSERIAL PRIMARY KEY,
  transaction_id BIGINT NOT NULL,
  category_id INTEGER NOT NULL,
  assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  assigned_by VARCHAR(10) NOT NULL DEFAULT 'user' CHECK (assigned_by IN ('user', 'system', 'ai')),
  CONSTRAINT fk_mapping_transaction FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id) ON DELETE CASCADE,
  CONSTRAINT fk_mapping_category FOREIGN KEY (category_id) REFERENCES transaction_categories(category_id) ON DELETE CASCADE,
  CONSTRAINT uniq_transaction_category UNIQUE (transaction_id)
);

CREATE INDEX idx_mapping_category ON transaction_category_mapping(category_id);

-- Бюджеты пользователей
CREATE TABLE IF NOT EXISTS budgets (
  budget_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  category_id INTEGER,
  budget_name VARCHAR(100) NOT NULL,
  budget_amount DECIMAL(15,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'RUB',
  period_type VARCHAR(10) NOT NULL DEFAULT 'monthly' CHECK (period_type IN ('daily', 'weekly', 'monthly', 'yearly')),
  start_date DATE NOT NULL,
  end_date DATE,
  alert_threshold DECIMAL(5,2),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_budget_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_budget_category FOREIGN KEY (category_id) REFERENCES transaction_categories(category_id) ON DELETE SET NULL
);

CREATE INDEX idx_budget_user ON budgets(user_id);
CREATE INDEX idx_budget_dates ON budgets(start_date, end_date);
CREATE INDEX idx_budget_category ON budgets(category_id);

-- Триггер для автообновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = CURRENT_TIMESTAMP;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_budgets_updated_at BEFORE UPDATE ON budgets
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Финансовые цели
CREATE TABLE IF NOT EXISTS financial_goals (
  goal_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  goal_name VARCHAR(200) NOT NULL,
  goal_description TEXT,
  target_amount DECIMAL(15,2) NOT NULL,
  current_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
  currency CHAR(3) NOT NULL DEFAULT 'RUB',
  target_date DATE,
  priority VARCHAR(10) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_goal_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX idx_goal_user ON financial_goals(user_id);
CREATE INDEX idx_goal_status ON financial_goals(is_completed);

CREATE TRIGGER update_financial_goals_updated_at BEFORE UPDATE ON financial_goals
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Кэш аналитических данных
CREATE TABLE IF NOT EXISTS analytics_cache (
  cache_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  cache_key VARCHAR(100) NOT NULL,
  cache_data JSONB NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  CONSTRAINT fk_cache_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT uniq_user_cache UNIQUE (user_id, cache_key, period_start, period_end)
);

CREATE INDEX idx_cache_expires ON analytics_cache(expires_at);

DO $$ BEGIN RAISE NOTICE '✅ Модуль аналитики создан'; END $$;

-- ============================================
-- 4. МОДУЛЬ УВЕДОМЛЕНИЙ
-- ============================================

-- Типы уведомлений
CREATE TABLE IF NOT EXISTS notification_types (
  type_id SERIAL PRIMARY KEY,
  type_code VARCHAR(50) NOT NULL UNIQUE,
  type_name VARCHAR(100) NOT NULL,
  description TEXT,
  category VARCHAR(20) NOT NULL CHECK (category IN ('transaction', 'security', 'service', 'marketing', 'system')),
  default_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  requires_confirmation BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Настройки уведомлений пользователя
CREATE TABLE IF NOT EXISTS user_notification_settings (
  setting_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  notification_type_code VARCHAR(50) NOT NULL,
  email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  sms_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  min_amount DECIMAL(15,2),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notification_settings_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT uniq_user_notification UNIQUE (user_id, notification_type_code)
);

CREATE INDEX idx_notification_settings_user ON user_notification_settings(user_id);

CREATE TRIGGER update_user_notification_settings_updated_at BEFORE UPDATE ON user_notification_settings
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Журнал уведомлений
CREATE TABLE IF NOT EXISTS notifications (
  notification_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  notification_type_code VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  priority VARCHAR(10) NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  email_status VARCHAR(10) CHECK (email_status IN ('pending', 'sent', 'failed', 'skipped')),
  email_sent_at TIMESTAMP,
  email_error TEXT,
  sms_status VARCHAR(10) CHECK (sms_status IN ('pending', 'sent', 'failed', 'skipped')),
  sms_sent_at TIMESTAMP,
  sms_error TEXT,
  push_status VARCHAR(10) CHECK (push_status IN ('pending', 'sent', 'failed', 'skipped')),
  push_sent_at TIMESTAMP,
  push_error TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_created ON notifications(created_at);
CREATE INDEX idx_notifications_read ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_type ON notifications(notification_type_code);

-- Устройства для push-уведомлений
CREATE TABLE IF NOT EXISTS user_devices (
  device_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  device_token VARCHAR(255) NOT NULL,
  device_type VARCHAR(10) NOT NULL CHECK (device_type IN ('ios', 'android', 'web')),
  device_name VARCHAR(100),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_active_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_devices_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT uniq_device_token UNIQUE (device_token)
);

CREATE INDEX idx_devices_user ON user_devices(user_id);

-- Шаблоны уведомлений
CREATE TABLE IF NOT EXISTS notification_templates (
  template_id SERIAL PRIMARY KEY,
  notification_type_code VARCHAR(50) NOT NULL,
  channel VARCHAR(10) NOT NULL CHECK (channel IN ('email', 'sms', 'push')),
  language CHAR(2) NOT NULL DEFAULT 'ru',
  subject VARCHAR(255),
  body_template TEXT NOT NULL,
  variables JSONB,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uniq_template UNIQUE (notification_type_code, channel, language)
);

CREATE TRIGGER update_notification_templates_updated_at BEFORE UPDATE ON notification_templates
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DO $$ BEGIN RAISE NOTICE '✅ Модуль уведомлений создан'; END $$;

-- ============================================
-- 5. МОДУЛЬ ПЛАТЕЖЕЙ
-- ============================================

-- Таблица шаблонов платежей
CREATE TABLE IF NOT EXISTS payment_templates (
  template_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  template_name VARCHAR(100) NOT NULL,
  template_data JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used TIMESTAMP,
  CONSTRAINT fk_template_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX idx_template_user ON payment_templates(user_id);

-- Таблица автоплатежей
CREATE TABLE IF NOT EXISTS auto_payments (
  auto_payment_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  template_id BIGINT NOT NULL,
  frequency VARCHAR(10) NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
  next_execution_date DATE NOT NULL,
  last_execution_date TIMESTAMP,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_autopay_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_autopay_template FOREIGN KEY (template_id) REFERENCES payment_templates(template_id) ON DELETE CASCADE
);

CREATE INDEX idx_autopay_user ON auto_payments(user_id);
CREATE INDEX idx_autopay_next_date ON auto_payments(next_execution_date, is_active);

-- Таблица для внешних API ключей
CREATE TABLE IF NOT EXISTS external_api_keys (
  api_key_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  api_key VARCHAR(64) NOT NULL UNIQUE,
  api_name VARCHAR(100) NOT NULL,
  permissions JSONB NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  last_used TIMESTAMP,
  CONSTRAINT fk_apikey_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX idx_apikey ON external_api_keys(api_key);
CREATE INDEX idx_apikey_user ON external_api_keys(user_id);

-- Логирование внешних API запросов
CREATE TABLE IF NOT EXISTS api_request_logs (
  log_id BIGSERIAL PRIMARY KEY,
  api_key_id BIGINT NOT NULL,
  endpoint VARCHAR(255) NOT NULL,
  method VARCHAR(10) NOT NULL,
  request_data JSONB,
  response_status INTEGER NOT NULL,
  ip_address VARCHAR(45) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_apilog_key FOREIGN KEY (api_key_id) REFERENCES external_api_keys(api_key_id) ON DELETE CASCADE
);

CREATE INDEX idx_apilog_key ON api_request_logs(api_key_id);
CREATE INDEX idx_apilog_date ON api_request_logs(created_at);

DO $$ BEGIN RAISE NOTICE '✅ Модуль платежей создан'; END $$;

-- ============================================
-- 6. ТЕСТОВЫЕ ДАННЫЕ
-- ============================================

-- Пользователи
INSERT INTO users (username, email, password_hash, full_name, phone_number) VALUES
  ('ivanov', 'ivanov@bank.ru', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIVj7rWXKy', 'Иванов Иван Иванович', '+7 900 123-45-67'),
  ('petrov', 'petrov@bank.ru', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIVj7rWXKy', 'Петров Пётр Петрович', '+7 900 234-56-78'),
  ('sidorov', 'sidorov@bank.ru', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYIVj7rWXKy', 'Сидоров Сидор Сидорович', '+7 900 345-67-89');

-- Счета
INSERT INTO accounts (user_id, account_number, account_type, balance, currency) VALUES
  (1, '4276123456789012', 'debit', 150000.00, 'RUB'),
  (2, '4276555512349876', 'debit', 75000.00, 'RUB'),
  (2, '4276555598765432', 'savings', 25000.00, 'RUB'),
  (3, '4276444498761234', 'debit', 25000.00, 'RUB');

-- Транзакции
INSERT INTO transactions (from_account_id, to_account_id, amount, transaction_type, description) VALUES
  (2, 3, 1000.00, 'transfer', 'Тестовый перевод с карты 1 на карту 2'),
  (3, 2, 500.00, 'transfer', 'Тестовый перевод с карты 2 на карту 1');

UPDATE users SET password_hash = '$2a$12$GyOhDSSummiqMgt8fcTJaOE615OvmwmKgJ59bg2D0nGu1FRxIR3/e' WHERE username = 'petrov';

-- Категории расходов
INSERT INTO transaction_categories (category_name, category_type, icon, color, is_system) VALUES
  ('Продукты', 'expense', '🛒', '#FF6B6B', TRUE),
  ('Транспорт', 'expense', '🚗', '#4ECDC4', TRUE),
  ('Коммунальные услуги', 'expense', '🏠', '#45B7D1', TRUE),
  ('Развлечения', 'expense', '🎬', '#FFA07A', TRUE),
  ('Здоровье', 'expense', '💊', '#98D8C8', TRUE),
  ('Образование', 'expense', '📚', '#6C5CE7', TRUE),
  ('Одежда', 'expense', '👔', '#A29BFE', TRUE),
  ('Рестораны и кафе', 'expense', '🍽️', '#FD79A8', TRUE),
  ('Связь', 'expense', '📱', '#FDCB6E', TRUE),
  ('Подписки', 'expense', '💳', '#E17055', TRUE),
  ('Прочие расходы', 'expense', '📦', '#B2BEC3', TRUE);

-- Категории доходов
INSERT INTO transaction_categories (category_name, category_type, icon, color, is_system) VALUES
  ('Зарплата', 'income', '💰', '#00B894', TRUE),
  ('Фриланс', 'income', '💼', '#00CEC9', TRUE),
  ('Инвестиции', 'income', '📈', '#6C5CE7', TRUE),
  ('Подарки', 'income', '🎁', '#FD79A8', TRUE),
  ('Возврат средств', 'income', '↩️', '#FDCB6E', TRUE),
  ('Прочие доходы', 'income', '💵', '#55EFC4', TRUE);

-- Типы уведомлений
INSERT INTO notification_types (type_code, type_name, description, category, default_enabled, requires_confirmation) VALUES
  ('TRANSACTION_COMPLETED', 'Транзакция выполнена', 'Уведомление о завершении транзакции', 'transaction', TRUE, FALSE),
  ('TRANSACTION_FAILED', 'Ошибка транзакции', 'Уведомление о неудачной транзакции', 'transaction', TRUE, FALSE),
  ('LARGE_TRANSACTION', 'Крупная транзакция', 'Уведомление о крупной сумме', 'security', TRUE, FALSE),
  ('LOW_BALANCE', 'Низкий баланс', 'Баланс счета ниже порога', 'transaction', TRUE, FALSE),
  ('LOGIN_SUCCESS', 'Успешный вход', 'Вход в систему выполнен', 'security', TRUE, FALSE),
  ('LOGIN_FAILED', 'Неудачная попытка входа', 'Несколько неудачных попыток входа', 'security', TRUE, FALSE),
  ('PASSWORD_CHANGED', 'Пароль изменен', 'Пароль учетной записи изменен', 'security', TRUE, TRUE),
  ('NEW_DEVICE', 'Новое устройство', 'Вход с нового устройства', 'security', TRUE, FALSE);

DO $$ BEGIN RAISE NOTICE '✅ Тестовые данные загружены'; END $$;

-- ============================================
-- 7. ФИНАЛЬНЫЕ ПРАВА
-- ============================================

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO banking_app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO banking_app_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO banking_app_user;

-- ============================================
-- ИТОГОВАЯ ИНФОРМАЦИЯ
-- ============================================

DO $$
DECLARE
  users_count INT;
  accounts_count INT;
  transactions_count INT;
  tables_count INT;
BEGIN
  SELECT COUNT(*) INTO users_count FROM users;
  SELECT COUNT(*) INTO accounts_count FROM accounts;
  SELECT COUNT(*) INTO transactions_count FROM transactions;
  SELECT COUNT(*) INTO tables_count FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Создано таблиц: %', tables_count;
  RAISE NOTICE 'Пользователей: %', users_count;
  RAISE NOTICE 'Счетов: %', accounts_count;
  RAISE NOTICE 'Транзакций: %', transactions_count;
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Тестовые аккаунты:';
  RAISE NOTICE '  • ivanov  / Password123!';
  RAISE NOTICE '  • petrov  / Password123!';
  RAISE NOTICE '  • sidorov / Password123!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'База данных готова к использованию!';
  RAISE NOTICE '========================================';
END
$$;
