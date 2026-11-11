const express = require('express');
const path = require('path');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const config = require('./config');
const db = require('./db/database');
const { requestLogger, metricsTracker } = require('./middleware/logger');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

const authRoutes = require('./routes/auth');
const snippetRoutes = require('./routes/snippets');
const healthRoutes = require('./routes/health');
const metricsRoutes = require('./routes/metrics');

const app = express();

// Basic middlewares
app.use(cors());
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));
app.use(cookieParser());

// Observability and logging middlewares
app.use(metricsTracker);
app.use(requestLogger);

// Serve frontend static assets
app.use(express.static(path.join(__dirname, 'public')));

// API Routes
app.use('/health', healthRoutes);
app.use('/metrics', metricsRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/snippets', snippetRoutes);

// SPA fallback: index.html
app.use((req, res, next) => {
  if (req.method === 'GET' && !req.path.startsWith('/api') && !req.path.startsWith('/health') && !req.path.startsWith('/metrics')) {
    return res.sendFile(path.join(__dirname, 'public', 'index.html'));
  }
  next();
});

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

// Server startup
async function startServer() {
  try {
    await db.initDb();
    const server = app.listen(config.port, () => {
      console.log('====================================================');
      console.log(`🚀 ${config.appName} v${config.version}`);
      console.log(`🌐 Server running at: http://localhost:${config.port}`);
      console.log(`🩺 Health check:      http://localhost:${config.port}/health`);
      console.log(`📊 Metrics monitor:   http://localhost:${config.port}/metrics`);
      console.log(`⚙️  Environment:       ${config.nodeEnv}`);
      console.log('====================================================');
    });

    const shutdown = () => {
      console.log('\n[SERVER] Gracefully shutting down...');
      server.close(() => {
        console.log('[SERVER] Closed all active connections.');
        process.exit(0);
      });
    };

    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
  } catch (err) {
    console.error('[FATAL] Failed to initialize server:', err);
    process.exit(1);
  }
}

if (require.main === module) {
  startServer();
}

module.exports = app;
