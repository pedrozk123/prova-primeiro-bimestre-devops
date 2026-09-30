const { Pool, types } = require('pg');

// devolve DATE como texto "YYYY-MM-DD" em vez de objeto Date
types.setTypeParser(1082, (v) => v);

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT) || 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

async function init() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS reservas (
      id SERIAL PRIMARY KEY,
      cliente VARCHAR(100) NOT NULL,
      data DATE NOT NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'pendente'
    )`);
}

module.exports = { pool, init };