#!/bin/bash

# Check if python3 exists
if ! command -v python3 &> /dev/null
then
    echo "python3 could not be found. Please install Python 3."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Create .env from example if not exists
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    cp .env.example .env
    echo "PLEASE EDIT .env AND ADD YOUR GOOGLE_API_KEY"
fi

# Run the server
echo "Starting server..."
  uvicorn main:socket_app --host 0.0.0.0 --port 8000 --reload                                                                                                                             