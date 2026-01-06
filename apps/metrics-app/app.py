#!/usr/bin/env python3
"""
Web Server Metrics Generator
Generates random web server metrics for Prometheus monitoring
"""

import random
import time
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Define metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total number of HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

http_active_connections = Gauge(
    'http_active_connections',
    'Number of active HTTP connections'
)

http_errors_total = Counter(
    'http_errors_total',
    'Total number of HTTP errors',
    ['error_type']
)

# Simulated endpoints
ENDPOINTS = ['/api/users', '/api/products', '/api/orders', '/api/stats', '/']
METHODS = ['GET', 'POST', 'PUT', 'DELETE']
STATUS_CODES = [200, 200, 200, 201, 204, 400, 404, 500, 503]  # More success than errors
ERROR_TYPES = ['timeout', 'connection_refused', 'bad_request', 'internal_error']

def generate_metrics():
    """Generate random web server metrics"""

    # Simulate random number of requests (10-50 requests per minute)
    num_requests = random.randint(10, 50)

    for _ in range(num_requests):
        # Random endpoint and method
        endpoint = random.choice(ENDPOINTS)
        method = random.choice(METHODS)
        status = random.choice(STATUS_CODES)

        # Increment request counter
        http_requests_total.labels(method=method, endpoint=endpoint, status=str(status)).inc()

        # Simulate request duration (0.01 to 2.0 seconds)
        duration = random.uniform(0.01, 2.0)
        http_request_duration_seconds.labels(method=method, endpoint=endpoint).observe(duration)

        # Increment error counter for error status codes
        if status >= 400:
            error_type = random.choice(ERROR_TYPES)
            http_errors_total.labels(error_type=error_type).inc()

    # Simulate active connections (0-100)
    active_conns = random.randint(0, 100)
    http_active_connections.set(active_conns)

    logger.info(f"Generated {num_requests} requests, {active_conns} active connections")

def main():
    """Main function"""
    # Start Prometheus metrics server on port 8000
    logger.info("Starting Prometheus metrics server on port 8000")
    start_http_server(8000)
    logger.info("Metrics available at http://0.0.0.0:8000/metrics")

    # Generate metrics every 60 seconds
    logger.info("Starting metrics generation (every 60 seconds)")
    while True:
        try:
            generate_metrics()
            time.sleep(60)  # Wait 60 seconds
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            break
        except Exception as e:
            logger.error(f"Error generating metrics: {e}")
            time.sleep(60)

if __name__ == '__main__':
    main()
