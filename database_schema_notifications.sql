-- ============================================
-- МОДУЛЬ УВЕДОМЛЕНИЙ
-- (PostgreSQL версия)
-- Выполнять после database_schema.sql
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
  
  -- Каналы доставки
  email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  sms_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  
  -- Пороги для уведомлений о транзакциях
  min_amount DECIMAL(15,2),
  
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_notification_settings_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE,
  
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
  
  -- Содержание
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  data JSONB,
  
  -- Приоритет
  priority VARCHAR(10) NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  
  -- Статусы доставки
  email_status VARCHAR(10) CHECK (email_status IN ('pending', 'sent', 'failed', 'skipped')),
  email_sent_at TIMESTAMP,
  email_error TEXT,
  
  sms_status VARCHAR(10) CHECK (sms_status IN ('pending', 'sent', 'failed', 'skipped')),
  sms_sent_at TIMESTAMP,
  sms_error TEXT,
  
  push_status VARCHAR(10) CHECK (push_status IN ('pending', 'sent', 'failed', 'skipped')),
  push_sent_at TIMESTAMP,
  push_error TEXT,
  
  -- Прочитано пользователем
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TIMESTAMP,
  
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  
  CONSTRAINT fk_notifications_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE
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
  
  CONSTRAINT fk_devices_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE,
  
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
  
  -- Переменные шаблона в формате JSON
  variables JSONB,
  
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT uniq_template UNIQUE (notification_type_code, channel, language)
);

CREATE TRIGGER update_notification_templates_updated_at BEFORE UPDATE ON notification_templates
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- НАЧАЛЬНЫЕ ДАННЫЕ
-- ============================================

-- Типы уведомлений
INSERT INTO notification_types (type_code, type_name, description, category, default_enabled, requires_confirmation)
VALUES
  ('TRANSACTION_COMPLETED', 'Транзакция выполнена', 'Уведомление о завершении транзакции', 'transaction', TRUE, FALSE),
  ('TRANSACTION_FAILED', 'Ошибка транзакции', 'Уведомление о неудачной транзакции', 'transaction', TRUE, FALSE),
  ('LARGE_TRANSACTION', 'Крупная транзакция', 'Уведомление о крупной сумме', 'security', TRUE, FALSE),
  ('LOW_BALANCE', 'Низкий баланс', 'Баланс счета ниже порога', 'transaction', TRUE, FALSE),
  
  ('LOGIN_SUCCESS', 'Успешный вход', 'Вход в систему выполнен', 'security', TRUE, FALSE),
  ('LOGIN_FAILED', 'Неудачная попытка входа', 'Несколько неудачных попыток входа', 'security', TRUE, FALSE),
  ('PASSWORD_CHANGED', 'Пароль изменен', 'Пароль учетной записи изменен', 'security', TRUE, TRUE),
  ('NEW_DEVICE', 'Новое устройство', 'Вход с нового устройства', 'security', TRUE, FALSE),
  
  ('ACCOUNT_FROZEN', 'Счет заморожен', 'Счет был заморожен', 'security', TRUE, TRUE),
  ('ACCOUNT_UNFROZEN', 'Счет разморожен', 'Счет был разморожен', 'security', TRUE, FALSE),
  ('CARD_BLOCKED', 'Карта заблокирована', 'Карта была заблокирована', 'security', TRUE, TRUE),
  
  ('SERVICE_UPDATE', 'Обновление сервиса', 'Изменения в условиях предоставления услуг', 'service', TRUE, FALSE),
  ('SCHEDULED_MAINTENANCE', 'Плановые работы', 'Плановое техническое обслуживание', 'service', TRUE, FALSE),
  
  ('PROMOTIONAL_OFFER', 'Специальное предложение', 'Акции и специальные предложения', 'marketing', FALSE, FALSE),
  ('NEWS_UPDATE', 'Новости банка', 'Новости и обновления', 'marketing', FALSE, FALSE)
ON CONFLICT (type_code) DO UPDATE SET type_name = EXCLUDED.type_name;

-- Шаблоны email
INSERT INTO notification_templates (notification_type_code, channel, language, subject, body_template, variables)
VALUES
  ('TRANSACTION_COMPLETED', 'email', 'ru', 'Транзакция выполнена', 
   'Здравствуйте, {{user_name}}!

Ваша транзакция успешно выполнена:

Сумма: {{amount}} {{currency}}
Тип: {{transaction_type}}
Описание: {{description}}
Дата: {{date}}

С уважением,
Команда Online Banking',
   '{"user_name": "string", "amount": "number", "currency": "string", "transaction_type": "string", "description": "string", "date": "string"}'),
  
  ('LOW_BALANCE', 'email', 'ru', 'Низкий баланс счета',
   'Здравствуйте, {{user_name}}!

Баланс вашего счета {{account_number}} опустился ниже установленного порога.

Текущий баланс: {{balance}} {{currency}}

Пожалуйста, пополните счет, чтобы избежать проблем с платежами.

С уважением,
Команда Online Banking',
   '{"user_name": "string", "account_number": "string", "balance": "number", "currency": "string"}'),
  
  ('PASSWORD_CHANGED', 'email', 'ru', 'Пароль изменен',
   'Здравствуйте, {{user_name}}!

Пароль вашей учетной записи был изменен {{date}}.

Если это были не вы, немедленно свяжитесь с нами по телефону горячей линии.

С уважением,
Команда Online Banking',
   '{"user_name": "string", "date": "string"}'),
   
  ('NEW_DEVICE', 'email', 'ru', 'Вход с нового устройства',
   'Здравствуйте, {{user_name}}!

Зафиксирован вход в вашу учетную запись с нового устройства:

Устройство: {{device_name}}
IP-адрес: {{ip_address}}
Дата: {{date}}

Если это были не вы, немедленно измените пароль и свяжитесь с нами.

С уважением,
Команда Online Banking',
   '{"user_name": "string", "device_name": "string", "ip_address": "string", "date": "string"}')
ON CONFLICT ON CONSTRAINT uniq_template DO UPDATE SET body_template = EXCLUDED.body_template;

-- Шаблоны SMS
INSERT INTO notification_templates (notification_type_code, channel, language, subject, body_template, variables)
VALUES
  ('TRANSACTION_COMPLETED', 'sms', 'ru', NULL,
   'Транзакция {{amount}} {{currency}} выполнена. {{description}}. Online Banking',
   '{"amount": "number", "currency": "string", "description": "string"}'),
  
  ('LOW_BALANCE', 'sms', 'ru', NULL,
   'Низкий баланс счета {{account_number}}: {{balance}} {{currency}}. Пополните счет. Online Banking',
   '{"account_number": "string", "balance": "number", "currency": "string"}'),
  
  ('PASSWORD_CHANGED', 'sms', 'ru', NULL,
   'Пароль изменен. Если это не вы, срочно свяжитесь с нами. Online Banking',
   '{}')
ON CONFLICT ON CONSTRAINT uniq_template DO UPDATE SET body_template = EXCLUDED.body_template;

-- Шаблоны push
INSERT INTO notification_templates (notification_type_code, channel, language, subject, body_template, variables)
VALUES
  ('TRANSACTION_COMPLETED', 'push', 'ru', 'Транзакция выполнена',
   'Транзакция {{amount}} {{currency}} успешно выполнена',
   '{"amount": "number", "currency": "string"}'),
  
  ('LOW_BALANCE', 'push', 'ru', 'Низкий баланс',
   'Баланс счета {{account_number}}: {{balance}} {{currency}}',
   '{"account_number": "string", "balance": "number", "currency": "string"}'),
  
  ('NEW_DEVICE', 'push', 'ru', 'Новое устройство',
   'Зафиксирован вход с нового устройства',
   '{}')
ON CONFLICT ON CONSTRAINT uniq_template DO UPDATE SET body_template = EXCLUDED.body_template;

DO $$
BEGIN
  RAISE NOTICE '✅ Таблицы модуля уведомлений созданы';
END $$;

-- Права для banking_app_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO banking_app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO banking_app_user;
