function errorHandler(err, req, res, next) {
  console.error(`[ERROR] ${new Date().toISOString()} - ${err.stack || err.message}`);

  const statusCode = err.status || err.statusCode || 500;
  res.status(statusCode).json({
    success: false,
    error: err.message || 'Lỗi hệ thống máy chủ nội bộ.',
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack })
  });
}

function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    error: `Endpoint '${req.originalUrl}' không tồn tại trên hệ thống.`
  });
}

module.exports = {
  errorHandler,
  notFoundHandler
};
