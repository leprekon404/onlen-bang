# Online Banking System

## Описание

Простая система онлайн-банка на Node.js + PostgreSQL с поддержкой аналитики, уведомлений и платежей.

## Технологии

- **Backend**: Node.js + Express
- **Database**: PostgreSQL
- **Authentication**: JWT + bcrypt
- **Frontend**: Vanilla JS, HTML, CSS

## Требования

- Node.js >= 16.0.0
- PostgreSQL >= 13
- npm >= 8.0.0

## Установка

### 1. Клонирование репозитория

```bash
git clone https://github.com/leprekon404/onlen-bang.git
cd onlen-bang
```

### 2. Установка зависимостей

```bash
npm install
```

### 3. Настройка окружения

Скопируйте `.env.example` в `.env` и настройте параметры:

```bash
cp .env.example .env
```

Отредактируйте `.env`:

```env
DB_HOST=localhost
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=online_banking_db
DB_PORT=5432

JWT_SECRET=your_secret_key
JWT_EXPIRES_IN=24h

PORT=3000
NODE_ENV=development
```

### 4. Настройка базы данных

#### Автоматическая настройка (требуется psql в PATH):

```bash
npm run db:setup
```

#### Ручная настройка:

1. Создайте БД и пользователя:

```bash
psql -U postgres -f database_schema_init.sql
```

2. Подключитесь к БД:

```bash
psql -U postgres -d online_banking_db
```

3. Выполните миграции:

```sql
\i database_schema.sql
\i database_schema_analytics.sql
\i database_schema_notifications.sql
\i database_schema_payments.sql
```

#### Альтернативный способ (через pgAdmin):

1. Откройте pgAdmin
2. Подключитесь к серверу PostgreSQL
3. Откройте Query Tool
4. Скопируйте содержимое файлов SQL и выполните их по порядку

### 5. Запуск приложения

#### Режим разработки:

```bash
npm run dev
```

#### Production режим:

```bash
npm start
```

Приложение будет доступно по адресу: http://localhost:3000

## Структура проекта

```
onlen-bang/
├── backend/
│   ├── config/          # Конфигурация БД
│   ├── middleware/      # Express middleware
│   ├── routes/          # API роуты
│   ├── services/        # Бизнес-логика
│   ├── utils/           # Утилиты
│   └── server.js        # Точка входа
├── frontend/            # Статические файлы фронтенда
├── docs/                # Документация
├── database_schema*.sql # SQL схемы
├── .env                 # Переменные окружения
└── package.json         # Зависимости
```

## API Endpoints

### Аутентификация

- `POST /api/auth/login` - Вход в систему
- `POST /api/auth/register` - Регистрация
- `POST /api/auth/logout` - Выход

### Счета

- `GET /api/accounts` - Список счетов
- `GET /api/accounts/:id` - Детали счета
- `POST /api/accounts` - Создание счета

### Транзакции

- `GET /api/transactions` - История транзакций
- `POST /api/transactions` - Создание транзакции

### Платежи

- `GET /api/payments/templates` - Шаблоны платежей
- `POST /api/payments/templates` - Создание шаблона
- `POST /api/payments/execute` - Выполнение платежа

### Уведомления

- `GET /api/notifications` - Список уведомлений
- `PUT /api/notifications/:id/read` - Отметить прочитанным

### Аналитика

- `GET /api/analytics/summary` - Сводка по счетам
- `GET /api/analytics/expenses` - Анализ расходов

## Тестовые данные

После настройки БД доступны тестовые пользователи:

**Пользователь 1:**
- Username: `ivanov`
- Password: `Password123!`
- Счет: 150,000 RUB

**Пользователь 2:**
- Username: `petrov`
- Password: `Password123!`
- Счета: 75,000 RUB (дебетовая), 25,000 RUB (сберегательная)

**Пользователь 3:**
- Username: `sidorov`
- Password: `Password123!`
- Счет: 25,000 RUB

## Генерация хешей паролей

```bash
node gen-hash.js
```

## Разработка

### Добавление новых миграций

1. Создайте новый SQL файл в корне проекта
2. Выполните его через psql или pgAdmin
3. Обновите документацию

### Добавление новых API endpoints

1. Создайте роут в `backend/routes/`
2. Добавьте бизнес-логику в `backend/services/`
3. Зарегистрируйте роут в `backend/server.js`

## Troubleshooting

### Ошибка подключения к БД

1. Убедитесь что PostgreSQL запущен:
   ```bash
   # Windows
   net start postgresql-x64-13
   
   # Linux/Mac
   sudo systemctl status postgresql
   ```

2. Проверьте настройки в `.env`

3. Проверьте доступ пользователя:
   ```bash
   psql -U postgres -d online_banking_db
   ```

### Ошибка "роль не существует"

Выполните скрипт инициализации:
```bash
psql -U postgres -f database_schema_init.sql
```

### Проблемы с портами

Если порт 3000 занят, измените `PORT` в `.env`

## Лицензия

ISC

## Контакты

Создайте issue в репозитории для вопросов и предложений.
