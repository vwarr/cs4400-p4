from flask import Flask, g, jsonify
from dotenv import load_dotenv
import os
from mysql.connector import pooling

app = Flask(__name__)

load_dotenv()

DB_CONFIG = {
    'host':     os.getenv('MYSQL_HOST'),
    'user':     os.getenv('MYSQL_USER'),
    'password': os.getenv('MYSQL_PASS'),
    'database': os.getenv('MYSQL_DB'),
}

pool = pooling.MySQLConnectionPool(
    pool_name="flask_pool",
    pool_size=5,
    **DB_CONFIG
)

@app.before_request
def open_db():
    g.db_conn   = pool.get_connection()
    g.db_cursor = g.db_conn.cursor(dictionary=True)

@app.teardown_request
def close_db(exc):
    if hasattr(g, 'db_cursor'):
        g.db_cursor.close()
    if hasattr(g, 'db_conn'):
        g.db_conn.close()

@app.route('/test-leg-time/<int:distance>/<int:speed>')
def test_leg_time(distance, speed):
    g.db_cursor.execute(
        "SELECT leg_time(%s, %s) AS duration",
        (distance, speed)
    )
    row = g.db_cursor.fetchone()
    return jsonify({
        'distance': distance,
        'speed': speed,
        'duration': str(row['duration'])
    })

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

if __name__ == '__main__':
    app.run(debug=True)