# Преобразование MySQL в PostgreSQL

## 🚀 Автоматическая конвертация

Для автоматической конвертации всех SQL запросов:

```bash
cd backend
node scripts/convert-to-postgres.js
```

Этот скрипт:
- Находит все `db.query()` в `routes/` и `middleware/`
- Конвертирует MySQL синтаксис в PostgreSQL
- Сохраняет изменения

## 🔄 Что конвертируется

### 1. Плейсхолдеры
```sql
-- MySQL
SELECT * FROM users WHERE id = ?

-- PostgreSQL
SELECT * FROM users WHERE id = $1
```

### 2. Функции даты/времени
```sql
-- MySQL -> PostgreSQL
NOW()              -> CURRENT_TIMESTAMP
CURDATE()          -> CURRENT_DATE
CURTIME()          -> CURRENT_TIME
DATE(column)       -> column::date
YEAR(column)       -> EXTRACT(YEAR FROM column)
MONTH(column)      -> EXTRACT(MONTH FROM column)
DAY(column)        -> EXTRACT(DAY FROM column)
```

### 3. Агрегатные функции
```sql
-- MySQL
GROUP_CONCAT(name)
GROUP_CONCAT(DISTINCT name)

-- PostgreSQL
STRING_AGG(name, ',')
STRING_AGG(DISTINCT name, ',')
```

### 4. Пагинация
```sql
-- MySQL
LIMIT 10, 20  -- offset, count

-- PostgreSQL
LIMIT 20 OFFSET 10  -- count OFFSET offset
```

### 5. Типы данных
```sql
-- MySQL -> PostgreSQL
INT                -> INTEGER
TINYINT(1)         -> BOOLEAN
DATETIME           -> TIMESTAMP
AUTO_INCREMENT     -> SERIAL
```

### 6. Кавычки
```sql
-- MySQL (backticks)
`table_name`
`column_name`

-- PostgreSQL (double quotes, но лучше без них)
"table_name"
"column_name"
```

## 🛠️ Ручная конвертация

Если нужно вручную обработать отдельные запросы:

```javascript
const { convertPlaceholders, convertFunctions } = require('./utils/pg-helper');

// Было (MySQL)
const [results] = await db.query(
  'SELECT * FROM users WHERE id = ? AND status = ?',
  [userId, 'active']
);

// Стало (PostgreSQL)
const [results] = await db.query(
  'SELECT * FROM users WHERE id = $1 AND status = $2',
  [userId, 'active']
);
```

## ✅ Проверка

После конвертации проверьте:

```bash
# 1. Запустите сервер
node server.js

# 2. Проверьте все API эндпоинты
# 3. Просмотрите логи на наличие SQL ошибок
```

## 🐛 Распространенные ошибки

### 1. "syntax error at or near"
Проверьте правильность плейсхолдеров ($1, $2, ...) и SQL синтаксис

### 2. "column does not exist"
PostgreSQL чувствителен к регистру. Используйте нижний регистр или двойные кавычки

### 3. "function does not exist"
Проверьте что все MySQL функции конвертированы

## 📚 Дополнительно

- [PostgreSQL Документация](https://www.postgresql.org/docs/)
- [MySQL в PostgreSQL миграция](https://wiki.postgresql.org/wiki/Converting_from_other_Databases_to_PostgreSQL)
