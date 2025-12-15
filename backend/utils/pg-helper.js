/**
 * Вспомогательные функции для работы с PostgreSQL
 * Обеспечивают совместимость с синтаксисом MySQL
 */

/**
 * Конвертирует MySQL плейсхолдеры (?) в PostgreSQL ($1, $2, ...)
 * @param {string} sql - SQL запрос с MySQL плейсхолдерами
 * @param {Array} params - Параметры запроса
 * @returns {Object} - {sql, params} с PostgreSQL форматом
 */
function convertPlaceholders(sql, params = []) {
  let index = 0;
  const newSql = sql.replace(/\?/g, () => `$${++index}`);
  return { sql: newSql, params };
}

/**
 * Форматирует LIMIT и OFFSET для PostgreSQL
 * @param {number} limit
 * @param {number} offset
 * @returns {string}
 */
function formatPagination(limit, offset = 0) {
  return `LIMIT $${1} OFFSET $${2}`;
}

/**
 * Конвертирует MySQL функции в PostgreSQL
 * @param {string} sql
 * @returns {string}
 */
function convertFunctions(sql) {
  return sql
    .replace(/NOW\(\)/g, 'CURRENT_TIMESTAMP')
    .replace(/CURDATE\(\)/g, 'CURRENT_DATE')
    .replace(/DATE\(([^)]+)\)/g, '$1::date')
    .replace(/YEAR\(([^)]+)\)/g, 'EXTRACT(YEAR FROM $1)')
    .replace(/MONTH\(([^)]+)\)/g, 'EXTRACT(MONTH FROM $1)')
    .replace(/GROUP_CONCAT\(([^)]+)\)/g, 'STRING_AGG($1, \',\')');
}

/**
 * Обертка для query с автоматической конвертацией
 * @param {Pool} pool - PostgreSQL pool
 * @param {string} sql - SQL запрос
 * @param {Array} params - Параметры
 * @returns {Promise<Array>} - [rows, fields]
 */
async function executeQuery(pool, sql, params = []) {
  // Конвертируем функции
  let convertedSql = convertFunctions(sql);
  
  // Конвертируем плейсхолдеры
  const { sql: finalSql, params: finalParams } = convertPlaceholders(convertedSql, params);
  
  try {
    const result = await pool.query(finalSql, finalParams);
    return [result.rows, result.fields];
  } catch (error) {
    console.error('SQL Error:', error.message);
    console.error('SQL:', finalSql);
    console.error('Params:', finalParams);
    throw error;
  }
}

module.exports = {
  convertPlaceholders,
  formatPagination,
  convertFunctions,
  executeQuery
};
