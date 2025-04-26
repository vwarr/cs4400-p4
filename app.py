from flask import Flask, render_template, request, redirect, url_for
import backend as be
from flask import Flask, g, jsonify
from dotenv import load_dotenv
import os
from flask import Flask, g, request, jsonify
from mysql.connector import pooling, DatabaseError

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

@app.route("/")
def index():
    return render_template('index.html')

@app.route('/add_airplane', methods=['POST', 'GET'])
def api_add_airplane():
    if request.method == 'GET':
        return render_template('add_airplane.html')
    data = request.form
    args = [
        data['airlineID'], data['tail_num'], data['seat_capacity'], data['speed'],
        data.get('locationID'), data.get('plane_type'), data.get('maintenanced'),
        data.get('model'), data.get('neo')
    ]
    g.db_cursor.callproc('add_airplane', args)
    g.db_conn.commit()
    return render_template('add_airplane.html', success=True)

@app.route('/add_airport', methods=['POST', 'GET'])
def api_add_airport():
    if request.method == 'GET':
        return render_template('add_airport.html')
    print("add_airport")
    data = request.form
    args = [
        data['airportID'], data.get('airport_name'), data['city'],
        data['state'], data['country'], data.get('locationID')
    ]
    g.db_cursor.callproc('add_airport', args)
    g.db_conn.commit()
    return render_template('add_airport.html', success=True)

@app.route('/add_person', methods=['POST', 'GET'])
def api_add_person():
    if request.method == 'GET':
        return render_template('add_person.html')
    print("add_person")
    data = request.form
    args = [
        data['personID'], data['first_name'], data.get('last_name'),
        data['locationID'], data.get('taxID'), data.get('experience'),
        data.get('miles'), data.get('funds')
    ]
    g.db_cursor.callproc('add_person', args)
    g.db_conn.commit()
    return render_template('add_person.html')

@app.route('/grant_or_revoke_pilot_license', methods=['POST', 'GET'])
def api_toggle_pilot_license():
    if request.method == 'GET':
        return render_template('grant_or_revoke.html')
    print("grant/revoke license")
    data = request.form
    args = [data['personID'], data['license']]
    g.db_cursor.callproc('grant_or_revoke_pilot_license', args)
    g.db_conn.commit()
    return render_template('grant_or_revoke.html')

@app.route('/offer_flight', methods=['POST', 'GET'])
def api_offer_flight():
    if request.method == 'GET':
        return render_template('offer_flight.html')
    print("offer_flight")
    data = request.form
    args = [
        data['flightID'], data['routeID'], data['support_airline'],
        data['support_tail'], data['progress'], data['next_time'], data['cost']
    ]
    g.db_cursor.callproc('offer_flight', args)
    g.db_conn.commit()
    return render_template('offer_flight.html')

@app.route('/flight_landing', methods=['POST', 'GET'])
def api_flight_landing():
    if request.method == 'GET':
        return render_template('flight_landing.html')
    print("flight_landing")
    data = request.form
    g.db_cursor.callproc('flight_landing', [data['flightID']])
    g.db_conn.commit()
    return render_template('flight_landing.html')

@app.route('/flight_takeoff', methods=['POST', 'GET'])
def api_flight_takeoff():
    if request.method == 'GET':
        return render_template('flight_takeoff.html')
    print("flight_takeoff")
    data = request.form
    g.db_cursor.callproc('flight_takeoff', [data['flightID']])
    g.db_conn.commit()
    return render_template('flight_takeoff.html')

@app.route('/passengers_board', methods=['POST', 'GET'])
def api_passengers_board():
    if request.method == 'GET':
        return render_template('passengers.board.html')
    print("passengers_board")
    data = request.form
    g.db_cursor.callproc('passengers_board', [data['flightID']])
    g.db_conn.commit()
    return render_template('passengers.board.html')

@app.route('/passengers_disembark', methods=['POST', 'GET'])
def api_passengers_disembark():
    if request.method == 'GET':
        return render_template('passengers.disembark.html')
    print("disembark")
    data = request.form
    g.db_cursor.callproc('passengers_disembark', [data['flightID']])
    g.db_conn.commit()
    return render_template('passengers.disembark.html')

@app.route('/assign_pilot', methods=['POST', 'GET'])
def api_assign_pilot():
    if request.method == 'GET':
        return render_template('assign_pilot.html')
    print("assign_pilot")
    data = request.form
    g.db_cursor.callproc('assign_pilot', [data['flightID'], data['personID']])
    g.db_conn.commit()
    return render_template('assign_pilot.html')

@app.route('/recycle_crew', methods=['POST', 'GET'])
def api_recycle_crew():
    if request.method == 'GET':
        return render_template('recycle_crew.html')
    print("recycle_crew")
    data = request.form
    g.db_cursor.callproc('recycle_crew', [data['flightID']])
    g.db_conn.commit()
    return render_template('recycle_crew.html')

@app.route('/retire_flight', methods=['POST', 'GET'])
def api_retire_flight():
    if request.method == 'GET':
        return render_template('retire_flight.html')
    print("ret_flight")
    data = request.form
    g.db_cursor.callproc('retire_flight', [data['flightID']])
    g.db_conn.commit()
    return render_template('retire_flight.html')

@app.route('/simulation_cycle', methods=['POST', 'GET'])
def api_simulation_cycle():
    if request.method == 'GET':
        return render_template('simulation_cycle.html')
    print("sim cycle")
    g.db_cursor.callproc('simulation_cycle', [])
    g.db_conn.commit()
    return render_template('simulation_cycle.html')

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



