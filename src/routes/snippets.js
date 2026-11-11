const express = require('express');
const router = express.Router();
const db = require('../db/database');
const { authenticateToken, optionalAuth } = require('../middleware/auth');

// GET /api/snippets - List & filter snippets
router.get('/', optionalAuth, async (req, res, next) => {
  try {
    const { search, language, status, sort } = req.query;
    const currentUserId = req.user ? req.user.id : null;

    let conditions = [];
    let params = [];
    let paramIndex = 1;

    // Visibility:
    // If not logged in: only public snippets
    // If logged in: public snippets OR snippets owned by current user
    if (!currentUserId) {
      conditions.push(`s.status = 'public'`);
    } else {
      if (status === 'private') {
        conditions.push(`s.user_id = $${paramIndex++} AND s.status = 'private'`);
        params.push(currentUserId);
      } else if (status === 'public') {
        conditions.push(`s.status = 'public'`);
      } else if (status === 'my') {
        conditions.push(`s.user_id = $${paramIndex++}`);
        params.push(currentUserId);
      } else {
        // default: public or own snippets
        conditions.push(`(s.status = 'public' OR s.user_id = $${paramIndex++})`);
        params.push(currentUserId);
      }
    }

    if (language && language !== 'all') {
      conditions.push(`LOWER(s.language) = LOWER($${paramIndex++})`);
      params.push(language);
    }

    if (search && search.trim() !== '') {
      const term = `%${search.trim().toLowerCase()}%`;
      conditions.push(`(LOWER(s.title) LIKE $${paramIndex} OR LOWER(s.description) LIKE $${paramIndex} OR LOWER(s.tags) LIKE $${paramIndex})`);
      params.push(term);
      paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const orderBy = sort === 'oldest' ? 'ORDER BY s.created_at ASC' : 'ORDER BY s.created_at DESC';

    const sql = `
      SELECT 
        s.id, s.user_id, s.title, s.language, s.code, s.description, 
        s.tags, s.status, s.created_at, s.updated_at,
        u.username as author_name, u.email as author_email
      FROM snippets s
      LEFT JOIN users u ON s.user_id = u.id
      ${whereClause}
      ${orderBy}
    `;

    const result = await db.query(sql, params);

    return res.status(200).json({
      success: true,
      count: result.rows.length,
      snippets: result.rows
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/snippets/meta/summary - Stats for dashboard / analytics
router.get('/meta/summary', optionalAuth, async (req, res, next) => {
  try {
    const totalResult = await db.query('SELECT COUNT(*) as count FROM snippets');
    const publicResult = await db.query(`SELECT COUNT(*) as count FROM snippets WHERE status = 'public'`);
    const privateResult = await db.query(`SELECT COUNT(*) as count FROM snippets WHERE status = 'private'`);
    const usersResult = await db.query('SELECT COUNT(*) as count FROM users');

    return res.status(200).json({
      success: true,
      stats: {
        totalSnippets: parseInt(totalResult.rows[0].count, 10),
        publicSnippets: parseInt(publicResult.rows[0].count, 10),
        privateSnippets: parseInt(privateResult.rows[0].count, 10),
        totalUsers: parseInt(usersResult.rows[0].count, 10)
      }
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/snippets/:id - Single snippet
router.get('/:id', optionalAuth, async (req, res, next) => {
  try {
    const { id } = req.params;
    const currentUserId = req.user ? req.user.id : null;

    const sql = `
      SELECT 
        s.id, s.user_id, s.title, s.language, s.code, s.description, 
        s.tags, s.status, s.created_at, s.updated_at,
        u.username as author_name, u.email as author_email
      FROM snippets s
      LEFT JOIN users u ON s.user_id = u.id
      WHERE s.id = $1
    `;
    const result = await db.query(sql, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: `Không tìm thấy snippet có ID ${id}.`
      });
    }

    const snippet = result.rows[0];

    // If private and not owner, forbid
    if (snippet.status === 'private' && snippet.user_id !== currentUserId) {
      return res.status(403).json({
        success: false,
        error: 'Bạn không có quyền xem đoạn code riêng tư này.'
      });
    }

    return res.status(200).json({
      success: true,
      snippet
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/snippets - Create snippet
router.post('/', authenticateToken, async (req, res, next) => {
  try {
    const { title, language, code, description, tags, status } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({
        success: false,
        error: 'Tiêu đề snippet không được để trống.'
      });
    }

    if (!code || !code.trim()) {
      return res.status(400).json({
        success: false,
        error: 'Nội dung mã nguồn không được để trống.'
      });
    }

    const snippetLang = (language && language.trim()) ? language.trim().toLowerCase() : 'plaintext';
    const snippetStatus = status === 'private' ? 'private' : 'public';
    const snippetDesc = description ? description.trim() : '';
    const snippetTags = tags ? tags.trim() : '';

    let insertSql = `
      INSERT INTO snippets (user_id, title, language, code, description, tags, status, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `;
    if (db.isPostgres()) {
      insertSql += ' RETURNING id, user_id, title, language, code, description, tags, status, created_at, updated_at';
    }

    const result = await db.query(insertSql, [
      req.user.id,
      title.trim(),
      snippetLang,
      code,
      snippetDesc,
      snippetTags,
      snippetStatus
    ]);

    let newSnippet;
    if (db.isPostgres()) {
      newSnippet = result.rows[0];
    } else {
      const id = result.lastInsertRowid;
      const fetchNew = await db.query('SELECT * FROM snippets WHERE id = $1', [id]);
      newSnippet = fetchNew.rows[0];
    }

    return res.status(201).json({
      success: true,
      message: 'Tạo snippet thành công.',
      snippet: newSnippet
    });
  } catch (err) {
    next(err);
  }
});

// PUT /api/snippets/:id - Update snippet
router.put('/:id', authenticateToken, async (req, res, next) => {
  try {
    const { id } = req.params;
    const { title, language, code, description, tags, status } = req.body;

    const existingResult = await db.query('SELECT * FROM snippets WHERE id = $1', [id]);
    if (existingResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: `Không tìm thấy snippet có ID ${id}.`
      });
    }

    const existing = existingResult.rows[0];
    if (existing.user_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'Bạn không có quyền chỉnh sửa snippet của người khác.'
      });
    }

    const newTitle = title !== undefined ? title.trim() : existing.title;
    const newLang = language !== undefined ? language.trim().toLowerCase() : existing.language;
    const newCode = code !== undefined ? code : existing.code;
    const newDesc = description !== undefined ? description.trim() : existing.description;
    const newTags = tags !== undefined ? tags.trim() : existing.tags;
    const newStatus = status !== undefined ? (status === 'private' ? 'private' : 'public') : existing.status;

    if (!newTitle) {
      return res.status(400).json({
        success: false,
        error: 'Tiêu đề snippet không được để trống.'
      });
    }

    if (!newCode || !newCode.trim()) {
      return res.status(400).json({
        success: false,
        error: 'Nội dung mã nguồn không được để trống.'
      });
    }

    const updateSql = `
      UPDATE snippets
      SET title = $1, language = $2, code = $3, description = $4, tags = $5, status = $6, updated_at = CURRENT_TIMESTAMP
      WHERE id = $7
    `;
    await db.query(updateSql, [newTitle, newLang, newCode, newDesc, newTags, newStatus, id]);

    const updated = await db.query('SELECT * FROM snippets WHERE id = $1', [id]);

    return res.status(200).json({
      success: true,
      message: 'Cập nhật snippet thành công.',
      snippet: updated.rows[0]
    });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/snippets/:id - Delete snippet
router.delete('/:id', authenticateToken, async (req, res, next) => {
  try {
    const { id } = req.params;

    const existingResult = await db.query('SELECT * FROM snippets WHERE id = $1', [id]);
    if (existingResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: `Không tìm thấy snippet có ID ${id}.`
      });
    }

    const existing = existingResult.rows[0];
    if (existing.user_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'Bạn không có quyền xóa snippet của người khác.'
      });
    }

    await db.query('DELETE FROM snippets WHERE id = $1', [id]);

    return res.status(200).json({
      success: true,
      message: `Đã xóa thành công snippet ID ${id}.`
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
