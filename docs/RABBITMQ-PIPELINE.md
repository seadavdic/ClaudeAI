# RabbitMQ Order Processing Pipeline

Event-driven microservices architecture for processing e-commerce orders using RabbitMQ message broker.

## Overview

This system simulates a complete order processing pipeline with four microservices communicating through RabbitMQ:

- **Order Generator**: Creates simulated customer orders
- **Payment Service**: Processes payments (90% success rate)
- **Fulfillment Service**: Creates shipments for successful payments
- **Notification Service**: Sends notifications for all events

## Architecture

```
┌─────────────────┐
│ Order Generator │
│  (1 replica)    │
└────────┬────────┘
         │ publishes
         ▼
    ┌────────┐
    │ orders │ exchange (fanout)
    └───┬─┬──┘
        │ │
    ┌───┘ └────────────────────────┐
    │                              │
    ▼                              ▼
┌─────────────────────┐  ┌────────────────────────┐
│payment_processor    │  │notifications_orders    │
│     _queue          │  │     _queue             │
└──────────┬──────────┘  └───────────┬────────────┘
           │                         │
           ▼                         ▼
    ┌─────────────┐          ┌─────────────────┐
    │  Payment    │          │  Notification   │
    │  Service    │          │    Service      │
    │ (2 replicas)│          │  (thread 1)     │
    └──────┬──────┘          └─────────────────┘
           │ publishes
           ▼
      ┌──────────┐
      │ payments │ exchange (fanout)
      └────┬─┬───┘
           │ │
    ┌──────┘ └────────────────────────┐
    │                                 │
    ▼                                 ▼
┌──────────────────────┐  ┌─────────────────────────┐
│fulfillment_processor │  │notifications_payments   │
│      _queue          │  │       _queue            │
└──────────┬───────────┘  └──────────┬──────────────┘
           │                         │
           ▼                         ▼
    ┌─────────────┐          ┌─────────────────┐
    │ Fulfillment │          │  Notification   │
    │   Service   │          │    Service      │
    │ (1 replica) │          │  (thread 2)     │
    └──────┬──────┘          └─────────────────┘
           │ publishes
           ▼
      ┌───────────┐
      │ shipments │ exchange (fanout)
      └─────┬─────┘
            │
            ▼
┌──────────────────────────┐
│notifications_shipments   │
│        _queue            │
└─────────────┬────────────┘
              │
              ▼
       ┌─────────────────┐
       │  Notification   │
       │    Service      │
       │  (thread 3)     │
       └─────────────────┘
```

## Services

### 1. Order Generator
- **Port**: 8000 (Prometheus metrics)
- **Replicas**: 1
- **Function**: Generates 1-5 simulated orders every 10-20 seconds
- **Products**: 8 different products (Laptop Pro, Mouse, Keyboard, Monitor, etc.)
- **Customers**: 6 simulated customer emails
- **Output**: Publishes to `orders` exchange

**Metrics**:
- `orders_generated_total` - Counter of total orders generated
- `orders_per_second` - Current order generation rate

### 2. Payment Service
- **Port**: 8001 (Prometheus metrics)
- **Replicas**: 2 (load balanced)
- **Function**: Processes payments with 90% success rate
- **Processing Time**: 0.5-2.0 seconds
- **Input**: Consumes from `payment_processor_queue`
- **Output**: Publishes to `payments` exchange

**Payment Methods**: Credit card, PayPal, Bank transfer

**Failure Reasons**: Insufficient funds, Card expired, Fraud detected, Network error

**Metrics**:
- `payments_processed_total{status}` - Counter by success/failed
- `payment_processing_duration_seconds` - Histogram of processing time
- `payment_amount_total{status}` - Counter of payment amounts

### 3. Fulfillment Service
- **Port**: 8002 (Prometheus metrics)
- **Replicas**: 1
- **Function**: Creates shipments for successful payments only
- **Processing Time**: 1.0-3.0 seconds
- **Input**: Consumes from `fulfillment_processor_queue`
- **Output**: Publishes to `shipments` exchange

**Carriers**: DHL, FedEx, UPS, USPS

**Delivery**: 2-7 days estimated

**Metrics**:
- `shipments_created_total` - Counter of total shipments
- `fulfillment_processing_duration_seconds` - Histogram of processing time

### 4. Notification Service
- **Port**: 8003 (Prometheus metrics)
- **Replicas**: 1 (multi-threaded)
- **Function**: Sends notifications for all events across 3 threads
- **Thread Safety**: Each thread has separate RabbitMQ connection
- **Input**: Consumes from 3 queues simultaneously

**Notification Types**:
- `order_confirmation` - Order received
- `payment_success` - Payment successful
- `payment_failed` - Payment failed with reason
- `shipment_notification` - Order shipped with tracking

**Metrics**:
- `notifications_sent_total{type,topic}` - Counter by notification type and topic

## Queue Structure

All queues are **durable** (survive RabbitMQ restarts) and use **manual acknowledgment**.

| Queue Name | Bound To | Consumer | Purpose |
|------------|----------|----------|---------|
| `payment_processor_queue` | orders | payment-service (2 replicas) | Process order payments |
| `fulfillment_processor_queue` | payments | fulfillment-service | Create shipments for successful payments |
| `notifications_orders_queue` | orders | notification-service (thread 1) | Send order confirmation notifications |
| `notifications_payments_queue` | payments | notification-service (thread 2) | Send payment status notifications |
| `notifications_shipments_queue` | shipments | notification-service (thread 3) | Send shipment tracking notifications |

## Message Flow

### Example Order Flow

1. **Order Generated** (Order Generator → orders exchange)
   ```json
   {
     "order_id": 42,
     "customer_email": "alice@example.com",
     "items": [
       {"product_id": 1, "name": "Laptop Pro 15", "price": 1299.99, "quantity": 1}
     ],
     "total_amount": 1299.99,
     "currency": "EUR",
     "timestamp": "2026-01-07T10:30:00Z",
     "status": "pending"
   }
   ```

2. **Payment Processed** (Payment Service → payments exchange)
   ```json
   {
     "order_id": 42,
     "customer_email": "alice@example.com",
     "amount": 1299.99,
     "currency": "EUR",
     "status": "success",
     "payment_method": "credit_card",
     "transaction_id": "TXN-42-1736244600",
     "timestamp": "2026-01-07T10:30:02Z",
     "processing_time": 1.23,
     "failure_reason": null
   }
   ```

3. **Shipment Created** (Fulfillment Service → shipments exchange)
   ```json
   {
     "order_id": 42,
     "customer_email": "alice@example.com",
     "tracking_number": "TRACK-42-1736244605",
     "carrier": "DHL",
     "estimated_delivery": "2026-01-12T10:30:05Z",
     "status": "shipped",
     "timestamp": "2026-01-07T10:30:05Z"
   }
   ```

4. **Notifications Sent** (Notification Service)
   - Order confirmation: "Order #42 received - Total: €1299.99"
   - Payment success: "Payment successful for order #42"
   - Shipment notification: "Order #42 shipped - Tracking: TRACK-42-1736244605"

## Dependencies

### Python Libraries
- `pika==1.3.2` - RabbitMQ client library
- `prometheus_client==0.19.0` - Metrics exposition
- `flask==3.0.0` - Web framework (if needed for health checks)

### Infrastructure
- **RabbitMQ**: 3.13-management-alpine
  - Host: `rabbitmq.rabbitmq.svc.cluster.local`
  - Port: 5672 (AMQP)
  - Credentials: admin/***
  - Heartbeat: 600s
  - Connection timeout: 300s

## Deployment

### Prerequisites
- Kubernetes cluster (tested on ARM32/Raspberry Pi)
- RabbitMQ deployed in `rabbitmq` namespace
- Flux CD for GitOps deployment

### Deploy Pipeline

```bash
# Apply with kubectl
kubectl apply -k apps/order-pipeline/

# Or commit to Git for Flux CD
git add apps/order-pipeline/
git commit -m "Deploy order processing pipeline"
git push
```

### Files Structure
```
apps/order-pipeline/
├── namespace.yaml               # Creates order-pipeline namespace
├── configmap.yaml               # Contains all Python code (450 lines)
│   ├── requirements.txt
│   ├── common.py
│   ├── order_generator.py
│   ├── payment_service.py
│   ├── fulfillment_service.py
│   └── notification_service.py
├── deployments.yaml             # 4 Deployments (250 lines)
├── services.yaml                # 4 Services for metrics (80 lines)
└── kustomization.yaml           # Kustomize configuration
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n order-pipeline

# Expected output:
# NAME                                    READY   STATUS    RESTARTS
# order-generator-xxx                     1/1     Running   0
# payment-service-xxx                     1/1     Running   0
# payment-service-yyy                     1/1     Running   0
# fulfillment-service-xxx                 1/1     Running   0
# notification-service-xxx                1/1     Running   0

# View logs
kubectl logs -n order-pipeline -l app=order-generator -f
kubectl logs -n order-pipeline -l app=payment-service -f
kubectl logs -n order-pipeline -l app=fulfillment-service -f
kubectl logs -n order-pipeline -l app=notification-service -f
```

## Monitoring

### Prometheus Metrics Endpoints

Each service exposes metrics on its dedicated port:

- Order Generator: `http://order-generator.order-pipeline:8000/metrics`
- Payment Service: `http://payment-service.order-pipeline:8001/metrics`
- Fulfillment Service: `http://fulfillment-service.order-pipeline:8002/metrics`
- Notification Service: `http://notification-service.order-pipeline:8003/metrics`

### Grafana Dashboard

Access the "RabbitMQ & Order Pipeline" dashboard at:
- URL: `http://grafana.local:30683`
- Dashboard: Search for "RabbitMQ & Order Pipeline"
- Refresh: 10 seconds

**Dashboard Sections**:
1. RabbitMQ Metrics (9 panels)
   - Total queued messages
   - Message rates (ready, unacked, published, delivered)
   - Queue depths by queue
   - Active connections and channels
   - Memory usage

2. Order Pipeline Metrics (13 panels)
   - Orders generated (total, rate)
   - Payment metrics (total, success rate, processing time, amounts)
   - Fulfillment metrics (shipments, processing time)
   - Notification metrics (sent by type)

### RabbitMQ Management UI

Access the RabbitMQ management interface:
- URL: `http://rabbitmq.local:30683`
- Username: `admin`
- Password: `***`

**Note**: Add to hosts file (as Administrator):
```powershell
echo '<cluster-ip> rabbitmq.local' | Out-File -Append -Encoding ASCII C:\Windows\System32\drivers\etc\hosts
```

**Features**:
- View all exchanges and queues
- Monitor message rates in real-time
- See consumer connections
- Inspect message contents
- View queue bindings

## Reliability Features

### Connection Resilience
- **Retry Logic**: 10 attempts with 5-second delays
- **Heartbeat**: 600 seconds to detect broken connections
- **Timeout**: 300 seconds for blocked connections
- **Auto-Reconnect**: Services reconnect on connection loss

### Message Durability
- **Durable Exchanges**: Survive RabbitMQ restarts
- **Durable Queues**: Messages persist across restarts
- **Manual Acknowledgment**: Messages requeued on failure
- **Dead Letter Handling**: Failed messages use `basic_nack(requeue=False)`

### Load Balancing
- **QoS Prefetch**: `prefetch_count=1` for fair dispatch
- **Multiple Replicas**: Payment service scaled to 2 replicas
- **Round-Robin**: Messages distributed evenly across consumers

### Thread Safety
- **Separate Connections**: Each notification thread has own RabbitMQ connection
- **Pika BlockingConnection**: Not thread-safe, isolation required
- **Daemon Threads**: Clean shutdown on service termination

## Troubleshooting

### Service Not Starting

**Symptom**: Pod in CrashLoopBackOff
```bash
kubectl describe pod -n order-pipeline <pod-name>
```

**Common Causes**:
1. RabbitMQ not ready - Wait for rabbitmq pod to be Running
2. Connection refused - Check RabbitMQ service is accessible
3. Authentication failed - Verify credentials (admin/***)

### No Messages Processing

**Check RabbitMQ queues**:
1. Access RabbitMQ UI at http://rabbitmq.local:30683
2. Go to "Queues" tab
3. Verify queues exist and have consumers
4. Check message rates

**Check service logs**:
```bash
# Look for "Waiting for orders/payments..."
kubectl logs -n order-pipeline -l app=payment-service

# Check for errors
kubectl logs -n order-pipeline -l app=notification-service | grep ERROR
```

### Notification Service Crashing

**Error**: `StreamLostError: AssertionError`

**Cause**: Shared RabbitMQ connection across threads (not thread-safe)

**Fix**: Each thread must create its own connection (already implemented in current code)

### Metrics Not Appearing in Grafana

**Check Prometheus targets**:
1. Access Prometheus UI
2. Go to Status → Targets
3. Verify all order-pipeline services are UP

**Check metric names**:
```bash
# Query Prometheus directly
curl 'http://prometheus:9090/api/v1/query?query=orders_generated_total'
```

### Payment Success Rate Too Low/High

**Adjust success rate** in [apps/order-pipeline/configmap.yaml:182](../apps/order-pipeline/configmap.yaml#L182):
```python
success = random.random() < 0.9  # 90% success rate
```

Change `0.9` to desired rate (0.0 = 0%, 1.0 = 100%)

### Order Generation Too Fast/Slow

**Adjust generation rate** in [apps/order-pipeline/configmap.yaml:123,142](../apps/order-pipeline/configmap.yaml#L123):
```python
batch_size = random.randint(1, 5)      # 1-5 orders per batch
time.sleep(random.uniform(10, 20))     # Wait 10-20 seconds
```

## Technical Decisions

### Why RabbitMQ Instead of Kafka?
- **ARM32 Support**: Kafka doesn't support ARMv7 (Raspberry Pi)
- **Simplicity**: RabbitMQ easier for event-driven patterns
- **Low Latency**: Sub-second message delivery for order processing
- **Management UI**: Built-in monitoring and administration

### Why Fanout Exchanges?
- **Broadcasting**: Multiple services need same events
- **Decoupling**: Services don't need to know about each other
- **Scalability**: Easy to add new consumers without changing producers

### Why Named Queues?
- **Visibility**: Easy to identify queues in RabbitMQ UI
- **Debugging**: Clear purpose from queue name
- **Durability**: Named queues persist across service restarts

### Why Separate Connections Per Thread?
- **Thread Safety**: Pika's BlockingConnection is not thread-safe
- **Isolation**: Connection issues in one thread don't affect others
- **Reliability**: Each thread can reconnect independently

### Why Manual Acknowledgment?
- **Reliability**: Messages requeued if processing fails
- **At-Least-Once**: Guarantees message processing
- **Error Handling**: Failed messages can be rejected without requeue

## Performance Characteristics

- **Order Rate**: ~0.1-0.5 orders/second (configurable)
- **Payment Processing**: 0.5-2.0 seconds per order
- **Fulfillment Processing**: 1.0-3.0 seconds per shipment
- **Notification Latency**: Near real-time (< 100ms)
- **Memory Usage**: ~50-100 MB per service
- **CPU Usage**: Minimal (< 0.1 CPU per service)

## License

Part of the ClaudeAI Kubernetes infrastructure project.
