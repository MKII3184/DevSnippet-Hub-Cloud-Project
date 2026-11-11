const express = require('express');
const router = express.Router();
const { getMetrics } = require('../middleware/logger');

// Observability Metrics Endpoint - Section 3.3 & Step 6
router.get('/', (req, res) => {
  const metrics = getMetrics();
  res.status(200).json({
    status: 'success',
    timestamp: new Date().toISOString(),
    metrics
  });
});

module.exports = router;
