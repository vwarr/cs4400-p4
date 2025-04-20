import os
from flask import Flask, g, request, jsonify
from mysql.connector import pooling
from dotenv import load_dotenv

load_dotenv()
app = Flask(__name__)

DB_CONFIG = {
    'host': os.getenv('MYSQL_HOST'),
    'user': os.getenv('MYSQL_USER'),
    'password': os.getenv('MYSQL_PASS'),
    'database': os.getenv('MYSQL_DB'),
    'port': int(os.getenv('MYSQL_PORT', 3306)),
}
pool = pooling.MySQLConnectionPool(pool_name="flask_pool", pool_size=5, **DB_CONFIG)

@app.before_request
def open_db():
    g.db_conn = pool.get_connection()
    g.db_cursor = g.db_conn.cursor(dictionary=True)

@app.teardown_request
def close_db(exc):
    if hasattr(g, 'db_cursor'):
        g.db_cursor.close()
    if hasattr(g, 'db_conn'):
        g.db_conn.close()

@app.route('/add_airplane', methods=['POST'])
def api_add_airplane():
    data = request.get_json()
    args = [
        data['airlineID'], data['tail_num'], data['seat_capacity'], data['speed'],
        data['locationID'], data['plane_type'], data['maintenanced'],
        data.get('model'), data.get('neo')
    ]
    g.db_cursor.callproc('add_airplane', args)
    g.db_conn.commit()
    return jsonify({'status': 'airplane_added'}), 201

@app.route('/add_airport', methods=['POST'])
def api_add_airport():
    data = request.get_json()
    args = [
        data['airportID'], data['airport_name'], data['city'],
        data['state'], data['country'], data['locationID']
    ]
    g.db_cursor.callproc('add_airport', args)
    g.db_conn.commit()
    return jsonify({'status': 'airport_added'}), 201

@app.route('/add_person', methods=['POST'])
def api_add_person():
    data = request.get_json()
    args = [
        data['personID'], data['first_name'], data.get('last_name'),
        data['locationID'], data.get('taxID'), data.get('experience'),
        data.get('miles'), data.get('funds')
    ]
    g.db_cursor.callproc('add_person', args)
    g.db_conn.commit()
    return jsonify({'status': 'person_added'}), 201

@app.route('/grant_or_revoke_pilot_license', methods=['POST'])
def api_toggle_pilot_license():
    data = request.get_json()
    args = [data['personID'], data['license']]
    g.db_cursor.callproc('grant_or_revoke_pilot_license', args)
    g.db_conn.commit()
    return jsonify({'status': 'pilot_license_toggled'}), 200

@app.route('/offer_flight', methods=['POST'])
def api_offer_flight():
    data = request.get_json()
    args = [
        data['flightID'], data['routeID'], data['support_airline'],
        data['support_tail'], data['progress'], data['next_time'], data['cost']
    ]
    g.db_cursor.callproc('offer_flight', args)
    g.db_conn.commit()
    return jsonify({'status': 'flight_offered'}), 201

@app.route('/flight_landing', methods=['POST'])
def api_flight_landing():
    g.db_cursor.callproc('flight_landing', [request.get_json()['flightID']])
    g.db_conn.commit()
    return jsonify({'status': 'flight_landed'}), 200

@app.route('/flight_takeoff', methods=['POST'])
def api_flight_takeoff():
    g.db_cursor.callproc('flight_takeoff', [request.get_json()['flightID']])
    g.db_conn.commit()
    return jsonify({'status': 'flight_takeoff_executed'}), 200

@app.route('/passengers_board', methods=['POST'])
def api_passengers_board():
    g.db_cursor.callproc('passengers_board', [request.get_json()['flightID']])
    g.db_conn.commit()
    return jsonify({'status': 'passengers_boarded'}), 200

@app.route('/passengers_disembark', methods=['POST'])
def api_passengers_disembark():
    g.db_cursor.callproc('passengers_disembark', [request.get_json()['flightID']])
    g.db_conn.commit()
    return jsonify({'status': 'passengers_disembarked'}), 200

@app.route('/assign_pilot', methods=['POST'])
def api_assign_pilot():
    data = request.get_json()
    g.db_cursor.callproc('assign_pilot', [data['flightID'], data['personID']])
    g.db_conn.commit()
    return jsonify({'status': 'pilot_assigned'}), 200

@app.route('/recycle_crew', methods=['POST'])
def api_recycle_crew():
    g.db_cursor.callproc('recycle_crew', [request.get_json()['flightID']])
    g.db_conn.commit()
    return jsonify({'status': 'crew_recycled'}), 200

@app.route('/retire_flight', methods=['POST'])
def api_retire_flight():
    g.db_cursor.callproc('retire_flight', [request.get_json()['flightID']])
    g.db_conn.commit()
    return jsonify({'status': 'flight_retired'}), 200

@app.route('/simulation_cycle', methods=['POST'])
def api_simulation_cycle():
    g.db_cursor.callproc('simulation_cycle', [])
    g.db_conn.commit()
    return jsonify({'status': 'simulation_cycle_executed'}), 200

@app.route('/')
def hello_world():
    return '<p>Hello, World!</p>'

if __name__ == '__main__':
    app.run(debug=True)
