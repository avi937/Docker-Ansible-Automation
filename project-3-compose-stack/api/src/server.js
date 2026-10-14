const express = require('express');
const Redis = require('ioredis');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;
const REDIS_HOST = process.env.REDIS_HOST || 'redis-cache';
const REDIS_PORT = process.env.REDIS_PORT || 6379;

// Initialize Redis Client using Docker Embedded DNS
const redis = new Redis({
    host: REDIS_HOST,
    port: REDIS_PORT,
    connectTimeout: 5000,
    maxRetriesPerRequest: 3,
    retryStrategy: (times) => Math.min(times * 100, 3000)
});

let redisConnected = false;

redis.on('connect', () => {
    redisConnected = true;
    console.log(`[REDIS] Successfully connected to Redis at ${REDIS_HOST}:${REDIS_PORT}`);
});

redis.on('error', (err) => {
    redisConnected = false;
    console.error(`[REDIS] Connection error: ${err.message}`);
});

// Helper: Simulate an expensive database lookup (500ms)
const fetchFromSlowDatabase = async (userId) => {
    await new Promise((resolve) => setTimeout(resolve, 500));
    return {
        id: userId,
        name: `Customer Account #${userId}`,
        tier: 'ENTERPRISE_GOLD',
        generatedAt: new Date().toISOString()
    };
};

// 1. Root Telemetry & Diagnostic Endpoint
app.get('/', (req, res) => {
    res.json({
        message: '🚀 Microservices API Service Online',
        service: 'backend-api',
        container: {
            hostname: os.hostname(),
            platform: os.platform(),
            uptimeSeconds: Math.floor(process.uptime()),
            memoryUsageMB: (process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2)
        },
        redisStatus: redisConnected ? 'CONNECTED' : 'DISCONNECTED'
    });
});

// 2. High-Performance Caching Endpoint
app.get('/api/users/:id', async (req, res) => {
    const userId = req.params.id;
    const cacheKey = `user:${userId}`;
    const startTime = Date.now();

    try {
        // Step A: Check Redis In-Memory Cache
        const cachedData = await redis.get(cacheKey);

        if (cachedData) {
            const latencyMs = Date.now() - startTime;
            return res.json({
                source: 'REDIS_CACHE_HIT ⚡',
                latencyMs: `${latencyMs}ms (Instant In-Memory)`,
                data: JSON.parse(cachedData)
            });
        }

        // Step B: Cache Miss -> Fetch from Slow "Database"
        const dbData = await fetchFromSlowDatabase(userId);

        // Step C: Save to Redis with 60-Second TTL (Time-To-Live)
        await redis.set(cacheKey, JSON.stringify(dbData), 'EX', 60);

        const latencyMs = Date.now() - startTime;
        return res.json({
            source: 'DATABASE_CACHE_MISS 🐢',
            latencyMs: `${latencyMs}ms (Slow DB Fetch, now cached for 60s)`,
            data: dbData
        });
    } catch (error) {
        return res.status(500).json({ error: error.message });
    }
});

// 3. Healthcheck Endpoint (Used by Docker Compose Healthcheck)
app.get('/health', async (req, res) => {
    try {
        const pingResponse = await redis.ping();
        if (pingResponse === 'PONG') {
            return res.status(200).json({
                status: 'healthy',
                redis: 'connected',
                timestamp: new Date().toISOString()
            });
        }
        throw new Error('Redis ping did not return PONG');
    } catch (err) {
        return res.status(503).json({
            status: 'unhealthy',
            redis: 'disconnected',
            error: err.message
        });
    }
});

// Start Express Server
const server = app.listen(PORT, () => {
    console.log(`[API] Microservice listening on port ${PORT}`);
});

// Graceful Shutdown Handler (Catches SIGTERM from Docker)
process.on('SIGTERM', () => {
    console.log('[API] SIGTERM received. Closing HTTP server and Redis connection...');
    server.close(() => {
        redis.disconnect();
        console.log('[API] Server and Redis closed cleanly. Exiting.');
        process.exit(0);
    });
});
