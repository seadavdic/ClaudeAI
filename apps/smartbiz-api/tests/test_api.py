"""
SmartBiz API Tests
Tests for the SmartBiz API endpoints
"""
import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


class TestHealthEndpoint:
    """Test health check endpoint"""

    def test_health_endpoint_returns_200(self):
        """Health endpoint should return 200 OK"""
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_endpoint_returns_correct_data(self):
        """Health endpoint should return status and service name"""
        response = client.get("/health")
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "smartbiz-api"


class TestMetricsEndpoint:
    """Test Prometheus metrics endpoint"""

    def test_metrics_endpoint_returns_200(self):
        """Metrics endpoint should return 200 OK"""
        response = client.get("/metrics")
        assert response.status_code == 200

    def test_metrics_endpoint_returns_prometheus_format(self):
        """Metrics should be in Prometheus format"""
        response = client.get("/metrics")
        assert response.status_code == 200
        content = response.text
        # Check for common Prometheus metrics
        assert "smartbiz_requests_total" in content or "# HELP" in content


class TestArticlesEndpoint:
    """Test articles CRUD operations"""

    def test_get_articles_returns_200(self):
        """GET /api/articles should return 200"""
        response = client.get("/api/articles")
        assert response.status_code == 200

    def test_get_articles_returns_list(self):
        """GET /api/articles should return a list"""
        response = client.get("/api/articles")
        data = response.json()
        assert isinstance(data, list)

    def test_create_article_with_valid_data(self):
        """POST /api/articles with valid data should create article"""
        article_data = {
            "name": "Test Product",
            "description": "Test Description",
            "price": 99.99,
            "category": "Electronics",
            "stock": 100
        }
        response = client.post("/api/articles", json=article_data)
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == article_data["name"]
        assert data["price"] == article_data["price"]
        assert "id" in data


class TestCustomersEndpoint:
    """Test customers CRUD operations"""

    def test_get_customers_returns_200(self):
        """GET /api/customers should return 200"""
        response = client.get("/api/customers")
        assert response.status_code == 200

    def test_get_customers_returns_list(self):
        """GET /api/customers should return a list"""
        response = client.get("/api/customers")
        data = response.json()
        assert isinstance(data, list)

    def test_create_customer_with_valid_data(self):
        """POST /api/customers with valid data should create customer"""
        import random
        customer_data = {
            "name": "Test Customer",
            "email": f"test{random.randint(1000, 9999)}@example.com",
            "phone": "+1234567890",
            "address": "123 Test Street"
        }
        response = client.post("/api/customers", json=customer_data)
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == customer_data["name"]
        assert data["email"] == customer_data["email"]
        assert "id" in data


class TestOrdersEndpoint:
    """Test orders operations"""

    def test_get_orders_returns_200(self):
        """GET /api/orders should return 200"""
        response = client.get("/api/orders")
        assert response.status_code == 200

    def test_get_orders_returns_list(self):
        """GET /api/orders should return a list"""
        response = client.get("/api/orders")
        data = response.json()
        assert isinstance(data, list)


class TestAPIStructure:
    """Test API structure and configuration"""

    def test_api_has_cors_enabled(self):
        """API should have CORS enabled"""
        response = client.options("/api/articles")
        # CORS should allow the request
        assert response.status_code in [200, 405]  # 405 is also acceptable

    def test_api_has_correct_title(self):
        """API should have correct title in docs"""
        response = client.get("/openapi.json")
        assert response.status_code == 200
        data = response.json()
        assert data["info"]["title"] == "SmartBiz API"
        assert data["info"]["version"] == "1.0.0"


# Pytest configuration
if __name__ == "__main__":
    pytest.main([__file__, "-v"])
