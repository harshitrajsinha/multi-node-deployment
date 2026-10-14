# Social Media App

A FastAPI backend with PostgreSQL database for a social media application.

## Backend API Setup

### 1. Install Python Dependencies

Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

Install dependencies:
```bash
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Copy the `.env` file and update the configuration:
```bash
cp .env .env.local
```

Edit `.env.local` with your database credentials:
```
DATABASE_URL=postgresql+asyncpg://postgres:your_password@localhost:5432/social_media_app
SECRET_KEY=your-secret-key-here
```

### 3. Start the FastAPI Server

Run the application:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`

## API Endpoints

### Authentication

#### POST /auth/login
Login to get JWT token.

**Request Body:**
```json
{
  "username": "alice_smith",
  "password": "password"
}
```

**Response:**
```json
{
  "access_token": "jwt_token_here",
  "token_type": "bearer"
}
```

Use the token in the Authorization header: `Authorization: Bearer <token>`

### Posts

#### GET /posts (Public)
Get paginated list of posts.

**Query Parameters:**
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 10, max: 10)
- `user_id`: Filter by user ID (optional)

**Response:**
```json
{
  "posts": [...],
  "total": 500,
  "page": 1,
  "limit": 10,
  "pages": 50
}
```

#### POST /posts (Auth Required)
Create a new post.

**Request Body:**
```json
{
  "user_id": 1,
  "content": "New post content"
}
```

#### PUT /posts/{id} (Auth Required)
Update a post.

**Request Body:**
```json
{
  "content": "Updated content"
}
```

#### DELETE /posts/{id} (Auth Required)
Delete a post.

#### POST /posts/{id}/like (Auth Required)
Like a post (increments likes_count).

#### POST /posts/{id}/comments (Auth Required)
Add a comment to a post.

**Request Body:**
```json
{
  "comment": "This is a comment"
}
```

### Health Check

#### GET /health
Check API health status.

**Response:**
```json
{
  "status": "healthy",
  "app_name": "Social Media API",
  "version": "1.0.0"
}
```

## Database Setup

### 1. Install PostgreSQL

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

### 2. Start PostgreSQL

**Linux:**
```bash
sudo service postgresql start

```

### 3. Initialize the Database

Make the initialization script executable:
```bash
chmod +x init_db.sh
```

Run the initialization script:
```bash
./init_db.sh
```

This script will:
- Check if PostgreSQL is running
- Create the database `social_media_app` if it doesn't exist
- Apply the schema from `schema.sql`
- Load seed data from `seed.sql`
- Verify the data was loaded correctly

### 4. Manual Setup (Alternative)

If you prefer to set up manually:

```bash
# Create database
createdb social_media_app

# Apply schema
psql -d social_media_app -f schema.sql

# Load seed data
psql -d social_media_app -f seed.sql
```

## Database Schema

### Users Table
- `id` - Primary key (auto-increment)
- `username` - Unique username (VARCHAR 50)
- `email` - Unique email address (VARCHAR 255)
- `password_hash` - Hashed password (VARCHAR 255)
- `full_name` - User's display name (VARCHAR 100)
- `bio` - User biography (TEXT, nullable, default empty string)
- `avatar_url` - Profile picture URL (VARCHAR 500, nullable, default empty string)
- `created_at` - Account creation timestamp
- `updated_at` - Last update timestamp (auto-updated)

### Posts Table
- `id` - Primary key (auto-increment)
- `user_id` - Foreign key to users table (with CASCADE delete)
- `content` - Post text content (TEXT)
- `likes_count` - Number of likes (INTEGER, default 0)
- `comments` - Array of comment strings (TEXT[], default empty array)
- `created_at` - Post creation timestamp
- `updated_at` - Last edit timestamp (auto-updated)

## Project Structure

```
social-media-app/
├── schema.sql           # Database schema definition
├── seed.sql             # Seed data (10 users, 500 posts)
├── init_db.sh           # Database initialization script
├── requirements.txt     # Python dependencies
├── .env                 # Environment variables template
├── .gitignore          # Git ignore file
├── main.py             # FastAPI application entry point
├── database.py         # Database connection and session management
├── models.py           # SQLModel models and Pydantic schemas
├── auth.py             # JWT authentication utilities
├── routers/
│   ├── __init__.py
│   └── posts.py        # Post-related endpoints
└── README.md           # This file
```

## Known Limitations

**Current design trade-offs:**
- No user tracking for likes/comments (same user can like multiple times)
- No rate limiting on like/comment endpoints
- No delete option for comments
- No unlike option for likes
- Array-based comments may have performance issues at scale
- No timestamps on comments
- Password validation accepts any password for MVP (seed data has hashed passwords)

**When to upgrade:**
- If performance degrades with many comments, move to separate comments table
- If abuse becomes an issue, add rate limiting
- If user tracking is needed, add separate likes/comments tables with user_id



## Setup signoz

Refer: ```https://signoz.io/docs/install/docker```

```foundryctl cast -f casting.yaml```

[If running locally, take care of signoz docker volume]

2. Once python interpreter is activated (.venv), inside this process set:
```
export OTEL_SERVICE_NAME="social-media-app"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
export OTEL_TRACES_EXPORTER="otlp"
export OTEL_EXPORTER_OTLP_INSECURE=true
```

Run signoz and python app together as: ```opentelemetry-instrument python3 main.py```

## Setup K6 load generator

1. Download
```curl -fsSL https://dl.k6.io/key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/k6-archive-keyring.gpg```
```echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list```

?. sudo apt-get install k6

2. Login
```
k6 cloud login
```

3. Run load test
```cd load-test```
```k6 cloud run --local-execution script.js```

4. Access on Grafana cloud