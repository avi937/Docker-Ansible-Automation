const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;
const ENVIRONMENT = process.env.NODE_ENV || 'production';

// Track when the container started
const startTime = Date.now();

// 1. Healthcheck Endpoint (Mandatory for Container Orchestrators)
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor((Date.now() - startTime) / 1000)
  });
});

// 2. Diagnostic Dashboard Endpoint
app.get('/', (req, res) => {
  const memoryUsage = process.memoryUsage();
  
  res.status(200).json({
    message: '🚀 Production Multi-Stage Container Microservice Live!',
    version: '1.0.0',
    environment: ENVIRONMENT,
    telemetry: {
      containerHostname: os.hostname(),
      platform: os.platform(),
      architecture: os.arch(),
      cpuCores: os.cpus().length,
      nodeVersion: process.version,
      memoryAllocatedMB: (memoryUsage.heapUsed / 1024 / 1024).toFixed(2),
      uptimeSeconds: Math.floor((Date.now() - startTime) / 1000)
    },
    security: {
      currentUserUID: process.getuid ? process.getuid() : 'N/A (Windows)',
      isRoot: process.getuid ? process.getuid() === 0 : false
    }
  });
});

// 3. Start the Server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`====================================================`);
  console.log(`🚀 Production Microservice Live on Port ${PORT}`);
  console.log(`📦 Container Hostname: ${os.hostname()}`);
  console.log(`🛡️  Environment: ${ENVIRONMENT}`);
  console.log(`====================================================`);
});

// 4. Graceful Shutdown (Handling PID 1 Signals)
const handleShutdown = (signal) => {
  console.log(`\n🛑 Received ${signal}. Starting graceful shutdown...`);
  server.close(() => {
    console.log('✅ HTTP server closed cleanly. Exiting process.');
    process.exit(0);
  });

  setTimeout(() => {
    console.error('⚠️ Forcing shutdown after timeout.');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));
