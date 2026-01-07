# SmartBiz Application Documentation

## Overview

SmartBiz is a complete business management application running on Kubernetes with full observability. It provides inventory management, customer tracking, and order processing with real-time stock management and business metrics.

## Architecture

```
┌──────────────────┐
│  Internet Users  │
└────────┬─────────┘
         │
         ↓
┌────────────────────┐
│ Cloudflare Tunnel  │  (Public HTTPS access)
└────────┬───────────┘
         │
         ↓
┌────────────────────┐
│   Nginx (UI)       │  Port 80
│  - HTML/CSS/JS     │
│  - Proxy /api/*    │
└────────┬───────────┘
         │
         ↓
┌────────────────────┐
│  FastAPI Backend   │  Port 8000
│  - CRUD API        │
│  - Stock Mgmt      │
│  - Prometheus      │
└────────┬───────────┘
         │
         ↓
┌────────────────────┐
│   PostgreSQL 15    │  Port 5432
│  - Articles        │
│  - Customers       │
│  - Orders          │
└────────────────────┘
```

## Components

### 1. Database (PostgreSQL 15)
- **Namespace:** `smartbiz`
- **Storage:** 5Gi PersistentVolume
- **Credentials:** `smartbiz` / `smartbiz123`
- **Image:** `postgres:15-alpine`

**Tables:**
- `articles` - Product inventory with stock tracking
- `customers` - Customer information
- `orders` - Purchase orders with foreign keys

### 2. Backend API (FastAPI + Python 3.11)
- **Namespace:** `smartbiz`
- **Image:** `python:3.11-slim`
- **Port:** 8000
- **Database ORM:** SQLAlchemy
- **Features:**
  - Full CRUD operations for articles, customers, orders
  - Stock management (PATCH endpoint)
  - Category suggestion helper
  - Email validation helper
  - Prometheus metrics export
  - Structured JSON logging (for Loki)

**Key Endpoints:**
```
GET    /health                      - Health check
GET    /stats                       - Database statistics
GET    /metrics                     - Prometheus metrics

GET    /articles                    - List all articles
POST   /articles                    - Create article
GET    /articles/{id}               - Get article by ID
PATCH  /articles/{id}/stock         - Update stock (+/- any amount)

GET    /customers                   - List all customers
POST   /customers                   - Create customer
GET    /customers/{id}              - Get customer by ID

GET    /orders                      - List all orders
POST   /orders                      - Create order (auto-reduces stock)
GET    /orders/{id}                 - Get order by ID

POST   /ai/suggest-category         - Helper: Suggest article category
POST   /ai/validate-email           - Helper: Validate email format
```

**Prometheus Metrics:**
- `smartbiz_requests_total` - Counter: Total HTTP requests by method/endpoint/status
- `smartbiz_request_duration_seconds` - Histogram: Request latency
- `smartbiz_articles_total` - Gauge: Total number of articles
- `smartbiz_customers_total` - Gauge: Total number of customers
- `smartbiz_orders_total` - Counter: Total number of orders created
- `smartbiz_orders_today` - Gauge: Orders created today
- `smartbiz_revenue_total` - Counter: Total revenue in EUR

### 3. Frontend UI (Nginx + Vanilla JS)
- **Namespace:** `smartbiz`
- **Image:** `nginx:alpine`
- **Port:** 80

**Features:**
- Single-page application with tabbed interface
- Real-time data loading
- Stock adjustment buttons (-10, -1, +1, +10)
- Category suggestion helper
- Email validation helper
- Dashboard with live statistics
- Notification system
- EUR currency display

**Tabs:**
1. **Articles** - Add/view articles with stock management
2. **Customers** - Add/view customer records
3. **Orders** - Create orders from existing articles & customers
4. **Dashboard** - Real-time business statistics

### 4. External Access (Cloudflare Tunnel)
- **Namespace:** `smartbiz`
- **Image:** `erisamoe/cloudflared:latest`
- **Purpose:** Provides public HTTPS access without port forwarding

**Quick Tunnel URL:** Auto-generated on pod start (check logs for URL)

### 5. Monitoring & Observability

**Prometheus:**
- Scrapes SmartBiz API every 30 seconds
- Job: `smartbiz-api`
- Target: `smartbiz-api.smartbiz.svc.cluster.local:8000/metrics`

**Grafana Dashboard:**
- **Name:** "SmartBiz Business Metrics"
- **Metrics:**
  - Total Articles (Gauge)
  - Total Customers (Gauge)
  - Total Orders (Counter)
  - Total Revenue (Counter, in EUR)
  - Orders Today (Gauge with thresholds)
  - Orders Rate (per hour)
  - Revenue Growth (per hour)
  - API Request Rate (by method)
  - API Response Time (p95)

## Deployment Structure

```
apps/smartbiz-db/
├── namespace.yaml          - Creates 'smartbiz' namespace
├── secret.yaml            - PostgreSQL credentials
├── pvc.yaml               - 5Gi persistent volume claim
├── deployment.yaml        - PostgreSQL deployment
├── service.yaml           - Internal service (port 5432)
└── kustomization.yaml     - Kustomize config

apps/smartbiz-api/
├── configmap.yaml         - Complete FastAPI application code
├── deployment.yaml        - API deployment with init container
├── service.yaml           - Internal service (port 8000)
└── kustomization.yaml     - Kustomize config

apps/smartbiz-ui/
├── configmap.yaml         - HTML/CSS/JavaScript files
├── nginx-config.yaml      - Nginx configuration with /api proxy
├── deployment.yaml        - Nginx deployment
├── service.yaml           - Internal service (port 80)
├── ingress.yaml           - Traefik ingress (smartbiz.local)
├── cloudflared-deployment.yaml  - Cloudflare tunnel
└── kustomization.yaml     - Kustomize config
```

## Usage Guide

### Access Methods

**Public Internet (Cloudflare):**
```bash
# Get the public URL from cloudflared logs
kubectl logs -n smartbiz -l app=cloudflared-smartbiz | grep trycloudflare.com

# Example URL: https://leslie-shortcuts-jokes-cart.trycloudflare.com
```

**Local Network (NodePort):**
```
http://smartbiz.local:30683
http://<cluster-ip>:30683  (direct node IP)
```

### Common Operations

**1. Add an Article:**
- Go to Articles tab
- Fill in: Name, Category, Description, Price, Stock
- Click "Suggest Category" for auto-suggestion
- Click "Add Article"

**2. Adjust Stock:**
- In Articles list, use buttons:
  - `-10` - Decrease by 10
  - `-1` - Decrease by 1
  - `+1` - Increase by 1
  - `+10` - Increase by 10

**3. Add a Customer:**
- Go to Customers tab
- Fill in: Name, Email, Phone, Address
- Click "Validate" to check email format
- Click "Add Customer"

**4. Create an Order:**
- Go to Orders tab
- Select customer from dropdown
- Select article from dropdown (shows price & stock)
- Enter quantity
- Click "Create Order"
- **Stock automatically reduces**
- Order status is set to "Done"

**5. View Statistics:**
- Go to Dashboard tab
- See real-time counts:
  - Total Articles
  - Total Customers
  - Total Orders
  - Total Revenue (in €)

### Database Access

```bash
# Connect to PostgreSQL
kubectl exec -it -n smartbiz deployment/postgres -- psql -U smartbiz -d smartbiz

# View tables
\dt

# Query articles
SELECT * FROM articles;

# Query orders with details
SELECT o.id, c.name as customer, a.name as article, o.quantity, o.total_price, o.status
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN articles a ON o.article_id = a.id;
```

### API Testing

```bash
# Port-forward API
kubectl port-forward -n smartbiz svc/smartbiz-api 8000:8000

# Get statistics
curl http://localhost:8000/stats

# List articles
curl http://localhost:8000/articles

# Create article
curl -X POST http://localhost:8000/articles \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Gaming Laptop",
    "description": "High-performance laptop",
    "price": 1299.99,
    "category": "Electronics",
    "stock": 5
  }'

# Update stock (+5)
curl -X PATCH 'http://localhost:8000/articles/1/stock?stock_change=5'

# Update stock (-3)
curl -X PATCH 'http://localhost:8000/articles/1/stock?stock_change=-3'

# Get Prometheus metrics
curl http://localhost:8000/metrics
```

## Grafana Dashboard Setup

1. Access Grafana (via your existing setup)
2. Navigate to Dashboards
3. Find "SmartBiz Business Metrics"
4. View real-time business metrics

**Note:** Metrics will show 0 until you create customers and orders!

## Security Features

1. **Database:**
   - Credentials stored in Kubernetes Secret
   - Not exposed externally (ClusterIP service)

2. **API:**
   - Input validation via Pydantic
   - SQL injection protection (SQLAlchemy ORM)
   - Stock validation (prevents negative values)

3. **Frontend:**
   - HTTPS via Cloudflare Tunnel
   - Form validation
   - Error handling

## Troubleshooting

### Pod not starting?
```bash
# Check pod status
kubectl get pods -n smartbiz

# Check logs
kubectl logs -n smartbiz deployment/smartbiz-api --tail=50
kubectl logs -n smartbiz deployment/smartbiz-ui --tail=50

# Check events
kubectl describe pod -n smartbiz <pod-name>
```

### API returning 404?
```bash
# Verify ConfigMap is updated
kubectl get configmap smartbiz-api-code -n smartbiz -o yaml | grep -c "PATCH"

# Should return 1 or more

# Restart API pod
kubectl delete pod -n smartbiz -l app=smartbiz-api
```

### Metrics not in Prometheus?
```bash
# Check if Prometheus is scraping
kubectl port-forward -n prometheus svc/prometheus-server 9090:80
# Open http://localhost:9090/targets
# Look for "smartbiz-api" target

# Test metrics endpoint directly
kubectl exec -n smartbiz deployment/smartbiz-api -- \
  curl -s http://localhost:8000/metrics | grep smartbiz_
```

### Cloudflare Tunnel URL?
```bash
# Get the public URL
kubectl logs -n smartbiz -l app=cloudflared-smartbiz | grep trycloudflare.com
```

## Resource Usage

**Typical resource consumption:**
- PostgreSQL: ~200MB RAM, ~50m CPU
- FastAPI: ~150MB RAM, ~100m CPU (during startup), ~50m CPU (idle)
- Nginx: ~20MB RAM, ~10m CPU
- Cloudflared: ~30MB RAM, ~10m CPU

**Total for SmartBiz stack:** ~400MB RAM, ~120m CPU

## Backup & Recovery

### Database Backup
```bash
# Dump database
kubectl exec -n smartbiz deployment/postgres -- \
  pg_dump -U smartbiz smartbiz > smartbiz_backup.sql

# Restore database
kubectl exec -i -n smartbiz deployment/postgres -- \
  psql -U smartbiz smartbiz < smartbiz_backup.sql
```

## Future Enhancements

Potential improvements:
1. User authentication (JWT/OAuth)
2. Multi-tenancy support
3. Advanced reporting (PDF exports)
4. Email notifications for low stock
5. Barcode scanning integration
6. Advanced analytics
7. Named Cloudflare Tunnel (permanent URL)
8. Automated backups to S3/MinIO

## License

Part of Raspberry Pi Kubernetes Homelab project.
