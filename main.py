# import otel_logger  # Import first to configure logging
import logging
# from opentelemetry import trace

import time
from fastapi import FastAPI, Request, HTTPException, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from database import init_db
from routers.posts import router as posts_router
from auth import login
from models import LoginRequest, Token
import os
from dotenv import load_dotenv

load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(name)s - %(message)s"
)
logger = logging.getLogger(__name__)

APP_NAME = os.getenv("APP_NAME", "Social Media API")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    # Startup
    print(f"Starting {APP_NAME} v{APP_VERSION}...")
    # Initialize database tables (optional - comment out if using existing schema)
    # await init_db()
    print("Application started successfully")
    yield
    # Shutdown
    print("Shutting down application...")


# Create FastAPI app
app = FastAPI(
    title=APP_NAME,
    version=APP_VERSION,
    description="FastAPI backend for Social Media App",
    lifespan=lifespan
)
logger.info("Application started")


# Add CORS middleware (adjust origins as needed)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info("Incoming request: %s %s", request.method, request.url.path)

    try:
        response = await call_next(request)
        logger.info(
            "Request completed: %s %s | Status: %s",
            request.method,
            request.url.path,
            response.status_code
        )
        return response
    except Exception:
        logger.exception(
            "Request failed: %s %s",
            request.method,
            request.url.path
        )
        raise


# Health check endpoint
@app.get("/health")
async def health_check():
    logger.info("Health check requested")
    """Health check endpoint."""
    return {
        "status": "healthy",
        "app_name": APP_NAME,
        "version": APP_VERSION
    }


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information."""
    logger.info("Root endpoint requested")
    return {
        "message": f"Welcome to {APP_NAME}",
        "version": APP_VERSION,
        "docs": "/docs",
        "health": "/health"
    }


# Include routers
app.include_router(posts_router)


# Authentication endpoint
@app.post("/auth/login", response_model=Token)
async def auth_login(login_data: LoginRequest):
    """
    Login endpoint to get JWT token.
    
    Use the returned token in the Authorization header as: Bearer <token>
    """
    logger.info("Login attempt received")
    token = await login(login_data)
    logger.info("Login successful")
    return token


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler for unhandled errors."""
    print(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error"}
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
