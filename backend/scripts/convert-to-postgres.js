/**
 * Скрипт для автоматической конвертации MySQL запросов в PostgreSQL
 * 
 * Запуск: node scripts/convert-to-postgres.js
 */

const fs = require('fs');
const path = require('path');

/**
 * Конвертирует MySQL SQL в PostgreSQL
 */
function convertSqlToPostgres(sql) {
  let result = sql;
  
  // 1. Конвертируем плейсхолдеры ? на $1, $2, ...
  let index = 0;
  result = result.replace(/\?/g, () => `$${++index}`);
  
  // 2. Заменяем функции MySQL на PostgreSQL
  const replacements = [
    // Функции даты/времени
    [/NOW\(\)/gi, 'CURRENT_TIMESTAMP'],
    [/CURDATE\(\)/gi, 'CURRENT_DATE'],
    [/CURTIME\(\)/gi, 'CURRENT_TIME'],
    
    // DATE() функция
    [/DATE\(([^)]+)\)/gi, '$1::date'],
    
    // YEAR, MONTH, DAY
    [/YEAR\(([^)]+)\)/gi, 'EXTRACT(YEAR FROM $1)'],
    [/MONTH\(([^)]+)\)/gi, 'EXTRACT(MONTH FROM $1)'],
    [/DAY\(([^)]+)\)/gi, 'EXTRACT(DAY FROM $1)'],
    
    // GROUP_CONCAT -> STRING_AGG
    [/GROUP_CONCAT\s*\(\s*DISTINCT\s+([^)]+)\s*\)/gi, "STRING_AGG(DISTINCT $1, ',')"],
    [/GROUP_CONCAT\s*\(([^)]+)\s*\)/gi, "STRING_AGG($1, ',')"],
    
    // TRUE/FALSE
    [/TRUE/gi, 'TRUE'],
    [/FALSE/gi, 'FALSE'],
    
    // LIMIT offset, count -> LIMIT count OFFSET offset
    [/LIMIT\s+(\d+)\s*,\s*(\d+)/gi, 'LIMIT $2 OFFSET $1'],
    
    // IF EXISTS / IF NOT EXISTS
    [/CREATE\s+DATABASE\s+IF\s+NOT\s+EXISTS/gi, 'CREATE DATABASE IF NOT EXISTS'],
    
    // TINYINT(1) -> BOOLEAN
    [/TINYINT\s*\(\s*1\s*\)/gi, 'BOOLEAN'],
    
    // INT -> INTEGER
    [/\bINT\b/gi, 'INTEGER'],
    
    // DATETIME -> TIMESTAMP
    [/DATETIME/gi, 'TIMESTAMP'],
    
    // AUTO_INCREMENT -> SERIAL
    [/INT\s+AUTO_INCREMENT/gi, 'SERIAL'],
    [/INTEGER\s+AUTO_INCREMENT/gi, 'SERIAL'],
    
    // BACKTICKS -> DOUBLE QUOTES (optional, можно просто убрать)
    [/`([^`]+)`/g, '"$1"'],
    
    // CASE WHEN ... THEN 1 END -> CASE WHEN ... THEN TRUE END
    [/THEN\s+1\s+END/gi, 'THEN TRUE END'],
    [/THEN\s+0\s+END/gi, 'THEN FALSE END']
  ];
  
  replacements.forEach(([pattern, replacement]) => {
    result = result.replace(pattern, replacement);
  });
  
  return result;
}

/**
 * Обрабатывает файл .js
 */
function processFile(filePath) {
  console.log(`Обработка: ${filePath}`);
  
  let content = fs.readFileSync(filePath, 'utf8');
  let modified = false;
  
  // Ищем db.query() и конвертируем SQL
  content = content.replace(/db\.query\s*\(\s*`([^`]+)`/g, (match, sql) => {
    const converted = convertSqlToPostgres(sql);
    if (converted !== sql) {
      modified = true;
      return `db.query(\`${converted}\``;
    }
    return match;
  });
  
  // Ищем db.query() с одинарными кавычками
  content = content.replace(/db\.query\s*\(\s*'([^']+)'/g, (match, sql) => {
    const converted = convertSqlToPostgres(sql);
    if (converted !== sql) {
      modified = true;
      return `db.query('${converted}'`;
    }
    return match;
  });
  
  // Ищем db.query() с двойными кавычками
  content = content.replace(/db\.query\s*\(\s*"([^"]+)"/g, (match, sql) => {
    const converted = convertSqlToPostgres(sql);
    if (converted !== sql) {
      modified = true;
      return `db.query("${converted}"`;
    }
    return match;
  });
  
  if (modified) {
    fs.writeFileSync(filePath, content, 'utf8');
    console.log(`  ✓ Обновлен`);
  } else {
    console.log(`  - Изменений не требуется`);
  }
}

/**
 * Обходит директорию рекурсивно
 */
function processDirectory(dir) {
  const files = fs.readdirSync(dir);
  
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    
    if (stat.isDirectory()) {
      // Пропускаем node_modules
      if (file !== 'node_modules') {
        processDirectory(filePath);
      }
    } else if (file.endsWith('.js')) {
      processFile(filePath);
    }
  });
}

// Запуск
console.log('='.repeat(50));
console.log('Конвертация MySQL в PostgreSQL');
console.log('='.repeat(50));

const routesDir = path.join(__dirname, '..', 'routes');
const middlewareDir = path.join(__dirname, '..', 'middleware');

console.log('\nОбработка routes/...');
processDirectory(routesDir);

console.log('\nОбработка middleware/...');
processDirectory(middlewareDir);

console.log('\n' + '='.repeat(50));
console.log('✓ Конвертация завершена!');
console.log('='.repeat(50));
