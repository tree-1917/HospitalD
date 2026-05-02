#!/bin/bash

set -e  # Exit on any error

# =================================================== #
# Hospital Database Seeder
# =================================================== #

DB_USER="hospital"
DB_NAME="hospital"
CONTAINER_NAME="snama-postgres-1"
SEED_FILE="Models/seed.sql"

echo "=== Hospital Database Seeder ==="

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: Postgres container '$CONTAINER_NAME' is not running"
    echo "Start it first: docker-compose up -d"
    exit 1
fi

# Check if seed file exists
if [ ! -f "$SEED_FILE" ]; then
    echo "Error: Seed file '$SEED_FILE' not found"
    exit 1
fi

echo "=== Checking seed file ($(wc -l < "$SEED_FILE") lines) ==="

echo "=== Cleaning old data ==="
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
    TRUNCATE recipes, clerks, patients, doctors RESTART IDENTITY CASCADE;
"

echo "=== Copying seed file into container ==="
docker cp "$SEED_FILE" "$CONTAINER_NAME:/tmp/seed.sql"

echo "=== Seeding database ==="
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f /tmp/seed.sql

echo "=== Seed completed successfully ==="

echo ""
echo "=== Verification ==="
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT 'Doctors' as table, COUNT(*) as count FROM doctors 
    UNION ALL 
    SELECT 'Patients', COUNT(*) FROM patients 
    UNION ALL 
    SELECT 'Clerks', COUNT(*) FROM clerks 
    UNION ALL 
    SELECT 'Recipes', COUNT(*) FROM recipes;
"

echo ""
echo "=== Sample Data ==="
echo "-- Doctors:"
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT id, username, email FROM doctors LIMIT 5;"

echo ""
echo "-- Patients:"
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT id, username, summary->>'condition' as condition FROM patients LIMIT 5;"

echo ""
echo "-- Recipes:"
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT id, title, price, status FROM recipes LIMIT 5;"
