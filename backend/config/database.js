const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'online_banking_db',
  port: process.env.DB_PORT || 5432,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

pool.connect()
  .then(client => {
    console.log('✅ PostgreSQL подключена');
    client.release();
  })
  .catch(err => {
    console.error('❌ PostgreSQL ошибка подключения:', err.message);
  });

// Wrapper для совместимости с MySQL синтаксисом
pool.query = async function(sql, params) {
  // Заменяем ? на $1, $2, $3 для PostgreSQL
  let paramIndex = 1;
  const pgSql = sql.replace(/\?/g, () => `$${paramIndex++}`);
  
  try {
    const result = await pool.query(pgSql, params);
    // Возвращаем в формате [rows, fields] как MySQL
    return [result.rows, result.fields];
  } catch (error) {
    throw error;
  }
};

module.exports = pool;
