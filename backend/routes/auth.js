// backend/routes/auth.js
const express = require('express');
const router = express.Router();
const db = require('../config/database');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// вспомогательная функция выдачи токена и объекта пользователя
function buildAuthResponse(userRow) {
  const token = jwt.sign(
    { userId: userRow.user_id, username: userRow.username },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
  );

  return {
    success: true,
    token,
    user: {
      id: userRow.user_id,
      username: userRow.username,
      email: userRow.email,
      fullName: userRow.full_name,
      phoneNumber: userRow.phone_number,
    },
  };
}

// ----- ВХОД -----
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res
        .status(400)
        .json({ success: false, message: 'Укажите логин и пароль' });
    }

    const [rows] = await db.query(
      'SELECT * FROM users WHERE username = ?',
      [username]
    );

    if (!rows.length) {
      return res
        .status(401)
        .json({ success: false, message: 'Неверный логин или пароль' });
    }

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);

    if (!ok) {
      return res
        .status(401)
        .json({ success: false, message: 'Неверный логин или пароль' });
    }

    user.last_login = new Date();
    await db.query(
      'UPDATE users SET last_login = NOW(), failed_login_attempts = 0 WHERE user_id = ?',
      [user.user_id]
    );

    res.json(buildAuthResponse(user));
  } catch (e) {
    console.error('Login error:', e);
    res
      .status(500)
      .json({ success: false, message: 'Ошибка сервера при входе' });
  }
});

// ----- РЕГИСТРАЦИЯ -----
router.post('/register', async (req, res) => {
  try {
    const { username, email, fullName, phoneNumber, password } = req.body;

    if (!username || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Логин, e‑mail и пароль обязательны',
      });
    }

    // проверка уникальности
    const [exists] = await db.query(
      'SELECT user_id, username, email FROM users WHERE username = ? OR email = ?',
      [username, email]
    );
    if (exists.length) {
      const conflict = exists[0];
      if (conflict.username === username) {
        return res
          .status(400)
          .json({ success: false, message: 'Такой логин уже используется' });
      }
      if (conflict.email === email) {
        return res
          .status(400)
          .json({ success: false, message: 'Такой e‑mail уже зарегистрирован' });
      }
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const [result] = await db.query(
      'INSERT INTO users (username, email, password_hash, full_name, phone_number, is_active, created_at) ' +
      'VALUES (?, ?, ?, ?, ?, TRUE, NOW())',
      [username, email, passwordHash, fullName || null, phoneNumber || null]
    );

    const [rows] = await db.query(
      'SELECT * FROM users WHERE user_id = ?',
      [result.insertId]
    );
    const newUser = rows[0];

    res.status(201).json(buildAuthResponse(newUser));
  } catch (e) {
    console.error('Register error:', e);
    res
      .status(500)
      .json({ success: false, message: 'Ошибка сервера при регистрации' });
  }
});

module.exports = router;
