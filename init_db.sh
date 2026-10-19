
#!/bin/sh
set -eu

# Database configuration
DB_NAME="${DB_NAME:-social_media_db}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

export PGPASSWORD="${DB_PASSWORD:?DB_PASSWORD must be set}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "${YELLOW}Social Media App Database Initialization${NC}"
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

# Check whether the application tables exist
echo "Checking application tables..."

TABLES_EXIST=$(psql -X -h "$DB_HOST" -p "$DB_PORT" \
    -U "$DB_USER" -d "$DB_NAME" -tAc \
    "SELECT CASE
        WHEN to_regclass('public.users') IS NOT NULL
         AND to_regclass('public.posts') IS NOT NULL
        THEN 1 ELSE 0
     END")

if [ "$TABLES_EXIST" != "1" ]; then
    echo "Application tables are missing. Applying schema..."

    psql -X -v ON_ERROR_STOP=1 \
        -h "$DB_HOST" -p "$DB_PORT" \
        -U "$DB_USER" -d "$DB_NAME" \
        -f /app/schema.sql

    echo "${GREEN}Schema applied successfully${NC}"
else
    echo "${GREEN}Application tables already exist. Skipping schema.${NC}"
fi

# Check whether both tables are empty
echo "Checking whether seed data is needed..."

TABLE_COUNTS=$(psql -X -h "$DB_HOST" -p "$DB_PORT" \
    -U "$DB_USER" -d "$DB_NAME" -tAc \
    "SELECT
        (SELECT COUNT(*) FROM public.users) || ',' ||
        (SELECT COUNT(*) FROM public.posts)")

USER_COUNT=${TABLE_COUNTS%%,*}
POST_COUNT=${TABLE_COUNTS#*,}

if [ "$USER_COUNT" = "0" ] && [ "$POST_COUNT" = "0" ]; then
    echo "Both tables are empty. Loading seed data..."

    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f seed.sql
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Seed data loaded successfully${NC}"
    else
        echo -e "${RED}Error: Failed to load seed data${NC}"
        exit 1
    fi
    echo ""
else
    echo "${YELLOW}Data already exists in at least one table. Skipping seed data.${NC}"
fi

echo ""
echo "${GREEN}Database initialization complete!${NC}"
echo "Database: $DB_NAME"
echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo "User: $DB_USER"
