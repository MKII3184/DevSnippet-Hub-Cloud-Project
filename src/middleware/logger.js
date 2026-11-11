const morgan = require('morgan');

// Simple runtime metrics store for monitoring
const metrics = {
  totalRequests: 0,
  status2xx: 0,
  status4xx: 0,
  status5xx: 0,
  startTime: Date.now()
};

const customFormat = ':date[iso] :remote-addr ":method :url HTTP/:http-version" :status :res[content-length] - :response-time ms';

const requestLogger = morgan(customFormat, {
  stream: {
    write: (message) => {
      process.stdout.write(`[APP-LOG] ${message}`);
    }
  }
});

function metricsTracker(req, res, next) {
  metrics.totalRequests++;
  res.on('finish', () => {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      metrics.status2xx++;
    } else if (res.statusCode >= 400 && res.statusCode < 500) {
      metrics.status4xx++;
    } else if (res.statusCode >= 500) {
      metrics.status5xx++;
    }
  });
  next();
}

function getMetrics() {
  const uptimeSeconds = Math.floor((Date.now() - metrics.startTime) / 1000);
  const memory = process.memoryUsage();
  return {
    uptimeSeconds,
    totalRequests: metrics.totalRequests,
    statusCodes: {
      '2xx': metrics.status2xx,
      '4xx': metrics.status4xx,
      '5xx': metrics.status5xx
    },
    memory: {
      rssMb: Math.round((memory.rss / 1024 / 1024) * 100) / 100,
      heapUsedMb: Math.round((memory.heapUsed / 1024 / 1024) * 100) / 100,
      heapTotalMb: Math.round((memory.heapTotal / 1024 / 1024) * 100) / 100
    },
    cpuUsage: process.cpuUsage()
  };
}

module.exports = {
  requestLogger,
  metricsTracker,
  getMetrics
};
