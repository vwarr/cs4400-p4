# Flight Tracking Web App

A Flask-powered frontend for our airline management system, backed by MySQL stored procedures, functions and views.

## Prerequisites
- Python 3.10+  
- MySQL 8.x  
- pip  

## Setup
- git clone https://github.com/vwarr/cs4400-p4.git && cd cs4400-p4
- python -m venv venv
- source venv/bin/activate
- pip install -r requirements.txt

## load all stored procedures/functions/views
- mysql -u root -p flight_tracking < cs4400_sams_phase3_mechanics_TEMPLATE_v0_fresh.sql

## create a .env file in project root with:
-MYSQL_HOST=localhost
- MYSQL_USER=your_user
- MYSQL_PASS=your_password
- MYSQL_DB=flight_tracking
- MYSQL_PORT=3306
- FLASK_ENV=development

## start the Flask app
flask run

## visit in browser:
http://127.0.0.1:5000

## this project uses:
HTML frontend, Flask 3.1, MySQL 8 with stored procedures/functions/views, mysql-connector-python with connection pooling, python-dotenv for configuration

## Contributions:

- Varun: Backend code and API routing for all CRUD operations
- Sharaf: Fixed SQL scripting, stored procedures, etc, and added view procedures
- Carlos: Built out entire HTML frontend