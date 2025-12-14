const jwt = require('jsonwebtoken');

function authenticateToken(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'Токен не передан' });
  }

  const token = header.slice(7);
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { userId: decoded.userId, username: decoded.username };
    next();
  } catch (e) {
    return res.status(401).json({ success: false, message: 'Неверный или истёкший токен' });
  }
}

// Экспортируем функцию напрямую, а не как объект
module.exports = authenticateToken;
