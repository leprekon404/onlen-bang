const { Pool } = require('pg');
require('dotenv').config();

// Создаем пул соединений PostgreSQL
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'onlinebank',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Проверка соединения
pool.on('connect', () => {
  console.log('✓ Подключено к PostgreSQL');
});

pool.on('error', (err) => {
  console.error('Ошибка подключения к PostgreSQL:', err);
});

// Функция-обертка для совместимости с MySQL синтаксисом
const query = async (text, params) => {
  try {
    const result = await pool.query(text, params);
    // Возвращаем в формате совместимом с mysql2
    return [result.rows, result.fields];
  } catch (error) {
    console.error('Database query error:', error);
    throw error;
  }
};

// Экспортируем pool и query
module.exports = {
  query,
  pool,
  // Для совместимости добавляем метод execute
  execute: query
};
