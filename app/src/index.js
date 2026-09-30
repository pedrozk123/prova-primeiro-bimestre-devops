const express = require('express');
const { pool, init } = require('./db');

const app = express();
app.use(express.json());

const STATUS_VALIDOS = ['pendente', 'confirmada', 'cancelada'];

function validar(body) {
  const { cliente, data, status } = body;
  if (!cliente || !data) return 'Campos obrigatórios: cliente e data';
  if (status && !STATUS_VALIDOS.includes(status))
    return `status deve ser um de: ${STATUS_VALIDOS.join(', ')}`;
  return null;
}

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.post('/reservas', async (req, res) => {
  const erro = validar(req.body);
  if (erro) return res.status(400).json({ erro });
  const { cliente, data, status = 'pendente' } = req.body;
  try {
    const r = await pool.query(
      'INSERT INTO reservas (cliente, data, status) VALUES ($1, $2, $3) RETURNING *',
      [cliente, data, status]
    );
    res.status(201).json(r.rows[0]);
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

app.get('/reservas', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM reservas ORDER BY id');
    res.json(r.rows);
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

app.get('/reservas/:id', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM reservas WHERE id = $1', [req.params.id]);
    if (r.rows.length === 0) return res.status(404).json({ erro: 'Reserva não encontrada' });
    res.json(r.rows[0]);
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

app.put('/reservas/:id', async (req, res) => {
  const erro = validar(req.body);
  if (erro) return res.status(400).json({ erro });
  const { cliente, data, status = 'pendente' } = req.body;
  try {
    const r = await pool.query(
      'UPDATE reservas SET cliente = $1, data = $2, status = $3 WHERE id = $4 RETURNING *',
      [cliente, data, status, req.params.id]
    );
    if (r.rows.length === 0) return res.status(404).json({ erro: 'Reserva não encontrada' });
    res.json(r.rows[0]);
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

app.delete('/reservas/:id', async (req, res) => {
  try {
    const r = await pool.query('DELETE FROM reservas WHERE id = $1 RETURNING id', [req.params.id]);
    if (r.rows.length === 0) return res.status(404).json({ erro: 'Reserva não encontrada' });
    res.status(204).send();
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

const PORT = process.env.PORT || 3000;
init()
  .then(() => app.listen(PORT, () => console.log(`API rodando na porta ${PORT}`)))
  .catch((e) => {
    console.error('Falha ao iniciar:', e.message);
    process.exit(1);
  });