-- ============================================
-- database_schema_init.sql для online-banking-simple
-- (PostgreSQL версия - создание БД и пользователя)
-- Выполнять от имени суперпользователя (postgres)
-- ============================================

-- 1. БАЗА ДАННЫХ

DROP DATABASE IF EXISTS online_banking_db;
CREATE DATABASE online_banking_db
  WITH ENCODING='UTF8'
       LC_COLLATE='ru_RU.UTF-8'
       LC_CTYPE='ru_RU.UTF-8'
       TEMPLATE=template0;

-- 2. ПОЛЬЗОВАТЕЛЬ ДЛЯ ПРИЛОЖЕНИЯ

DROP USER IF EXISTS banking_app_user;
CREATE USER banking_app_user WITH PASSWORD 'SecureP@ssw0rd2025!';
GRANT ALL PRIVILEGES ON DATABASE online_banking_db TO banking_app_user;
GRANT USAGE, CREATE ON SCHEMA public TO banking_app_user;

DO $$
BEGIN
  RAISE NOTICE '✅ База данных online_banking_db и пользователь banking_app_user созданы';
  RAISE NOTICE 'Теперь подключитесь к базе: \c online_banking_db';
  RAISE NOTICE 'И выполните: database_schema.sql';
END $$;
