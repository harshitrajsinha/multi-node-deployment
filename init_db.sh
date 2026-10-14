#!/bin/bash

# Database initialization script for Social Media App
# This script creates the database, runs the schema, and loads seed data

# Database configuration
DB_NAME=$1
DB_USER=$2
DB_HOST=$3
DB_PORT="5432"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Social Media App Database Initialization${NC}"
echo "========================================"
echo ""

# Check if PostgreSQL is running
echo -e "${YELLOW}Checking PostgreSQL status...${NC}"
if ! pg_isready -h $DB_HOST -p $DB_PORT > /dev/null 2>&1; then
    echo -e "${RED}Error: PostgreSQL is not running or not accessible${NC}"
    echo "Please start PostgreSQL and try again"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL is running${NC}"
echo ""

# Check if database exists
echo -e "${YELLOW}Checking if database exists...${NC}"
DB_EXISTS=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -lqt | cut -d \| -f 1 | grep -w $DB_NAME | wc -l)

if [ $DB_EXISTS -eq 0 ]; then
    echo "Database '$DB_NAME' does not exist. Creating..."
    createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database '$DB_NAME' created successfully${NC}"
    else
        echo -e "${RED}Error: Failed to create database${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Database '$DB_NAME' already exists${NC}"
fi
echo ""

# Run schema
echo -e "${YELLOW}Applying database schema...${NC}"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f schema.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Schema applied successfully${NC}"
else
    echo -e "${RED}Error: Failed to apply schema${NC}"
    exit 1
fi
echo ""

# Run seed data
echo -e "${YELLOW}Loading seed data...${NC}"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f seed.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Seed data loaded successfully${NC}"
else
    echo -e "${RED}Error: Failed to load seed data${NC}"
    exit 1
fi
echo ""

# Verify data
echo -e "${YELLOW}Verifying data...${NC}"
USER_COUNT=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM users;")
POST_COUNT=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM posts;")

echo "Users: $USER_COUNT"
echo "Posts: $POST_COUNT"

if [ "$USER_COUNT" -eq "10" ] && [ "$POST_COUNT" -eq "500" ]; then
    echo -e "${GREEN}✓ Data verification successful${NC}"
else
    echo -e "${RED}✗ Data verification failed${NC}"
    echo "Expected: 10 users, 500 posts"
    echo "Found: $USER_COUNT users, $POST_COUNT posts"
    exit 1
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Database initialization complete!${NC}"
echo ""
echo "Database: $DB_NAME"
echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo "User: $DB_USER"
echo ""
echo "To connect to the database:"
echo "  psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
