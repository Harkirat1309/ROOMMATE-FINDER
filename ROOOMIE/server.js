
require('dotenv').config();
const express  = require('express');
const mysql    = require('mysql2/promise');
const bcrypt   = require('bcryptjs');
const cors     = require('cors');

const app  = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

const pool = mysql.createPool({
    host:            process.env.DB_HOST     || 'localhost',
    port:            process.env.DB_PORT     || 3306,
    user:            process.env.DB_USER     || 'root',
    password:        process.env.DB_PASSWORD || '',
    database:        process.env.DB_NAME     || 'main_system_db',
    waitForConnections: true,
    connectionLimit:    10,
    timezone:           'Z',
    charset:            'utf8mb4'
});

// Helper: run a query and return rows
async function query(sql, params = []) {
    const [rows] = await pool.execute(sql, params);
    return rows;
}

// Helper: call stored procedure
async function callProc(name, params = []) {
    const placeholders = params.map(() => '?').join(',');
    const [rows] = await pool.execute(`CALL ${name}(${placeholders})`, params);
    return rows;
}

const asyncHandler = fn => (req, res, next) =>
    Promise.resolve(fn(req, res, next)).catch(next);


// GET /api/users — all active users
app.get('/api/users', asyncHandler(async (req, res) => {
    const { status, gender, search } = req.query;
    let sql = 'SELECT * FROM vw_all_users WHERE 1=1';
    const params = [];

    if (status) { sql += ' AND status = ?';  params.push(status); }
    if (gender) { sql += ' AND gender = ?';  params.push(gender); }
    if (search) {
        sql += ' AND (name LIKE ? OR email LIKE ?)';
        params.push(`%${search}%`, `%${search}%`);
    }

    const rows = await query(sql, params);
    res.json({ success: true, count: rows.length, data: rows });
}));

// GET /api/users/:id — single user
app.get('/api/users/:id', asyncHandler(async (req, res) => {
    const rows = await query(
        'SELECT * FROM vw_all_users WHERE user_id = ?',
        [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });
    res.json({ success: true, data: rows[0] });
}));

// POST /api/users — register new user
app.post('/api/users', asyncHandler(async (req, res) => {
    const { name, email, password, phone, gender, bio } = req.body;

    if (!name || !email || !password)
        return res.status(400).json({ error: 'name, email, password required' });
    if (password.length < 8)
        return res.status(400).json({ error: 'Password must be at least 8 characters' });

    const hash = await bcrypt.hash(password, 12);

    const conn = await pool.getConnection();
    try {
        await conn.execute(
            'CALL sp_create_user(?,?,?,?,?,?,@uid)',
            [name, email, hash, phone||null, gender||null, bio||null]
        );
        const [[{ uid }]] = await conn.execute('SELECT @uid AS uid');
        res.status(201).json({ success: true, user_id: uid, message: 'User registered' });
    } catch (err) {
        if (err.sqlState === '45001')
            return res.status(409).json({ error: 'Email already registered' });
        throw err;
    } finally { conn.release(); }
}));

// PUT /api/users/:id — update user
app.put('/api/users/:id', asyncHandler(async (req, res) => {
    const { name, phone, gender, bio } = req.body;
    await callProc('sp_update_user', [req.params.id, name, phone, gender, bio]);
    res.json({ success: true, message: 'User updated' });
}));

// DELETE /api/users/:id — soft or hard delete
app.delete('/api/users/:id', asyncHandler(async (req, res) => {
    const { hard = false, admin_id = 1 } = req.body;
    await callProc('sp_delete_user', [req.params.id, hard ? 1 : 0, admin_id]);
    res.json({ success: true, message: hard ? 'User deleted' : 'User deactivated' });
}));

// PUT /api/users/:id/profile — save lifestyle profile
app.put('/api/users/:id/profile', asyncHandler(async (req, res) => {
    const { food_preference, sleep_schedule, cleanliness_level,
            study_habit, social_type, hobbies, location, occupation } = req.body;
    await callProc('sp_save_profile', [
        req.params.id,
        food_preference || 'Any',
        sleep_schedule  || 'Flexible',
        cleanliness_level || 3,
        study_habit     || 'Flexible',
        social_type     || 'Ambivert',
        hobbies         || null,
        location        || null,
        occupation      || null
    ]);
    res.json({ success: true, message: 'Profile saved' });
}));


// GET /api/pairings — all pairings (filterable)
app.get('/api/pairings', asyncHandler(async (req, res) => {
    const { status } = req.query;
    let sql = 'SELECT * FROM vw_all_pairings';
    const params = [];
    if (status) { sql += ' WHERE pairing_status = ?'; params.push(status); }

    const rows = await query(sql, params);
    res.json({ success: true, count: rows.length, data: rows });
}));

// GET /api/pairings/user/:id — pairings for a specific user
app.get('/api/pairings/user/:id', asyncHandler(async (req, res) => {
    const rows = await query(
        'SELECT * FROM vw_all_pairings WHERE user_id_1 = ? OR user_id_2 = ?',
        [req.params.id, req.params.id]
    );
    res.json({ success: true, data: rows });
}));

// POST /api/pairings — send pairing request
app.post('/api/pairings', asyncHandler(async (req, res) => {
    const { from_user_id, to_user_id, message } = req.body;
    if (!from_user_id || !to_user_id)
        return res.status(400).json({ error: 'from_user_id and to_user_id required' });

    const conn = await pool.getConnection();
    try {
        await conn.execute(
            'CALL sp_send_pairing_request(?,?,?,@pid)',
            [from_user_id, to_user_id, message || null]
        );
        const [[{ pid }]] = await conn.execute('SELECT @pid AS pid');
        res.status(201).json({ success: true, pairing_id: pid, message: 'Request sent' });
    } catch (err) {
        if (err.sqlState === '45003') return res.status(400).json({ error: err.message });
        if (err.sqlState === '45005') return res.status(409).json({ error: err.message });
        throw err;
    } finally { conn.release(); }
}));

// PATCH /api/pairings/:id/respond — accept or reject
app.patch('/api/pairings/:id/respond', asyncHandler(async (req, res) => {
    const { user_id, action } = req.body;  // action: 'accept' | 'reject'
    if (!user_id || !action)
        return res.status(400).json({ error: 'user_id and action required' });

    try {
        await callProc('sp_respond_to_pairing', [req.params.id, user_id, action]);
        res.json({ success: true, message: `Pairing ${action}ed` });
    } catch (err) {
        if (['45006','45007','45008','45009'].includes(err.sqlState))
            return res.status(400).json({ error: err.message });
        throw err;
    }
}));

// PATCH /api/pairings/:id/cancel — cancel sent request
app.patch('/api/pairings/:id/cancel', asyncHandler(async (req, res) => {
    const { user_id } = req.body;
    await callProc('sp_cancel_pairing', [req.params.id, user_id]);
    res.json({ success: true, message: 'Pairing cancelled' });
}));

// GET /api/compatibility/:id1/:id2 — score between two users
app.get('/api/compatibility/:id1/:id2', asyncHandler(async (req, res) => {
    const rows = await query(
        'SELECT fn_compatibility_score(?, ?) AS score',
        [req.params.id1, req.params.id2]
    );
    res.json({ success: true, score: rows[0].score });
}));


// GET /api/stats — dashboard summary
app.get('/api/stats', asyncHandler(async (req, res) => {
    const rows = await query('SELECT * FROM vw_dashboard_stats');
    res.json({ success: true, data: rows[0] });
}));

// GET /api/activity — recent activity log
app.get('/api/activity', asyncHandler(async (req, res) => {
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const rows = await query(
        `SELECT log_id, created_at, action, entity_type,
                message, status, new_values
         FROM   activity_logs
         ORDER  BY created_at DESC LIMIT ?`,
        [limit]
    );
    res.json({ success: true, data: rows });
}));

// GET /api/users/available — users without active pairing
app.get('/api/users/available', asyncHandler(async (req, res) => {
    const rows = await query('SELECT * FROM vw_available_users');
    res.json({ success: true, count: rows.length, data: rows });
}));

app.use((err, req, res, _next) => {
    console.error('API Error:', err.message);
    res.status(500).json({ success: false, error: err.message || 'Internal server error' });
});

app.listen(PORT, () => {
    console.log(`\n🚀 Server running on http://localhost:${PORT}`);
    console.log('─'.repeat(50));
    console.log('  USERS');
    console.log('  GET    /api/users              All users');
    console.log('  GET    /api/users/:id           Single user');
    console.log('  POST   /api/users              Register user');
    console.log('  PUT    /api/users/:id           Update user');
    console.log('  DELETE /api/users/:id           Delete user');
    console.log('  PUT    /api/users/:id/profile   Save profile');
    console.log('─'.repeat(50));
    console.log('  PAIRINGS');
    console.log('  GET    /api/pairings            All pairings');
    console.log('  POST   /api/pairings            Send request');
    console.log('  PATCH  /api/pairings/:id/respond  Accept/Reject');
    console.log('  PATCH  /api/pairings/:id/cancel   Cancel');
    console.log('  GET    /api/compatibility/:a/:b   Score');
    console.log('─'.repeat(50));
    console.log('  MISC');
    console.log('  GET    /api/stats               Dashboard stats');
    console.log('  GET    /api/activity            Activity log');
    console.log('─'.repeat(50));
});
