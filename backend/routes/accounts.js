// backend/routes/accounts.js
const express = require('express');
const router = express.Router();
const db = require('../config/database');
const bcrypt = require('bcryptjs');
const { authenticate } = require('../middleware/auth');

// GET /api/accounts – список всех счетов/карт пользователя
router.get('/', authenticate, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT account_id,
              account_number,
              account_type,
              balance,
              daily_limit,
              currency,
              is_active,
              is_frozen,
              created_at
       FROM accounts
       WHERE user_id = ?
       ORDER BY created_at ASC`,
      [req.user.id]
    );
    res.json({ success: true, accounts: rows });
  } catch (e) {
    console.error('Accounts list error:', e);
    res.status(500).json({ success: false, message: 'Ошибка сервера' });
  }
});

// GET /api/accounts/:id – подробности по одному счёту/карте
router.get('/:id', authenticate, async (req, res) => {
  try {
    const accountId = Number(req.params.id);
    const [rows] = await db.query(
      `SELECT account_id,
              account_number,
              account_type,
              balance,
              daily_limit,
              currency,
              is_active,
              is_frozen,
              created_at
       FROM accounts
       WHERE account_id = ? AND user_id = ?`,
      [accountId, req.user.id]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Счёт не найден' });
    }
    res.json({ success: true, account: rows[0] });
  } catch (e) {
    console.error('Account details error:', e);
    res.status(500).json({ success: false, message: 'Ошибка сервера' });
  }
});

// PATCH /api/accounts/:id/limit – установка дневного лимита
router.patch('/:id/limit', authenticate, async (req, res) => {
  try {
    const accountId = Number(req.params.id);
    const { dailyLimit } = req.body;
    const value = dailyLimit == null || dailyLimit === ''
      ? null
      : Number(dailyLimit);

    if (value !== null && (isNaN(value) || value <= 0)) {
      return res.status(400).json({ success: false, message: 'Некорректный лимит' });
    }

    const [result] = await db.query(
      `UPDATE accounts
       SET daily_limit = ?
       WHERE account_id = ? AND user_id = ?`,
      [value, accountId, req.user.id]
    );

    if (!result.affectedRows) {
      return res.status(404).json({ success: false, message: 'Счёт не найден' });
    }

    res.json({ success: true, message: 'Лимит обновлён' });
  } catch (e) {
    console.error('Update limit error:', e);
    res.status(500).json({ success: false, message: 'Ошибка сервера' });
  }
});

// PATCH /api/accounts/:id/freeze – временная блокировка/разблокировка
router.patch('/:id/freeze', authenticate, async (req, res) => {
  try {
    const accountId = Number(req.params.id);
    const { freeze } = req.body; // true / false

    const [result] = await db.query(
      `UPDATE accounts
       SET is_frozen = ?
       WHERE account_id = ? AND user_id = ?`,
      [!!freeze, accountId, req.user.id]
    );

    if (!result.affectedRows) {
      return res.status(404).json({ success: false, message: 'Счёт не найден' });
    }

    res.json({
      success: true,
      message: freeze ? 'Карта временно заблокирована' : 'Карта разблокирована',
    });
  } catch (e) {
    console.error('Freeze card error:', e);
    res.status(500).json({ success: false, message: 'Ошибка сервера' });
  }
});

// PATCH /api/accounts/:id/pin – смена PIN
router.patch('/:id/pin', authenticate, async (req, res) => {
  try {
    const accountId = Number(req.params.id);
    const { oldPin, newPin } = req.body;

    if (!newPin || String(newPin).length < 4) {
      return res
        .status(400)
        .json({ success: false, message: 'PIN должен содержать минимум 4 цифры' });
    }

    const [rows] = await db.query(
      `SELECT account_id, pin_hash
       FROM accounts
       WHERE account_id = ? AND user_id = ?`,
      [accountId, req.user.id]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Счёт не найден' });
    }

    const acc = rows[0];

    if (acc.pin_hash) {
      if (!oldPin) {
        return res
          .status(400)
          .json({ success: false, message: 'Укажите старый PIN' });
      }
      const ok = await bcrypt.compare(String(oldPin), acc.pin_hash);
      if (!ok) {
        return res
          .status(400)
          .json({ success: false, message: 'Старый PIN неверен' });
      }
    }

    const hash = await bcrypt.hash(String(newPin), 10);
    await db.query(
      `UPDATE accounts
       SET pin_hash = ?
       WHERE account_id = ? AND user_id = ?`,
      [hash, accountId, req.user.id]
    );

    res.json({ success: true, message: 'PIN обновлён' });
  } catch (e) {
    console.error('Change PIN error:', e);
    res.status(500).json({ success: false, message: 'Ошибка сервера' });
  }
});

module.exports = router;
