-- ============================================
-- РАСШИРЕНИЕ СХЕМЫ БД ДЛЯ МОДУЛЯ ПЛАТЕЖЕЙ
-- (PostgreSQL версия)
-- Выполнять после database_schema.sql
-- ============================================

-- Таблица шаблонов платежей
CREATE TABLE IF NOT EXISTS payment_templates (
  template_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  template_name VARCHAR(100) NOT NULL,
  template_data JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used TIMESTAMP,
  CONSTRAINT fk_template_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE
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
  CONSTRAINT fk_autopay_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE,
  CONSTRAINT fk_autopay_template
    FOREIGN KEY (template_id) REFERENCES payment_templates(template_id)
    ON DELETE CASCADE
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
  CONSTRAINT fk_apikey_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE
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
  CONSTRAINT fk_apilog_key
    FOREIGN KEY (api_key_id) REFERENCES external_api_keys(api_key_id)
    ON DELETE CASCADE
);

CREATE INDEX idx_apilog_key ON api_request_logs(api_key_id);
CREATE INDEX idx_apilog_date ON api_request_logs(created_at);

-- Проверка успешного создания
DO $$
BEGIN
  RAISE NOTICE '✅ Таблицы для модуля платежей созданы';
END $$;

-- Права для banking_app_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO banking_app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO banking_app_user;
