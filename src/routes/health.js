const express = require('express');
const router = express.Router();
const db = require('../db/database');
const config = require('../config');

// Health Check Endpoint - Section 3.1 & Test Case T5
router.get('/', async (req, res) => {
  const dbHealth = await db.checkHealth();
  const isHealthy = dbHealth.status === 'UP';

  const healthData = {
    status: isHealthy ? 'UP' : 'DEGRADED',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    service: config.appName,
    version: config.version,
    environment: config.nodeEnv,
    database: dbHealth
  };

  return res.status(isHealthy ? 200 : 503).json(healthData);
});

module.exports = router;
