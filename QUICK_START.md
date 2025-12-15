# Quick Start Guide

## Быстрый старт для разработчиков

### Prerequisites

✅ Node.js 16+  
✅ PostgreSQL 13+  
✅ Git  

### 1️⃣ Клонирование и установка (2 минуты)

```bash
git clone https://github.com/leprekon404/onlen-bang.git
cd onlen-bang
npm install
```

### 2️⃣ Настройка окружения (1 минута)

```bash
cp .env.example .env
```

Отредактируйте `.env` - укажите пароль PostgreSQL:

```env
DB_PASSWORD=ваш_пароль_postgres
```

### 3️⃣ База данных (5 минут)

#### Вариант A: Автоматически (если psql в PATH)

```bash
npm run db:setup
```

#### Вариант B: Через pgAdmin (рекомендуется для Windows)

1. Откройте **pgAdmin**
2. Подключитесь к серверу PostgreSQL
3. Кликните правой кнопкой на `Databases` → `Create` → `Database`
4. Имя: `online_banking_db`
5. Откройте **Query Tool** (иконка молнии)
6. Выполните файлы в порядке:
   - `database_schema_init.sql` (создание пользователя)
   - `database_schema.sql` (основные таблицы)
   - `database_schema_analytics.sql` (аналитика)
   - `database_schema_notifications.sql` (уведомления)
   - `database_schema_payments.sql` (платежи)

#### Вариант C: Через командную строку

```bash
# Windows (PowerShell)
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -f database_schema_init.sql
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -d online_banking_db -f database_schema.sql
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -d online_banking_db -f database_schema_analytics.sql
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -d online_banking_db -f database_schema_notifications.sql
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -d online_banking_db -f database_schema_payments.sql

# Linux/Mac
psql -U postgres -f database_schema_init.sql
psql -U postgres -d online_banking_db -f database_schema.sql
psql -U postgres -d online_banking_db -f database_schema_analytics.sql
psql -U postgres -d online_banking_db -f database_schema_notifications.sql
psql -U postgres -d online_banking_db -f database_schema_payments.sql
```

### 4️⃣ Запуск приложения (30 секунд)

```bash
npm run dev
```

**Готово!** 🎉 Откройте браузер: http://localhost:3000

### 5️⃣ Тестовые аккаунты

| Пользователь | Пароль | Баланс |
|-------------|---------|--------|
| ivanov | Password123! | 150,000₽ |
| petrov | Password123! | 100,000₽ (2 карты) |
| sidorov | Password123! | 25,000₽ |

## Что дальше?

### Структура проекта

```
📁 backend/
  ├── config/      # Конфигурация БД
  ├── routes/      # API endpoints
  ├── middleware/  # Авторизация, валидация
  └── services/    # Бизнес-логика
📁 frontend/       # HTML/CSS/JS
📄 database_*.sql  # Схемы БД
```

### Полезные команды

```bash
# Разработка с auto-reload
npm run dev

# Production запуск
npm start

# Проверка подключения к БД
node test-db.js

# Генерация password hash
node gen-hash.js
```

### API Documentation

После запуска доступно:
- 🏠 Главная: http://localhost:3000
- 🔐 API Auth: http://localhost:3000/api/auth/login
- 📊 Admin Panel: http://localhost:3000/admin.html
- 📡 API Status: http://localhost:3000/api/external/status

### Troubleshooting

**Ошибка подключения к БД?**
1. Проверьте PostgreSQL запущен
2. Проверьте пароль в `.env`
3. Убедитесь что БД создана

**Порт 3000 занят?**
Измените `PORT=3001` в `.env`

**Ошибка "роль не существует"?**
Выполните `database_schema_init.sql` первым

## Дополнительная информация

📖 Полная документация: `README.md`  
🗄️ Миграция на PostgreSQL: `backend/MIGRATION_TO_POSTGRES.md`  
🔧 Настройка продакшена: `docs/`

---

**Нужна помощь?** Создайте issue в репозитории!
