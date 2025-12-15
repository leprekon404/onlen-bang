# Code Review & Recommendations

Дата: 15.12.2025  
Уровень: Middle Developer Review

## ✅ Что сделано хорошо

### 1. Архитектура
- ✅ Чистая структура backend/frontend
- ✅ Разделение на routes/services/middleware
- ✅ Модульная структура БД (аналитика, платежи, уведомления)

### 2. База данных
- ✅ PostgreSQL - правильный выбор для банкинга
- ✅ JSONB для гибких данных
- ✅ Индексы на важных полях
- ✅ CASCADE для foreign keys
- ✅ Триггеры для updated_at

### 3. Безопасность
- ✅ bcrypt для хеширования паролей
- ✅ JWT для аутентификации
- ✅ Отдельный пользователь БД (banking_app_user)
- ✅ .env для чувствительных данных

## ⚠️ Критические улучшения

### 1. Безопасность

#### 🔴 Критично
- [ ] **Убрать .env из репозитория**
  ```bash
  git rm --cached .env
  git commit -m "Remove .env from repository"
  ```

- [ ] **Добавить валидацию ввода**
  Используйте `express-validator` для проверки данных:
  ```bash
  npm install express-validator
  ```

- [ ] **Rate limiting**
  ```bash
  npm install express-rate-limit
  ```
  ```javascript
  const rateLimit = require('express-rate-limit');
  
  const loginLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // 5 attempts
    message: 'Слишком много попыток. Попробуйте позже.'
  });
  
  app.use('/api/auth/login', loginLimiter);
  ```

- [ ] **Helmet.js для HTTP headers**
  ```bash
  npm install helmet
  ```
  ```javascript
  const helmet = require('helmet');
  app.use(helmet());
  ```

- [ ] **SQL Injection protection**
  Убедитесь что везде используются parameterized queries:
  ```javascript
  // ✅ Правильно
  await db.query('SELECT * FROM users WHERE username = $1', [username]);
  
  // ❌ Неправильно
  await db.query(`SELECT * FROM users WHERE username = '${username}'`);
  ```

### 2. Обработка ошибок

- [ ] **Централизованный error handler**
  Создать `backend/middleware/errorHandler.js`:
  ```javascript
  module.exports = (err, req, res, next) => {
    console.error(err.stack);
    
    const status = err.status || 500;
    const message = process.env.NODE_ENV === 'production' 
      ? 'Внутренняя ошибка сервера'
      : err.message;
    
    res.status(status).json({
      success: false,
      error: message
    });
  };
  ```

- [ ] **Custom error classes**
  ```javascript
  class ValidationError extends Error {
    constructor(message) {
      super(message);
      this.name = 'ValidationError';
      this.status = 400;
    }
  }
  
  class AuthError extends Error {
    constructor(message) {
      super(message);
      this.name = 'AuthError';
      this.status = 401;
    }
  }
  ```

### 3. Тестирование

- [ ] **Unit тесты**
  ```bash
  npm install --save-dev jest supertest
  ```
  
  Пример `backend/__tests__/auth.test.js`:
  ```javascript
  const request = require('supertest');
  const app = require('../server');
  
  describe('Auth API', () => {
    test('POST /api/auth/login - success', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ username: 'ivanov', password: 'Password123!' });
      
      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('token');
    });
    
    test('POST /api/auth/login - wrong password', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ username: 'ivanov', password: 'wrong' });
      
      expect(res.statusCode).toBe(401);
    });
  });
  ```

### 4. Логирование

- [ ] **Winston logger**
  ```bash
  npm install winston
  ```
  
  `backend/utils/logger.js`:
  ```javascript
  const winston = require('winston');
  
  const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.json()
    ),
    transports: [
      new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
      new winston.transports.File({ filename: 'logs/combined.log' })
    ]
  });
  
  if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
      format: winston.format.simple()
    }));
  }
  
  module.exports = logger;
  ```

### 5. Транзакции БД

- [ ] **Использовать транзакции для переводов**
  ```javascript
  async function transferMoney(fromAccountId, toAccountId, amount) {
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');
      
      // Списание
      await client.query(
        'UPDATE accounts SET balance = balance - $1 WHERE account_id = $2',
        [amount, fromAccountId]
      );
      
      // Зачисление
      await client.query(
        'UPDATE accounts SET balance = balance + $1 WHERE account_id = $2',
        [amount, toAccountId]
      );
      
      // Запись транзакции
      await client.query(
        'INSERT INTO transactions (from_account_id, to_account_id, amount, transaction_type) VALUES ($1, $2, $3, $4)',
        [fromAccountId, toAccountId, amount, 'transfer']
      );
      
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }
  ```

### 6. Конфигурация

- [ ] **Валидация .env**
  ```bash
  npm install dotenv-safe
  ```
  
  Создать `.env.example` с обязательными переменными

### 7. Производительность

- [ ] **Connection pooling**
  Увеличить размер пула для production:
  ```javascript
  const pool = new Pool({
    max: process.env.NODE_ENV === 'production' ? 50 : 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  });
  ```

- [ ] **Индексы БД**
  Добавить composite indexes для частых запросов:
  ```sql
  CREATE INDEX idx_transactions_user_date 
  ON transactions(user_id, created_at DESC);
  ```

- [ ] **Кеширование**
  ```bash
  npm install redis
  ```

## 🟡 Рекомендации

### 1. Код стиль

- [ ] **ESLint + Prettier**
  ```bash
  npm install --save-dev eslint prettier eslint-config-prettier
  npx eslint --init
  ```

- [ ] **Git hooks (Husky)**
  ```bash
  npm install --save-dev husky lint-staged
  npx husky-init
  ```

### 2. Документация API

- [ ] **Swagger/OpenAPI**
  ```bash
  npm install swagger-ui-express swagger-jsdoc
  ```

### 3. Мониторинг

- [ ] **PM2 для production**
  ```bash
  npm install -g pm2
  pm2 start backend/server.js --name online-banking
  pm2 startup
  pm2 save
  ```

### 4. Docker

- [ ] **Dockerfile**
  ```dockerfile
  FROM node:16-alpine
  WORKDIR /app
  COPY package*.json ./
  RUN npm ci --only=production
  COPY . .
  EXPOSE 3000
  CMD ["node", "backend/server.js"]
  ```

- [ ] **docker-compose.yml**
  ```yaml
  version: '3.8'
  services:
    db:
      image: postgres:13
      environment:
        POSTGRES_DB: online_banking_db
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: postgres
      volumes:
        - postgres_data:/var/lib/postgresql/data
    
    app:
      build: .
      ports:
        - "3000:3000"
      depends_on:
        - db
      environment:
        DB_HOST: db
  
  volumes:
    postgres_data:
  ```

### 5. CI/CD

- [ ] **GitHub Actions**
  `.github/workflows/test.yml`:
  ```yaml
  name: Tests
  on: [push, pull_request]
  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v2
        - uses: actions/setup-node@v2
          with:
            node-version: '16'
        - run: npm ci
        - run: npm test
  ```

## 📊 Приоритеты внедрения

### Неделя 1 (Критично)
1. Убрать .env из репозитория
2. Добавить rate limiting
3. Добавить helmet.js
4. Транзакции БД для переводов

### Неделя 2 (Важно)
5. Валидация ввода
6. Централизованный error handler
7. Winston logger
8. Unit тесты

### Неделя 3 (Улучшения)
9. ESLint + Prettier
10. Swagger documentation
11. Docker
12. PM2 для production

## 📝 Заключение

Проект имеет **хорошую основу**, но требует доработки в области безопасности и надежности. 

**Оценка:** 7/10  
**Готовность к production:** Не готов (требуется выполнить критические пункты)

---

Для дальнейшего развития рекомендую следовать плану приоритетов выше.
