const fs = require('fs');
const path = require('path');
const config = require('../config');

let isPostgres = false;
let pgPool = null;
let sqliteDb = null;

if (config.databaseUrl && (config.databaseUrl.startsWith('postgres://') || config.databaseUrl.startsWith('postgresql://'))) {
  isPostgres = true;
  const { Pool } = require('pg');
  pgPool = new Pool({
    connectionString: config.databaseUrl,
    ssl: config.nodeEnv === 'production' ? { rejectUnauthorized: false } : false
  });
  console.log('[DB] Using PostgreSQL connection pool');
} else {
  const { DatabaseSync } = require('node:sqlite');
  const dbDir = path.dirname(path.resolve(config.dbPath));
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }
  sqliteDb = new DatabaseSync(path.resolve(config.dbPath));
  console.log(`[DB] Using SQLite database at: ${path.resolve(config.dbPath)}`);
}

async function initDb() {
  if (isPostgres) {
    const client = await pgPool.connect();
    try {
      await client.query(`
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          email VARCHAR(255) UNIQUE NOT NULL,
          username VARCHAR(100) NOT NULL,
          password_hash TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS snippets (
          id SERIAL PRIMARY KEY,
          user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
          title VARCHAR(255) NOT NULL,
          language VARCHAR(50) NOT NULL,
          code TEXT NOT NULL,
          description TEXT,
          tags VARCHAR(255),
          status VARCHAR(20) DEFAULT 'public',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      `);
      console.log('[DB] PostgreSQL tables verified/created successfully.');
    } finally {
      client.release();
    }
  } else {
    sqliteDb.exec(`
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        username TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS snippets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        title TEXT NOT NULL,
        language TEXT NOT NULL,
        code TEXT NOT NULL,
        description TEXT,
        tags TEXT,
        status TEXT DEFAULT 'public',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      );
    `);
    console.log('[DB] SQLite tables verified/created successfully.');
  }
}

async function query(sql, params = []) {
  if (isPostgres) {
    const result = await pgPool.query(sql, params);
    return {
      rows: result.rows,
      rowCount: result.rowCount
    };
  } else {
    // Convert PostgreSQL style parameters ($1, $2, ...) to SQLite (?)
    const sqliteSql = sql.replace(/\$(\d+)/g, '?');
    const trimmed = sqliteSql.trim();
    const isSelect = /^SELECT/i.test(trimmed);

    const stmt = sqliteDb.prepare(sqliteSql);
    if (isSelect) {
      const rows = stmt.all(...params);
      return {
        rows: rows.map(r => ({ ...r })),
        rowCount: rows.length
      };
    } else {
      const result = stmt.run(...params);
      // For INSERT RETURNING id emulation if needed:
      let rows = [];
      if (/RETURNING/i.test(trimmed) && result.lastInsertRowid) {
        rows = [{ id: Number(result.lastInsertRowid) }];
      }
      return {
        rows,
        rowCount: result.changes,
        lastInsertRowid: result.lastInsertRowid ? Number(result.lastInsertRowid) : null
      };
    }
  }
}

async function checkHealth() {
  try {
    const start = Date.now();
    await query('SELECT 1 as ping');
    return {
      status: 'UP',
      type: isPostgres ? 'PostgreSQL' : 'SQLite',
      latencyMs: Date.now() - start
    };
  } catch (error) {
    return {
      status: 'DOWN',
      type: isPostgres ? 'PostgreSQL' : 'SQLite',
      error: error.message
    };
  }
}

module.exports = {
  initDb,
  query,
  checkHealth,
  isPostgres: () => isPostgres
};
