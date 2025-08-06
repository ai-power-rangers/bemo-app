#!/bin/bash

# Test script for send-welcome-email edge function
# Make sure to replace YOUR_SERVICE_ROLE_KEY with your actual service role key

echo "Testing send-welcome-email edge function..."

# Test with valid INSERT event
echo -e "\n1. Testing valid INSERT event:"
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-welcome-email' \
  --header 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "type": "INSERT",
    "table": "parent_profiles",
    "record": {
      "email": "test@example.com",
      "full_name": "Test User"
    }
  }'

# Test with missing email
echo -e "\n\n2. Testing with missing email:"
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-welcome-email' \
  --header 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "type": "INSERT",
    "table": "parent_profiles",
    "record": {
      "full_name": "Test User"
    }
  }'

# Test with wrong table
echo -e "\n\n3. Testing with wrong table (should be ignored):"
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-welcome-email' \
  --header 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "type": "INSERT",
    "table": "child_profiles",
    "record": {
      "name": "Child User"
    }
  }'

# Test with UPDATE event (should be ignored)
echo -e "\n\n4. Testing with UPDATE event (should be ignored):"
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-welcome-email' \
  --header 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "type": "UPDATE",
    "table": "parent_profiles",
    "record": {
      "email": "test@example.com",
      "full_name": "Updated User"
    }
  }'

# Test with invalid authorization
echo -e "\n\n5. Testing with invalid authorization:"
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-welcome-email' \
  --header 'Authorization: Bearer INVALID_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "type": "INSERT",
    "table": "parent_profiles",
    "record": {
      "email": "test@example.com",
      "full_name": "Test User"
    }
  }'

echo -e "\n\nTests completed!"