from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, ForeignKey, Text, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional
import os
import logging
import json
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

# Database setup
DATABASE_URL = f"postgresql://{os.getenv('POSTGRES_USER', 'smartbiz')}:{os.getenv('POSTGRES_PASSWORD', 'smartbiz123')}@{os.getenv('DB_HOST', 'postgres.smartbiz.svc.cluster.local')}:5432/{os.getenv('POSTGRES_DB', 'smartbiz')}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Prometheus metrics
request_count = Counter('smartbiz_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
request_duration = Histogram('smartbiz_request_duration_seconds', 'Request duration', ['method', 'endpoint'])
articles_total = Gauge('smartbiz_articles_total', 'Total number of articles')
customers_total = Gauge('smartbiz_customers_total', 'Total number of customers')
orders_total = Counter('smartbiz_orders_total', 'Total number of orders created')
revenue_total = Counter('smartbiz_revenue_total', 'Total revenue')

# Database Models
class Article(Base):
    __tablename__ = "articles"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(Text)
    price = Column(Float)
    category = Column(String)
    stock = Column(Integer)
    created_at = Column(DateTime, default=datetime.utcnow)

class Customer(Base):
    __tablename__ = "customers"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    phone = Column(String)
    address = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    orders = relationship("Order", back_populates="customer")

class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"))
    article_id = Column(Integer, ForeignKey("articles.id"))
    quantity = Column(Integer)
    total_price = Column(Float)
    status = Column(String, default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)
    customer = relationship("Customer", back_populates="orders")

# Create tables
Base.metadata.create_all(bind=engine)

# Pydantic models
class ArticleCreate(BaseModel):
    name: str
    description: str
    price: float
    category: str
    stock: int

class CustomerCreate(BaseModel):
    name: str
    email: str
    phone: str
    address: str

class OrderCreate(BaseModel):
    customer_id: int
    article_id: int
    quantity: int

# FastAPI app
app = FastAPI(title="SmartBiz API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint
@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "smartbiz-api"}

# Metrics endpoint
@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Articles endpoints
@app.get("/api/articles")
def get_articles():
    db = SessionLocal()
    try:
        articles = db.query(Article).all()
        articles_total.set(len(articles))
        return articles
    finally:
        db.close()

@app.post("/api/articles")
def create_article(article: ArticleCreate):
    db = SessionLocal()
    try:
        db_article = Article(**article.dict())
        db.add(db_article)
        db.commit()
        db.refresh(db_article)
        articles_total.inc()
        return db_article
    finally:
        db.close()

# Customers endpoints
@app.get("/api/customers")
def get_customers():
    db = SessionLocal()
    try:
        customers = db.query(Customer).all()
        customers_total.set(len(customers))
        return customers
    finally:
        db.close()

@app.post("/api/customers")
def create_customer(customer: CustomerCreate):
    db = SessionLocal()
    try:
        db_customer = Customer(**customer.dict())
        db.add(db_customer)
        db.commit()
        db.refresh(db_customer)
        customers_total.inc()
        return db_customer
    finally:
        db.close()

# Orders endpoints
@app.get("/api/orders")
def get_orders():
    db = SessionLocal()
    try:
        orders = db.query(Order).all()
        return orders
    finally:
        db.close()

@app.post("/api/orders")
def create_order(order: OrderCreate):
    db = SessionLocal()
    try:
        # Get article to calculate total price
        article = db.query(Article).filter(Article.id == order.article_id).first()
        if not article:
            raise HTTPException(status_code=404, detail="Article not found")

        if article.stock < order.quantity:
            raise HTTPException(status_code=400, detail="Insufficient stock")

        total_price = article.price * order.quantity

        db_order = Order(
            customer_id=order.customer_id,
            article_id=order.article_id,
            quantity=order.quantity,
            total_price=total_price
        )

        # Reduce stock
        article.stock -= order.quantity

        db.add(db_order)
        db.commit()
        db.refresh(db_order)

        orders_total.inc()
        revenue_total.inc(total_price)

        return db_order
    finally:
        db.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
