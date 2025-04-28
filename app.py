from flask import Flask, render_template, request, redirect, url_for, g, jsonify
from dotenv import load_dotenv
import os
from mysql.connector import pooling, errorcode, DatabaseError, IntegrityError
import error_handle as handler

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
        return render_template('add_airplane.html', success=False, error=handler.handle_db_error(e))

@app.route('/add_airport', methods=['POST', 'GET'])
def api_add_airport():
    if request.method == 'GET':
        return render_template('add_airport.html')

    data = request.form

    missing = [f for f in ('airportID','city','state','country') if not data.get(f)]
    if missing:
        return render_template('add_airport.html',
                               success=False,
                               error=f"Missing fields: {', '.join(missing)}")

    if len(data['airportID']) != 3:
        return render_template('add_airport.html',
                               success=False,
                               error="airportID must be exactly 3 characters")
    if len(data['country']) != 3:
        return render_template('add_airport.html',
                               success=False,
                               error="country code must be 3 characters")

    args = [
        data['airportID'],
        data.get('airport_name') or None,
        data['city'],
        data['state'],
        data['country'],
        data.get('locationID') or None
    ]

    try:
        g.db_cursor.callproc('add_airport', args)
        g.db_conn.commit()
        return render_template('add_airport.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('add_airport.html',
                               success=False,
                               error=handler.handle_db_error(e))

@app.route('/add_person', methods=['POST', 'GET'])
def api_add_person():
    if request.method == 'GET':
        return render_template('add_person.html')

    data = request.form
    missing = [f for f in ('personID', 'first_name', 'locationID') if not data.get(f)]
    if missing:
        return render_template('add_person.html',
                               success=False,
                               error=f"Missing fields: {', '.join(missing)}")

    try:
        exp = int(data['experience']) if data.get('experience') else None
        miles = int(data['miles']) if data.get('miles') else None
        funds = int(data['funds']) if data.get('funds') else None
        if any(x is not None and x < 0 for x in (exp, miles, funds)):
            raise ValueError
    except (ValueError, TypeError):
        return render_template('add_person.html',
                               success=False,
                               error="experience, miles, and funds must be non-negative integers")

    args = [
        data['personID'],
        data['first_name'],
        data.get('last_name') or None,
        data['locationID'],
        data.get('taxID') or None,
        exp,
        miles,
        funds
    ]

    try:
        g.db_cursor.callproc('add_person', args)
        g.db_conn.commit()
        return render_template('add_person.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('add_person.html',
                               success=False,
                               error=handler.handle_db_error(e))

@app.route('/grant_or_revoke_pilot_license', methods=['POST', 'GET'])
def api_toggle_pilot_license():
    if request.method == 'GET':
        return render_template('grant_or_revoke.html')
    data = request.form
    missing = [f for f in ('personID', 'license') if not data.get(f)]
    if missing:
        return render_template('grant_or_revoke.html', success=False,
                               error='Missing fields: ' + ', '.join(missing))
    pid = data['personID'].strip()
    lic = data['license'].strip()
    if len(pid) > 50 or len(lic) > 100:
        return render_template('grant_or_revoke.html', success=False,
                               error='personID ≤50 chars; license ≤100 chars')
    args = [pid, lic]
    try:
        g.db_cursor.callproc('grant_or_revoke_pilot_license', args)
        g.db_conn.commit()
        return render_template('grant_or_revoke.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('grant_or_revoke.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/offer_flight', methods=['POST', 'GET'])
def api_offer_flight():
    if request.method == 'GET':
        return render_template('offer_flight.html')
    data = request.form
    missing = [f for f in ('flightID', 'routeID', 'progress', 'next_time', 'cost') if not data.get(f)]
    if missing:
        return render_template('offer_flight.html', success=False,
                               error='Missing fields: ' + ', '.join(missing))
    try:
        prog = int(data['progress'])
        cost = int(data['cost'])
        if prog < 0 or cost < 0:
            raise ValueError
    except (ValueError, TypeError):
        return render_template('offer_flight.html', success=False,
                               error='progress & cost must be non-negative integers')
    args = [
        data['flightID'],
        data['routeID'],
        data.get('support_airline'),
        data.get('support_tail'),
        prog,
        data['next_time'],
        cost
    ]
    try:
        g.db_cursor.callproc('offer_flight', args)
        g.db_conn.commit()
        return render_template('offer_flight.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('offer_flight.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/flight_landing', methods=['GET', 'POST'])
def api_flight_landing():
    if request.method == 'GET':
        return render_template('flight_landing.html')
    fid = request.form.get('flightID')
    if not fid:
        return render_template('flight_landing.html', success=False,
                               error='Missing flightID')
    if len(fid) > 50:
        return render_template('flight_landing.html', success=False,
                               error='flightID too long')
    try:
        g.db_cursor.callproc('flight_landing', [fid])
        g.db_conn.commit()
        return render_template('flight_landing.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('flight_landing.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/flight_takeoff', methods=['GET', 'POST'])
def api_flight_takeoff():
    if request.method == 'GET':
        return render_template('flight_takeoff.html')
    fid = request.form.get('flightID')
    if not fid:
        return render_template('flight_takeoff.html', success=False,
                               error='Missing flightID')
    if len(fid) > 50:
        return render_template('flight_takeoff.html', success=False,
                               error='flightID too long')
    try:
        g.db_cursor.callproc('flight_takeoff', [fid])
        g.db_conn.commit()
        return render_template('flight_takeoff.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('flight_takeoff.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/passengers_board', methods=['GET', 'POST'])
def api_passengers_board():
    if request.method == 'GET':
        return render_template('passengers.board.html')
    fid = request.form.get('flightID')
    if not fid:
        return render_template('passengers.board.html', success=False,
                               error='Missing flightID')
    if len(fid) > 50:
        return render_template('passengers.board.html', success=False,
                               error='flightID too long')
    try:
        g.db_cursor.callproc('passengers_board', [fid])
        g.db_conn.commit()
        return render_template('passengers.board.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('passengers.board.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/passengers_disembark', methods=['GET', 'POST'])
def api_passengers_disembark():
    if request.method == 'GET':
        return render_template('passengers.disembark.html')
    fid = request.form.get('flightID')
    if not fid:
        return render_template('passengers.disembark.html', success=False,
                               error='Missing flightID')
    if len(fid) > 50:
        return render_template('passengers.disembark.html', success=False,
                               error='flightID too long')
    try:
        g.db_cursor.callproc('passengers_disembark', [fid])
        g.db_conn.commit()
        return render_template('passengers.disembark.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('passengers.disembark.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/assign_pilot', methods=['GET', 'POST'])
def api_assign_pilot():
    if request.method == 'GET':
        return render_template('assign_pilot.html')
    data = request.form
    missing = [f for f in ('flightID', 'personID') if not data.get(f)]
    if missing:
        return render_template('assign_pilot.html', success=False,
                               error='Missing fields: ' + ', '.join(missing))
    fid = data['flightID']
    pid = data['personID']
    if len(fid) > 50 or len(pid) > 50:
        return render_template('assign_pilot.html', success=False,
                               error='IDs must be ≤50 chars')
    try:
        g.db_cursor.callproc('assign_pilot', [fid, pid])
        g.db_conn.commit()
        return render_template('assign_pilot.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('assign_pilot.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/recycle_crew', methods=['GET', 'POST'])
def api_recycle_crew():
    if request.method == 'GET':
        return render_template('recycle_crew.html')
    fid = request.form.get('flightID')
    if not fid:
        return render_template('recycle_crew.html', success=False,
                               error='Missing flightID')
    if len(fid) > 50:
        return render_template('recycle_crew.html', success=False,
                               error='flightID too long')
    try:
        g.db_cursor.callproc('recycle_crew', [fid])
        g.db_conn.commit()
        return render_template('recycle_crew.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('recycle_crew.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/retire_flight', methods=['GET', 'POST'])
def api_retire_flight():
    if request.method == 'GET':
        return render_template('retire_flight.html')
    fid = request.form.get('flightID')
    if not fid:
        return render_template('retire_flight.html', success=False,
                               error='Missing flightID')
    if len(fid) > 50:
        return render_template('retire_flight.html', success=False,
                               error='flightID too long')
    try:
        g.db_cursor.callproc('retire_flight', [fid])
        g.db_conn.commit()
        return render_template('retire_flight.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('retire_flight.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/simulation_cycle', methods=['GET', 'POST'])
def api_simulation_cycle():
    if request.method == 'GET':
        return render_template('simulation_cycle.html')
    try:
        g.db_cursor.callproc('simulation_cycle', [])
        g.db_conn.commit()
        return render_template('simulation_cycle.html', success=True)
    except (IntegrityError, DatabaseError) as e:
        return render_template('simulation_cycle.html', success=False,
                               error=handler.handle_db_error(e))

@app.route('/alternate_airports', methods=['POST', 'GET'])
def alternate_airports():
    try:
        g.db_cursor.execute("SELECT * FROM alternative_airports")
        airports = g.db_cursor.fetchall()
        return render_template('alternative_airports.html', airports=airports)
    except DatabaseError as e:
        print(e)
        return render_template('alternative_airports.html', error=str(e))

@app.route('/flights_in_the_air', methods=['GET'])
def flights_in_the_air():
    try:
        g.db_cursor.execute("SELECT * FROM flights_in_the_air")
        flights = g.db_cursor.fetchall()
        return render_template('flights_in_the_air.html', flights=flights)
    except DatabaseError as e:
        print(e)
        return render_template('flights_in_the_air.html', error=str(e))

@app.route('/flights_on_the_ground', methods=['POST', 'GET'])
def flights_on_the_ground():
    print("flights in the ground")
    try:
        g.db_cursor.execute("SELECT * FROM flights_on_the_ground")
        flights = g.db_cursor.fetchall()
        print(flights)
        return render_template('flights_on_the_ground.html', flights=flights)
    except DatabaseError as e:
        print(e)
        return render_template('flights_on_the_ground.html', error=str(e))

@app.route('/people_in_the_air', methods=['POST', 'GET'])
def people_in_the_air():
    print("ppl in the air")
    try:
        g.db_cursor.execute("SELECT * FROM people_in_the_air")
        ppl = g.db_cursor.fetchall()
        print(ppl)
        return render_template('people_in_the_air.html', ppl=ppl)
    except DatabaseError as e:
        print(e)
        return render_template('people_in_the_air.html', error=str(e))

@app.route('/people_on_the_ground', methods=['POST', 'GET'])
def people_on_the_ground():
    print("ppl in the ground")
    try:
        g.db_cursor.execute("SELECT * FROM people_on_the_ground")
        ppl = g.db_cursor.fetchall()
        print(ppl)
        return render_template('people_on_the_ground.html', ppl=ppl)
    except DatabaseError as e:
        print(e)
        return render_template('people_on_the_ground.html', error=str(e))

@app.route('/route_summary', methods=['POST', 'GET'])
def route_summary():
    print("route_summary")
    try:
        g.db_cursor.execute("SELECT * FROM route_summary")
        routes = g.db_cursor.fetchall()
        print(routes)
        return render_template('route_summary.html', routes=routes)
    except DatabaseError as e:
        print(e)
        return render_template('route_summary.html', error=str(e))
    
if __name__ == '__main__':
    app.run(debug=True)



