const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const dotenv = require('dotenv');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

dotenv.config();

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

app.use(cors({ origin: true, credentials: true }));
app.use(express.json());

const PORT = process.env.PORT || 3000;
const DATABASE_URL = process.env.DATABASE_URL || process.env.DATABASE_URI;
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

if (!DATABASE_URL) {
  console.error('Missing env: DATABASE_URL or DATABASE_URI');
  process.exit(1);
}
if (!JWT_SECRET) {
  console.error('Missing env: JWT_SECRET');
  process.exit(1);
}

const pool = new Pool({ connectionString: DATABASE_URL });

// ─────────────────────────────────────────────
// In-memory online users map
// Key: userId (string), Value: { socketId, name, userId }
// ─────────────────────────────────────────────
const onlineUsers = new Map();

function broadcastUsersList() {
  const usersList = Array.from(onlineUsers.values()).map(({ userId, name }) => ({
    userId,
    name,
  }));
  io.emit('users_list', usersList);
  console.log(`[Socket] Broadcasting users_list: ${usersList.length} users`);
}

// ─────────────────────────────────────────────
// Socket.IO Signaling
// ─────────────────────────────────────────────
io.on('connection', (socket) => {
  console.log(`[Socket] Client connected: ${socket.id}`);

  // User registers with their userId and name
  socket.on('register', ({ userId, name }) => {
    if (!userId || !name) return;

    // Remove any old socket entry for this userId (re-connect case)
    for (const [key, val] of onlineUsers.entries()) {
      if (val.userId === userId) {
        onlineUsers.delete(key);
        break;
      }
    }

    onlineUsers.set(socket.id, { socketId: socket.id, userId, name });
    socket.data.userId = userId;
    socket.data.name = name;

    console.log(`[Socket] User registered: ${name} (${userId}) — socket: ${socket.id}`);
    broadcastUsersList();
  });

  // ── CALL INITIATION ──────────────────────────
  socket.on('call_user', ({ targetUserId, callerName, callerId }) => {
    const target = [...onlineUsers.values()].find((u) => u.userId === targetUserId);
    if (!target) {
      socket.emit('call_error', { message: 'User is not online' });
      return;
    }
    console.log(`[Socket] ${callerName} is calling ${targetUserId}`);
    io.to(target.socketId).emit('incoming_call', {
      callerId,
      callerName,
    });
  });

  // Callee accepted the call
  socket.on('call_accepted', ({ callerId }) => {
    const caller = [...onlineUsers.values()].find((u) => u.userId === callerId);
    if (!caller) return;
    console.log(`[Socket] Call accepted — notifying caller ${callerId}`);
    io.to(caller.socketId).emit('call_accepted', {
      calleeId: socket.data.userId,
      calleeName: socket.data.name,
    });
  });

  // Callee rejected the call
  socket.on('call_rejected', ({ callerId }) => {
    const caller = [...onlineUsers.values()].find((u) => u.userId === callerId);
    if (!caller) return;
    console.log(`[Socket] Call rejected — notifying caller ${callerId}`);
    io.to(caller.socketId).emit('call_rejected', {
      calleeId: socket.data.userId,
    });
  });

  // ── WebRTC OFFER ─────────────────────────────
  socket.on('send_offer', ({ targetUserId, sdp }) => {
    const target = [...onlineUsers.values()].find((u) => u.userId === targetUserId);
    if (!target) return;
    console.log(`[Socket] Relaying offer to ${targetUserId}`);
    io.to(target.socketId).emit('receive_offer', {
      sdp,
      callerId: socket.data.userId,
    });
  });

  // ── WebRTC ANSWER ────────────────────────────
  socket.on('send_answer', ({ targetUserId, sdp }) => {
    const target = [...onlineUsers.values()].find((u) => u.userId === targetUserId);
    if (!target) return;
    console.log(`[Socket] Relaying answer to ${targetUserId}`);
    io.to(target.socketId).emit('receive_answer', {
      sdp,
      calleeId: socket.data.userId,
    });
  });

  // ── ICE CANDIDATE ────────────────────────────
  socket.on('ice_candidate', ({ targetUserId, candidate }) => {
    const target = [...onlineUsers.values()].find((u) => u.userId === targetUserId);
    if (!target) return;
    io.to(target.socketId).emit('ice_candidate', {
      candidate,
      fromUserId: socket.data.userId,
    });
  });

  // ── END CALL ─────────────────────────────────
  socket.on('end_call', ({ targetUserId }) => {
    const target = [...onlineUsers.values()].find((u) => u.userId === targetUserId);
    if (!target) return;
    console.log(`[Socket] Call ended — notifying ${targetUserId}`);
    io.to(target.socketId).emit('call_ended');
  });

  // ── DISCONNECT ───────────────────────────────
  socket.on('disconnect', () => {
    const user = onlineUsers.get(socket.id);
    if (user) {
      console.log(`[Socket] User disconnected: ${user.name} (${user.userId})`);
      onlineUsers.delete(socket.id);
      broadcastUsersList();
    } else {
      console.log(`[Socket] Unknown client disconnected: ${socket.id}`);
    }
  });
});

// ─────────────────────────────────────────────
// JWT helpers
// ─────────────────────────────────────────────
function signToken(user) {
  return jwt.sign(
    { sub: String(user.id), email: user.email },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

// ─────────────────────────────────────────────
// DB Init
// ─────────────────────────────────────────────
async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id BIGSERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
}

// ─────────────────────────────────────────────
// REST Endpoints
// ─────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ ok: true, onlineUsers: onlineUsers.size });
});

app.post('/api/auth/signup', async (req, res) => {
  try {
    const { name, email, password } = req.body || {};

    if (!name || typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({ message: 'Name is required' });
    }
    if (!email || typeof email !== 'string' || !email.trim()) {
      return res.status(400).json({ message: 'Email is required' });
    }
    if (!password || typeof password !== 'string' || password.length < 8) {
      return res.status(400).json({ message: 'Password must be at least 8 characters' });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [normalizedEmail]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ message: 'Email already exists' });
    }

    const saltRounds = 12;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    const insertRes = await pool.query(
      'INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id, name, email',
      [name.trim(), normalizedEmail, passwordHash]
    );

    const user = insertRes.rows[0];
    const token = signToken(user);

    return res.status(201).json({
      token,
      user: { id: String(user.id), name: user.name, email: user.email }
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};

    if (!email || typeof email !== 'string' || !email.trim()) {
      return res.status(400).json({ message: 'Email is required' });
    }
    if (!password || typeof password !== 'string') {
      return res.status(400).json({ message: 'Password is required' });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const userRes = await pool.query(
      'SELECT id, name, email, password_hash FROM users WHERE email = $1',
      [normalizedEmail]
    );

    const user = userRes.rows[0];
    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const token = signToken(user);

    return res.status(200).json({
      token,
      user: { id: String(user.id), name: user.name, email: user.email }
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});

// ─────────────────────────────────────────────
// Start Server
// ─────────────────────────────────────────────
initDb()
  .then(() => {
    pool.connect()
      .then(() => {
        console.log('PostgreSQL connected');
        server.listen(PORT, '0.0.0.0', () => {
          console.log(`ClearTalk server running on http://0.0.0.0:${PORT}`);
          console.log(`Local:   http://localhost:${PORT}`);
          console.log(`Network: http://192.168.1.50:${PORT}`);
          console.log(`Socket.IO signaling server ready`);
        });
      })
      .catch((err) => {
        console.error('PostgreSQL connection error:', err);
        process.exit(1);
      });
  })
  .catch((err) => {
    console.error('PostgreSQL init error:', err);
    process.exit(1);
  });
