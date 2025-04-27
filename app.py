from flask import Flask, render_template, request, redirect, url_for
import backend as be
from flask import Flask, g, jsonify
from dotenv import load_dotenv
import os
from flask import Flask, g, request, jsonify
from mysql.connector import pooling, errorcode, DatabaseError, IntegrityError

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

def handle_db_error(e):
    if isinstance(e, IntegrityError):
        if e.errno == errorcode.ER_DUP_ENTRY:
            return "Duplicate entry."
        if e.errno in (errorcode.ER_NO_REFERENCED_ROW_2, errorcode.ER_NO_REFERENCED_ROW):
            return "Invalid reference to another record."
    return "Unexpected database behavior. Please check your inputs and try again."

@app.route("/")
def index():
    return render_template('index.html')

@app.route('/add_airplane', methods=['POST', 'GET'])
def api_add_airplane():
    if request.method == 'GET':
        return render_template('add_airplane.html')

    data = request.form
    missing = [f for f in ('airlineID', 'tail_num', 'seat_capacity', 'speed') if not data.get(f)]
    if missing:
        return render_template('add_airplane.html', success=False, error=f"Missing fields: {', '.join(missing)}")

    try:
        seat_capacity = int(data['seat_capacity'])
        if seat_capacity <= 0:
            raise ValueError('Seat capacity must be greater than 0')
        speed = int(data['speed'])
        if speed <= 0:
            raise ValueError('Speed must be greater than 0')
    except ValueError as ve:
        return render_template('add_airplane.html', success=False, error=str(ve))

    args = [
        data['airlineID'],
        data['tail_num'],
        seat_capacity,
        speed,
        data.get('locationID') or None,
        data.get('plane_type') or None,
        True if data.get('maintenanced') else None,
        data.get('model') or None,
        True if data.get('neo') else None
    ]

    try:
        g.db_cursor.callproc('add_airplane', args)
        g.db_conn.commit()
        return render_template('add_airplane.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('add_airplane.html', success=False, error=handle_db_error(e))

@app.route('/add_airport', methods=['POST', 'GET'])
def api_add_airport():
    if request.method == 'GET':
        return render_template('add_airport.html')
    try:
        print("add_airport")
        data = request.form
        args = [
            data['airportID'], data.get('airport_name'), data['city'],
            data['state'], data['country'], data.get('locationID')
        ]
        g.db_cursor.callproc('add_airport', args)
        g.db_conn.commit()
        return render_template('add_airport.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('add_airport.html', success=False)

@app.route('/add_person', methods=['POST', 'GET'])
def api_add_person():
    if request.method == 'GET':
        return render_template('add_person.html')
    try:
        print("add_person")
        data = request.form
        args = [
            data['personID'], data['first_name'], data.get('last_name'),
            data['locationID'], data.get('taxID'), data.get('experience'),
            data.get('miles'), data.get('funds')
        ]
        g.db_cursor.callproc('add_person', args)
        g.db_conn.commit()
        return render_template('add_person.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('add_person.html', success=False)

@app.route('/grant_or_revoke_pilot_license', methods=['POST', 'GET'])
def api_toggle_pilot_license():
    if request.method == 'GET':
        return render_template('grant_or_revoke.html')
    try:
        print("grant/revoke license")
        data = request.form
        args = [data['personID'], data['license']]
        g.db_cursor.callproc('grant_or_revoke_pilot_license', args)
        g.db_conn.commit()
        return render_template('grant_or_revoke.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('grant_or_revoke.html', success=False)

@app.route('/offer_flight', methods=['POST', 'GET'])
def api_offer_flight():
    if request.method == 'GET':
        return render_template('offer_flight.html')
    try:
        print("offer_flight")
        data = request.form
        args = [
            data['flightID'], data['routeID'], data['support_airline'],
            data['support_tail'], data['progress'], data['next_time'], data['cost']
        ]
        g.db_cursor.callproc('offer_flight', args)
        g.db_conn.commit()
        return render_template('offer_flight.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('offer_flight.html', success=False)

@app.route('/flight_landing', methods=['POST', 'GET'])
def api_flight_landing():
    if request.method == 'GET':
        return render_template('flight_landing.html')
    try:
        print("flight_landing")
        data = request.form
        g.db_cursor.callproc('flight_landing', [data['flightID']])
        g.db_conn.commit()
        return render_template('flight_landing.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('flight_landing.html', success=False)

@app.route('/flight_takeoff', methods=['POST', 'GET'])
def api_flight_takeoff():
    if request.method == 'GET':
        return render_template('flight_takeoff.html')
    try:
        print("flight_takeoff")
        data = request.form
        g.db_cursor.callproc('flight_takeoff', [data['flightID']])
        g.db_conn.commit()
        return render_template('flight_takeoff.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('flight_takeoff.html', success=False)

@app.route('/passengers_board', methods=['POST', 'GET'])
def api_passengers_board():
    if request.method == 'GET':
        return render_template('passengers.board.html')
    try:
        print("passengers_board")
        data = request.form
        g.db_cursor.callproc('passengers_board', [data['flightID']])
        g.db_conn.commit()
        return render_template('passengers.board.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('passengers.board.html', success=False)

@app.route('/passengers_disembark', methods=['POST', 'GET'])
def api_passengers_disembark():
    if request.method == 'GET':
        return render_template('passengers.disembark.html')
    try:
        print("disembark")
        data = request.form
        g.db_cursor.callproc('passengers_disembark', [data['flightID']])
        g.db_conn.commit()
        return render_template('passengers.disembark.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('passengers.disembark.html', success=False)

@app.route('/assign_pilot', methods=['POST', 'GET'])
def api_assign_pilot():
    if request.method == 'GET':
        return render_template('assign_pilot.html')
    try:
        print("assign_pilot")
        data = request.form
        g.db_cursor.callproc('assign_pilot', [data['flightID'], data['personID']])
        g.db_conn.commit()
        return render_template('assign_pilot.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('assign_pilot.html', success=False)

@app.route('/recycle_crew', methods=['POST', 'GET'])
def api_recycle_crew():
    if request.method == 'GET':
        return render_template('recycle_crew.html')
    try:
        print("recycle_crew")
        data = request.form
        g.db_cursor.callproc('recycle_crew', [data['flightID']])
        g.db_conn.commit()
        return render_template('recycle_crew.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('recycle_crew.html', success=False)

@app.route('/retire_flight', methods=['POST', 'GET'])
def api_retire_flight():
    if request.method == 'GET':
        return render_template('retire_flight.html')
    try:
        print("ret_flight")
        data = request.form
        g.db_cursor.callproc('retire_flight', [data['flightID']])
        g.db_conn.commit()
        return render_template('retire_flight.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('retire_flight.html', success=False)

@app.route('/simulation_cycle', methods=['POST', 'GET'])
def api_simulation_cycle():
    if request.method == 'GET':
        return render_template('simulation_cycle.html')
    try:
        print("sim cycle")
        g.db_cursor.callproc('simulation_cycle', [])
        g.db_conn.commit()
        return render_template('simulation_cycle.html', success=True)
    except DatabaseError as e:
        print(e)
        return render_template('simulation_cycle.html', success=False)

@app.route('/alternate_airports', methods=['POST', 'GET'])
def alternate_airports():
    print("alt airports")
    return render_template('alternate_airports.html')

@app.route('/flights_in_the_air', methods=['POST', 'GET'])
def flights_in_the_air():
    print("flights in the air")
    return render_template('flights_in_the_air.html')

@app.route('/flights_on_the_ground', methods=['POST', 'GET'])
def flights_on_the_ground():
    print("flights in the ground")
    return render_template('flights_on_the_ground.html')

@app.route('/people_in_the_air', methods=['POST', 'GET'])
def people_in_the_air():
    print("ppl in the air")
    return render_template('people_in_the_air.html')

@app.route('/people_on_the_ground', methods=['POST', 'GET'])
def people_on_the_ground():
    print("ppl in the ground")
    return render_template('people_on_the_ground.html')

@app.route('/route_summary', methods=['POST', 'GET'])
def route_summary():
    print("route_summary")
    return render_template('route_summary.html')

if __name__ == '__main__':
    app.run(debug=True)



