# Миграция с MySQL на PostgreSQL

## 🚀 Быстрый старт

### 1. Установка PostgreSQL

**Windows:**
```bash
# Скачайте с https://www.postgresql.org/download/windows/
# Или через Chocolatey:
choco install postgresql
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

**macOS:**
```bash
brew install postgresql
brew services start postgresql
```

### 2. Настройка базы данных

```bash
# Войдите в PostgreSQL
psql -U postgres

# Создайте базу данных
CREATE DATABASE onlinebank;

# Подключитесь к базе
\c onlinebank

# Запустите схему
\i config/schema.sql

# Выйдите
\q
```

**Или одной командой:**
```bash
psql -U postgres -d onlinebank -f backend/config/schema.sql
```

### 3. Настройка переменных окружения

Создайте файл `backend/.env`:

```env
# Server
PORT=3000
NODE_ENV=development

# PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_NAME=onlinebank
DB_USER=postgres
DB_PASSWORD=ваш_пароль

# JWT
JWT_SECRET=your-super-secret-key-change-this
JWT_EXPIRES_IN=24h
```

### 4. Установка зависимостей

```bash
cd backend
npm install
```

### 5. Запуск сервера

```bash
node server.js
```

## 🔄 Основные изменения

### Синтаксис SQL

| MySQL | PostgreSQL |
|-------|------------|
| `AUTO_INCREMENT` | `SERIAL` или `GENERATED ALWAYS AS IDENTITY` |
| `NOW()` | `CURRENT_TIMESTAMP` |
| `CURDATE()` | `CURRENT_DATE` |
| `DATE(column)` | `column::date` |
| `YEAR(column)` | `EXTRACT(YEAR FROM column)` |
| `MONTH(column)` | `EXTRACT(MONTH FROM column)` |
| `LIMIT ?, ?` | `LIMIT ? OFFSET ?` |
| Backticks ``` | Double quotes `"` |
| `INSERT ... ON DUPLICATE KEY UPDATE` | `INSERT ... ON CONFLICT ... DO UPDATE` |

### Параметризованные запросы

**MySQL:**
```javascript
db.query('SELECT * FROM users WHERE id = ?', [userId])
```

**PostgreSQL:**
```javascript
db.query('SELECT * FROM users WHERE id = $1', [userId])
```

### Типы данных

| MySQL | PostgreSQL |
|-------|------------|
| `INT` | `INTEGER` |
| `TINYINT(1)` | `BOOLEAN` |
| `DATETIME` | `TIMESTAMP` |
| `TEXT` | `TEXT` |
| `VARCHAR(n)` | `VARCHAR(n)` |
| `DECIMAL(m,n)` | `DECIMAL(m,n)` или `NUMERIC(m,n)` |

## 🛠️ Полезные команды PostgreSQL

```sql
-- Показать все базы данных
\l

-- Подключиться к базе
\c onlinebank

-- Показать все таблицы
\dt

-- Описание таблицы
\d users

-- Показать все индексы
\di

-- Показать все представления
\dv

-- Выполнить SQL файл
\i file.sql

-- Выйти
\q
```

## 🔍 Проверка установки

```bash
# Проверьте версию PostgreSQL
psql --version

# Проверьте подключение
psql -U postgres -c "SELECT version();"

# Проверьте список баз
psql -U postgres -c "\l"
```

## 🐛 Решение проблем

### Ошибка: "role does not exist"

```bash
# Создайте пользователя
psql -U postgres -c "CREATE USER youruser WITH PASSWORD 'yourpassword';"
psql -U postgres -c "ALTER USER youruser CREATEDB;"
```

### Ошибка: "password authentication failed"

Отредактируйте `pg_hba.conf`:

**Windows:** `C:\Program Files\PostgreSQL\15\data\pg_hba.conf`  
**Linux:** `/etc/postgresql/15/main/pg_hba.conf`

Измените:
```
host    all             all             127.0.0.1/32            md5
```

Перезапустите PostgreSQL:
```bash
# Windows
net stop postgresql-x64-15
net start postgresql-x64-15

# Linux
sudo systemctl restart postgresql

# macOS
brew services restart postgresql
```

### Ошибка: "database does not exist"

```bash
psql -U postgres -c "CREATE DATABASE onlinebank;"
```

## 📊 Преимущества PostgreSQL

✅ **Полностью бесплатный и open-source**  
✅ **Поддержка JSON/JSONB**  
✅ **Мощные триггеры и функции**  
✅ **Лучшая производительность**  
✅ **ACID гарантии**  
✅ **Автоматическое обновление updated_at**  
✅ **Поддержка представлений (views)**  

## 📚 Дополнительные ресурсы

- [PostgreSQL Документация](https://www.postgresql.org/docs/)
- [node-postgres (pg) документация](https://node-postgres.com/)
- [PostgreSQL тюториал](https://www.postgresqltutorial.com/)
