-- ============================================
-- МОДУЛЬ АНАЛИТИКИ И ПЛАНИРОВАНИЯ БЮДЖЕТА
-- (PostgreSQL версия)
-- ============================================

\c online_banking_db;

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
  
  CONSTRAINT fk_parent_category
    FOREIGN KEY (parent_category_id) REFERENCES transaction_categories(category_id)
    ON DELETE SET NULL
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
  
  CONSTRAINT fk_mapping_transaction
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
    ON DELETE CASCADE,
  
  CONSTRAINT fk_mapping_category
    FOREIGN KEY (category_id) REFERENCES transaction_categories(category_id)
    ON DELETE CASCADE,
  
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
  
  CONSTRAINT fk_budget_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE,
  
  CONSTRAINT fk_budget_category
    FOREIGN KEY (category_id) REFERENCES transaction_categories(category_id)
    ON DELETE SET NULL
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
  
  CONSTRAINT fk_goal_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE
);

CREATE INDEX idx_goal_user ON financial_goals(user_id);
CREATE INDEX idx_goal_status ON financial_goals(is_completed);

CREATE TRIGGER update_financial_goals_updated_at BEFORE UPDATE ON financial_goals
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Кэш аналитических данных для быстрого доступа
CREATE TABLE IF NOT EXISTS analytics_cache (
  cache_id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  cache_key VARCHAR(100) NOT NULL,
  cache_data JSONB NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  
  CONSTRAINT fk_cache_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE,
  
  CONSTRAINT uniq_user_cache UNIQUE (user_id, cache_key, period_start, period_end)
);

CREATE INDEX idx_cache_expires ON analytics_cache(expires_at);

-- ============================================
-- НАЧАЛЬНЫЕ ДАННЫЕ
-- ============================================

-- Стандартные категории расходов
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
  ('Прочие расходы', 'expense', '📦', '#B2BEC3', TRUE)
ON CONFLICT DO NOTHING;

-- Стандартные категории доходов
INSERT INTO transaction_categories (category_name, category_type, icon, color, is_system) VALUES
  ('Зарплата', 'income', '💰', '#00B894', TRUE),
  ('Фриланс', 'income', '💼', '#00CEC9', TRUE),
  ('Инвестиции', 'income', '📈', '#6C5CE7', TRUE),
  ('Подарки', 'income', '🎁', '#FD79A8', TRUE),
  ('Возврат средств', 'income', '↩️', '#FDCB6E', TRUE),
  ('Прочие доходы', 'income', '💵', '#55EFC4', TRUE)
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  RAISE NOTICE '✅ Таблицы модуля аналитики созданы';
END $$;

-- Права для banking_app_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO banking_app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO banking_app_user;
