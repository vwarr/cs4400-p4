-- CS4400: Introduction to Database Systems: Monday, March 3, 2025
-- Simple Airline Management System Course Project Mechanics [TEMPLATE] (v0)
-- Views, Functions & Stored Procedures

/* This is a standard preamble for most of our scripts.  The intent is to establish
a consistent environment for the database behavior. */
set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

set @thisDatabase = 'flight_tracking';
use flight_tracking;
-- -----------------------------------------------------------------------------
-- stored procedures and views
-- -----------------------------------------------------------------------------
/* Standard Procedure: If one or more of the necessary conditions for a procedure to
be executed is false, then simply have the procedure halt execution without changing
the database state. Do NOT display any error messages, etc. */

-- [_] supporting functions, views and stored procedures
-- -----------------------------------------------------------------------------
/* Helpful library capabilities to simplify the implementation of the required
views and procedures. */
-- -----------------------------------------------------------------------------
drop function if exists leg_time;
delimiter //
create function leg_time (ip_distance integer, ip_speed integer)
	returns time reads sql data
begin
	declare total_time decimal(10,2);
    declare hours, minutes integer default 0;
    set total_time = ip_distance / ip_speed;
    set hours = truncate(total_time, 0);
    set minutes = truncate((total_time - hours) * 60, 0);
    return maketime(hours, minutes, 0);
end //
delimiter ;

-- [1] add_airplane()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airplane.  A new airplane must be sponsored
by an existing airline, and must have a unique tail number for that airline.
username.  An airplane must also have a non-zero seat capacity and speed. An airplane
might also have other factors depending on it's type, like the model and the engine.  
Finally, an airplane must have a new and database-wide unique location
since it will be used to carry passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airplane;
delimiter //
create procedure add_airplane (in ip_airlineID varchar(50), in ip_tail_num varchar(50),
	in ip_seat_capacity integer, in ip_speed integer, in ip_locationID varchar(50),
    in ip_plane_type varchar(100), in ip_maintenanced boolean, in ip_model varchar(50),
    in ip_neo boolean)
sp_main: begin
	declare tracker int;
    
	IF NOT EXISTS (SELECT 1 FROM airline where airlineID = ip_airlineID) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Add_airplane: Airline does not exist.';
		LEAVE sp_main;
	END IF;
    IF (ip_airlineID is null or ip_tail_num is null) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Add_airplane: AirlineID or Tailnum is null.';
		LEAVE sp_main;
	END IF;
    
	-- Ensure that the plane type is valid: Boeing, Airbus, or neither
    if ip_plane_type not in ('Boeing', 'Airbus') and ip_plane_type is not Null then
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Add_airplane: Plane type is not Boeing or Airbus and is NOT null.';
		leave sp_main;
	end if;
    
    -- Ensure that the type-specific attributes are accurate for the type
    -- Ensure that the airplane and location values are new and unique
    select count(*) into tracker from Airplane
	where airlineID = ip_airlineID and tail_num = ip_tail_num;
	if tracker > 0 then
		leave sp_main;
	end if;
    
    if ip_seat_capacity <= 0 or ip_speed <= 0 then
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Add_airplane: Seat capacity or speed inputs are 0 or less.';
		leave sp_main;
	end if;
    
    select count(*) into tracker from Location where locationID = ip_locationID;
	if tracker > 0 then
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Add_airplane: Location ID not unique';
		leave sp_main;
	end if;
    
    -- Add airplane and location into respective tables
    insert into Location(locationID) values (ip_locationID);
    
    insert into Airplane(
		airlineID, tail_num, seat_capacity, speed, locationID,
		plane_type, maintenanced, model, neo) 
        values (ip_airlineID, ip_tail_num, ip_seat_capacity, ip_speed, ip_locationID,
		ip_plane_type, ip_maintenanced, ip_model, ip_neo);

end //
delimiter ;

-- [2] add_airport()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airport.  A new airport must have a unique
identifier along with a new and database-wide unique location if it will be used
to support airplane takeoffs and landings.  An airport may have a longer, more
descriptive name.  An airport must also have a city, state, and country designation. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airport;
delimiter //
create procedure add_airport (in ip_airportID char(3), in ip_airport_name varchar(200),
    in ip_city varchar(100), in ip_state varchar(100), in ip_country char(3), in ip_locationID varchar(50))
sp_main: begin

	-- Ensure that the airport and location values are new and unique
    -- Add airport and location into respective tables


    if ip_airportID is NULL or ip_airportID = '' then
		signal sqlstate '45000' set message_text = 'Add_airport: Airport ID cannot be null nor empty';
        leave sp_main;
    elseif ip_locationID is NULL or ip_locationID = '' then
		signal sqlstate '45000' set message_text = 'Add_airport: Location ID cannot be null nor empty';
        leave sp_main;
    elseif ip_city is NULL or ip_city = '' then
		signal sqlstate '45000' set message_text = 'Add_airport: City cannot be null nor empty';
        leave sp_main;
    elseif ip_state is NULL or ip_state = '' then
		signal sqlstate '45000' set message_text = 'Add_airport: State cannot be null nor empty';
        leave sp_main;
    elseif ip_country is NULL or ip_country = '' then
		signal sqlstate '45000' set message_text = 'Add_airport: Country cannot be null nor empty';
        leave sp_main;
    end if;
    
    if (not exists (select 1 from airport where airportID = ip_airportID)) and (not exists (select 1 from location where locationID = ip_locationID)) THEN
		insert into location(locationID)VALUES(ip_locationID);
		insert into airport(airportID, airport_name, city, state, country, locationID)VALUES(ip_airportID, ip_airport_name, ip_city, ip_state, ip_country, ip_locationID);
	else
		signal sqlstate '45000' set message_text = 'Add_airport: Airport and location must be new and unique';
		leave sp_main;
	END IF;

end //
delimiter ;

-- [3] add_person()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new person.  A new person must reference a unique
identifier along with a database-wide unique location used to determine where the
person is currently located: either at an airport, or on an airplane, at any given
time.  A person must have a first name, and might also have a last name.

A person can hold a pilot role or a passenger role (exclusively).  As a pilot,
a person must have a tax identifier to receive pay, and an experience level.  As a
passenger, a person will have some amount of frequent flyer miles, along with a
certain amount of funds needed to purchase tickets for flights. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_person;
delimiter //
create procedure add_person (in ip_personID varchar(50), in ip_first_name varchar(100),
    in ip_last_name varchar(100), in ip_locationID varchar(50), in ip_taxID varchar(50),
    in ip_experience integer, in ip_miles integer, in ip_funds integer)
sp_main: begin

	
	-- Ensure that the location is valid
    -- Ensure that the persion ID is unique
    -- Ensure that the person is a pilot or passenger
    -- Add them to the person table as well as the table of their respective role
    
	-- Ensure that the location is valid
	if not exists (select 1 from Location where locationID = ip_locationID) then
        signal sqlstate '45000' set message_text = 'Add_person: Location is invalid';
        leave sp_main;
    -- Ensure that the persion ID is unique
	elseif exists (select 1 from Person where personID = ip_personID) then
        signal sqlstate '45000' set message_text = 'Add_person: PersonID is invalid';

        leave sp_main;
    -- Ensure that the person is a pilot or passenger
    elseif ip_taxID is null and ip_funds is null then
		signal sqlstate '45000' set message_text = 'Add_person: Person is neither a pilot nor a passenger. This is not allowed. Enter valid taxID or funds amount.';
        leave sp_main;
    -- Add them to the person table as well as the table of their respective role
	else
        insert into person(personID, first_name, last_name, locationID)
        values (ip_personID, ip_first_name, ip_last_name, ip_locationID);

		if ip_taxID is not null then
            insert into pilot(personID, taxID, experience)
            values (ip_personID, ip_taxID, ip_experience);
        end if;
        if ip_funds is not null then
            insert into passenger(personID, miles, funds)
            values (ip_personID, ip_miles, ip_funds);
        end if;
	end if;

end //
delimiter ;

-- [4] grant_or_revoke_pilot_license()
-- -----------------------------------------------------------------------------
/* This stored procedure inverts the status of a pilot license.  If the license
doesn't exist, it must be created; and, if it aready exists, then it must be removed. */
-- -----------------------------------------------------------------------------
drop procedure if exists grant_or_revoke_pilot_license;
delimiter //
create procedure grant_or_revoke_pilot_license (in ip_personID varchar(50), in ip_license varchar(100))
sp_main: begin

	-- Ensure that the person is a valid pilot
    -- If license exists, delete it, otherwise add the license

    IF EXISTS (SELECT 1 FROM pilot WHERE personID = ip_personID) THEN
		-- Revoke license if personID and license exists
		IF EXISTS (SELECT 1 FROM pilot_licenses WHERE personID = ip_personID and license = ip_license) THEN
			DELETE FROM pilot_licenses WHERE personID = ip_personID and license = ip_license;
        -- Add license if it doesnt exist
        ELSE
			INSERT INTO pilot_licenses VALUES (ip_personID, ip_license);
		END IF;
	END IF;

end //
delimiter ;

-- [5] offer_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new flight.  The flight can be defined before
an airplane has been assigned for support, but it must have a valid route.  And
the airplane, if designated, must not be in use by another flight.  The flight
can be started at any valid location along the route except for the final stop,
and it will begin on the ground.  You must also include when the flight will
takeoff along with its cost. */
-- -----------------------------------------------------------------------------
drop procedure if exists offer_flight;
delimiter //
create procedure offer_flight (in ip_flightID varchar(50), in ip_routeID varchar(50),
    in ip_support_airline varchar(50), in ip_support_tail varchar(50), in ip_progress integer,
    in ip_next_time time, in ip_cost integer)
sp_main: begin

	-- Ensure that the airplane exists
    -- Ensure that the route exists
    -- Ensure that the progress is less than the length of the route
    -- Create the flight with the airplane starting in on the ground

	IF (ip_routeID is null or ip_flightID is null) THEN
		signal sqlstate '45000' set message_text = 'Offer_flight: ip_route ID or ip_flight ID is null';
		LEAVE sp_main;
    END IF;
	IF EXISTS (SELECT 1 FROM flight where flightID = ip_flightID) THEN
		signal sqlstate '45000' set message_text = 'Offer_flight: FlightID not found.';
		LEAVE sp_main;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM airplane where airlineID = ip_support_airline and tail_num = ip_support_tail) THEN
		signal sqlstate '45000' set message_text = 'Offer_flight: Tailnum or airline id not found';
		LEAVE sp_main;
	END IF;
	IF EXISTS (SELECT 1 FROM airplane a join flight f on (a.airlineID = f.support_airline and a.tail_num = f.support_tail) where a.airlineID = ip_support_airline and a.tail_num = ip_support_tail and f.airplane_status = 'in_flight') THEN
		LEAVE sp_main;
	END IF;
	IF NOT EXISTS (SELECT 1 FROM route where routeID = ip_routeID) THEN
		signal sqlstate '45000' set message_text = 'Offer_flight: Route ID does not exist';
		LEAVE sp_main;
	END IF;
	IF (SELECT max(sequence) from route_path where routeID = ip_routeID) <= ip_progress THEN
		signal sqlstate '45000' set message_text = 'Offer_flight: Sequence already maxed out';
		LEAVE sp_main;
	END IF;
	INSERT INTO flight VALUES (ip_flightID, ip_routeID, ip_support_airline, ip_support_tail, ip_progress, 'on_ground', ip_next_time, ip_cost);

end //
delimiter ;

-- [6] flight_landing()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight landing at the next airport
along it's route.  The time for the flight should be moved one hour into the future
to allow for the flight to be checked, refueled, restocked, etc. for the next leg
of travel.  Also, the pilots of the flight should receive increased experience, and
the passengers should have their frequent flyer miles updated. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_landing;
delimiter //
create procedure flight_landing (in ip_flightID varchar(50))
sp_main: begin

	-- Ensure that the flight exists
    -- Ensure that the flight is in the air
    
    -- Increment the pilot's experience by 1
    -- Increment the frequent flyer miles of all passengers on the plane
    -- Update the status of the flight and increment the next time to 1 hour later
		-- Hint: use addtime()

    DECLARE temp_airplane_status VARCHAR(100);
    DECLARE temp_airline VARCHAR(50);
    DECLARE temp_tail_num VARCHAR(50);
    DECLARE temp_routeID VARCHAR(50);
    DECLARE temp_progress INT;
    DECLARE temp_legID VARCHAR(50);
    DECLARE temp_distance INT;
    -- Get flight details
    SELECT airplane_status, support_airline, support_tail, routeID, progress
    INTO temp_airplane_status, temp_airline, temp_tail_num, temp_routeID, temp_progress
    FROM flight 
    WHERE flightID = ip_flightID;
    IF temp_airplane_status = 'in_flight' THEN
    
        -- Get the current leg's distance
        SELECT l.legID, l.distance INTO temp_legID, temp_distance
        FROM route_path rp
        JOIN leg l ON rp.legID = l.legID
        WHERE rp.routeID = temp_routeID AND rp.sequence = temp_progress;
        
        -- Increment pilot experience
        UPDATE pilot
        SET experience = experience + 1
        WHERE commanding_flight = ip_flightID;

        -- Award miles to passengers (only if distance exists)
        IF temp_distance IS NOT NULL THEN
            UPDATE passenger p
            JOIN person per ON p.personID = per.personID
            JOIN airplane a ON per.locationID = a.locationID
            SET p.miles = IFNULL(p.miles, 0) + temp_distance
            WHERE a.airlineID = temp_airline 
            AND a.tail_num = temp_tail_num;
        END IF;
        -- Update flight status (DO NOT increment progress here)
        UPDATE flight
        SET 
            airplane_status = 'on_ground',
            next_time = ADDTIME(next_time, '1:00:00') -- For ground time
        WHERE flightID = ip_flightID;
	ELSE 
		signal sqlstate '45000' set message_text = 'Flight_landing: Flight with associated ID not in_flight';
    END IF;

end //
delimiter ;

-- [7] flight_takeoff()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight taking off from its current
airport towards the next airport along it's route.  The time for the next leg of
the flight must be calculated based on the distance and the speed of the airplane.
And we must also ensure that Airbus and general planes have at least one pilot
assigned, while Boeing must have a minimum of two pilots. If the flight cannot take
off because of a pilot shortage, then the flight must be delayed for 30 minutes. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_takeoff;
delimiter //
create procedure flight_takeoff (in ip_flightID varchar(50))
sp_main: begin

	-- Ensure that the flight exists
    -- Ensure that the flight is on the ground
    -- Ensure that the flight has another leg to fly
    -- Ensure that there are enough pilots (1 for Airbus and general, 2 for Boeing)
		-- If there are not enough, move next time to 30 minutes later
        
	-- Increment the progress and set the status to in flight
    -- Calculate the flight time using the speed of airplane and distance of leg
    -- Update the next time using the flight time

    DECLARE temp_airplane_status VARCHAR(20);
    DECLARE temp_support_tail VARCHAR(50);
    DECLARE temp_plane_type VARCHAR(20);
    DECLARE temp_current_progress INT;
    DECLARE temp_routeID VARCHAR(50);
    DECLARE temp_total_legs INT;
    DECLARE temp_pilot_count INT;
    DECLARE temp_speed INT;
    DECLARE temp_distance INT;
    DECLARE temp_flight_time INT; #Minutes
	IF EXISTS (SELECT 1 FROM flight WHERE flightID = ip_flightID) THEN
        SELECT airplane_status, support_tail, progress, routeID INTO temp_airplane_status, temp_support_tail, temp_current_progress, temp_routeID FROM flight WHERE flightID = ip_flightID;
	ELSE
		signal sqlstate '45000' set message_text = 'Flight_takeoff: FlightID not found';
		LEAVE sp_main;
	END IF;
	IF temp_airplane_status != 'on_ground' THEN
		signal sqlstate '45000' set message_text = 'Flight_takeoff: Airplane not on ground';
        LEAVE sp_main;
    END IF;
        SELECT COUNT(*) INTO temp_total_legs FROM route_path WHERE routeID = temp_routeID;
    IF temp_current_progress >= temp_total_legs THEN
		signal sqlstate '45000' set message_text = 'Flight_takeoff: Airplane progress exceeds route legs amount';
        LEAVE sp_main;
    END IF;
    SELECT plane_type, speed INTO temp_plane_type, temp_speed FROM airplane WHERE tail_num = temp_support_tail;
    IF temp_plane_type = 'Boeing' THEN
        SET temp_pilot_count = 2;
    ELSE
        SET temp_pilot_count = 1;
    END IF;
	SELECT COUNT(*) INTO temp_pilot_count 
    FROM pilot 
    WHERE commanding_flight = ip_flightID;
    IF (temp_plane_type = 'Boeing' AND temp_pilot_count < 2) OR 
       (temp_plane_type != 'Boeing' AND temp_pilot_count < 1) THEN
        UPDATE flight 
        SET next_time = DATE_ADD(next_time, INTERVAL 30 MINUTE) 
        WHERE flightID = ip_flightID;
        LEAVE sp_main;
    END IF;
	SELECT l.distance INTO temp_distance FROM route_path rp JOIN leg l ON rp.legID = l.legID WHERE rp.routeID = temp_routeID AND rp.sequence = temp_current_progress + 1;
	SET temp_flight_time = (temp_distance / temp_speed) * 60; # rounding?
        UPDATE flight
		SET airplane_status = 'in_flight', progress = progress + 1, next_time = DATE_ADD(next_time, INTERVAL temp_flight_time MINUTE)
		WHERE flightID = ip_flightID;
end //
delimiter ;

-- [8] passengers_board()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting on a flight at
its current airport.  The passengers must be at the same airport as the flight,
and the flight must be heading towards that passenger's desired destination.
Also, each passenger must have enough funds to cover the flight.  Finally, there
must be enough seats to accommodate all boarding passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_board;
delimiter //
CREATE PROCEDURE process_passenger_boarding(
    IN ip_flight_id VARCHAR(50)
)
	sp_main: BEGIN
	declare v_routeID varchar(50);
	declare v_support_airline varchar(50);
	declare v_support_tail varchar(50);
	declare v_progress int;
	declare v_cost int;
	declare v_seat_capacity int;
	declare v_legID varchar(50);
	declare v_departure varchar(50);
	declare v_arrival varchar(50);
	declare v_departure_locationID varchar(50);
	declare v_arrival_locationID varchar(50);
	declare v_locationID varchar(50);
	declare v_boarding_count int;
	declare v_current_onboard int;
	declare v_total_legs int; 
	declare v_flight_exists int;

	-- Flight existence check
	SELECT count(*) INTO v_flight_exists FROM flight WHERE flightID = ip_flightID;
	IF flight_exists = 0 THEN 
		signal sqlstate '45000' set message_text = 'Passengers_board: Flight does not exist';
		LEAVE sp_main;

	 -- Check if flight is grounded
	 ELSEIF (SELECT airplane_status FROM flight WHERE flightID = ip_flightID) != 'on_ground' THEN 
			signal sqlstate '45000' set message_text = 'Passengers_board: Flight not grounded';

		LEAVE sp_main; 
     
	 -- Do further legs exist?
	 SELECT progress INTO v_progress FROM flight WHERE flightID = ip_flightID; 
	 SELECT count(*) INTO v_total_legs FROM route_path WHERE routeID = (SELECT routeID FROM flight WHERE flightID = ip_flightID); 
	 ELSEIF v_progress >= v_total_legs THEN 
		signal sqlstate '45000' set message_text = 'Passengers_board: Progress exceeds total legs';
		LEAVE sp_main;
	 END IF; 
	 
	 -- Flight information
	 SELECT routeID, support_airline, support_tail, progress, cost INTO v_routeID, v_support_airline, v_support_tail, v_progress, v_cost FROM flight WHERE flightID = ip_flightID; 
	 SELECT seat_capacity, locationID INTO v_seat_capacity, v_locationID FROM airplane WHERE airlineID = v_support_airline AND tail_num = v_support_tail; 
	 SELECT legID INTO v_legID FROM route_path WHERE routeID = v_routeID AND sequence = v_progress + 1; 
	 
	 -- Arrival and departure details
	 SELECT arrival, departure INTO v_arrival, v_departure FROM leg WHERE legID = v_legID; 
	 SELECT locationID INTO v_arrival_locationID FROM airport WHERE airportID = v_arrival; 
	 SELECT locationID INTO v_departure_locationID FROM airport WHERE airportID = v_departure; 
	 
	 SELECT count(*) INTO v_boarding_count 
	 FROM person pe
	 JOIN passenger_vacations pv ON pe.personID = pv.personID 
	 JOIN passenger pa ON pe.personID = pa.personID 
	 WHERE pe.locationID = v_departure_locationID
	 AND pv.sequence = 1 
	 AND pv.airportID = v_arrival
	 AND pa.funds >= v_cost; 
	 
	 -- Are there enough seats?
	 IF v_boarding_count > v_seat_capacity THEN
		signal sqlstate '45000' set message_text = 'Passengers_board: Not enough seats';
		LEAVE sp_main; 
	 ELSE
	 UPDATE person p 
	 JOIN passenger_vacations pv ON p.personID = pv.personID 
	 JOIN passenger pa ON p.personID = pa.personID 
	 SET p.locationID = v_locationID 
	 WHERE p.locationID = v_departure_locationID 
	 AND pv.sequence = 1 
	 AND pv.airportID = v_arrival 
	 AND pa.funds >= v_cost; 
	 
	 -- Remove funds
	 UPDATE passenger pa 
	 JOIN person p ON pa.personID = p.personID 
	 JOIN passenger_vacations pv ON p.personID = pv.personID 
	 SET pa.funds = pa.funds - v_cost 
	 WHERE p.locationID = v_locationID 
	 AND pv.sequence = 1 
	 AND pv.airportID = v_arrival; 
	  
	 -- Edit seat availability
	 UPDATE airplane 
	 SET seat_capacity = seat_capacity - v_boarding_count 
	 WHERE airlineID = v_support_airline AND tail_num = v_support_tail; 
	 END IF; 
	 
	 END // 
	 delimiter ;


-- [9] passengers_disembark()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting off of a flight
at its current airport.  The passengers must be on that flight, and the flight must
be located at the destination airport as referenced by the ticket. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_disembark;
delimiter //
create procedure passengers_disembark (in ip_flightID varchar(50))
sp_main: begin

	-- Ensure the flight exists
    -- Ensure that the flight is in the air
    
    -- Determine the list of passengers who are disembarking
	-- Use the following to check:
		-- Passengers must be on the plane supporting the flight
        -- Passenger has reached their immediate next destionation airport
        
	-- Move the appropriate passengers to the airport
    -- Update the vacation plans of the passengers

    if not exists (
         select 1
         from flight
         where flightID = ip_flightID and airplane_status = 'on_ground'
    ) then
		 signal sqlstate '45000' set message_text = 'Passengers_disembark: Flight not on ground or flight does not exist';
         leave sp_main;
    end if;
    
    update person p
    join passenger_vacations pv on p.personID = pv.personID
    set p.locationID =
      (
         select a.locationID
         from airport a
         where a.airportID =
           (
              select l.arrival
              from flight f
              join route_path rp on f.routeID = rp.routeID
              join leg l on rp.legID = l.legID
              where f.flightID = ip_flightID and rp.sequence = f.progress
           )
      )
    where p.locationID =
         (
            select locationID
            from airplane
            where airlineID = (select support_airline from flight where flightID = ip_flightID)
              and tail_num = (select support_tail from flight where flightID = ip_flightID)
         )
      and pv.airportID =
         (
            select l.arrival
            from flight f
            join route_path rp on f.routeID = rp.routeID
            join leg l on rp.legID = l.legID
            where f.flightID = ip_flightID and rp.sequence = f.progress
         )
      and pv.sequence = 1;
    
    delete from passenger_vacations
    where sequence = 1
      and airportID =
         (
            select l.arrival
            from flight f
            join route_path rp on f.routeID = rp.routeID
            join leg l on rp.legID = l.legID
            where f.flightID = ip_flightID and rp.sequence = f.progress
         );
    
   
    update passenger_vacations pv
    join person p on pv.personID = p.personID
    set pv.sequence = pv.sequence - 1
    where p.locationID =
         (
            select a.locationID
            from airport a
            where a.airportID =
              (
                 select l.arrival
                 from flight f
                 join route_path rp on f.routeID = rp.routeID
                 join leg l on rp.legID = l.legID
                 where f.flightID = ip_flightID and rp.sequence = f.progress
              )
         )
      and pv.sequence > 1;

end //
delimiter ;

-- [10] assign_pilot()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a pilot as part of the flight crew for a given
flight.  The pilot being assigned must have a license for that type of airplane,
and must be at the same location as the flight.  Also, a pilot can only support
one flight (i.e. one airplane) at a time.  The pilot must be assigned to the flight
and have their location updated for the appropriate airplane. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_pilot;
delimiter //
create procedure assign_pilot (in ip_flightID varchar(50), ip_personID varchar(50))
sp_main: begin

	-- Ensure the flight exists
    -- Ensure that the flight is on the ground
    -- Ensure that the flight has further legs to be flown
    
    -- Ensure that the pilot exists and is not already assigned
	-- Ensure that the pilot has the appropriate license
    -- Ensure the pilot is located at the airport of the plane that is supporting the flight
    
    -- Assign the pilot to the flight and update their location to be on the plane

    declare plane_airlineID varchar(50);
    declare tail_no varchar(50);
    declare airplane_type varchar(100);
	declare license_count int default 0;
    
    declare airport_location varchar(50);
    declare flight_location varchar(50);
    declare plane_status varchar(20);
    
    select support_airline, support_tail into plane_airlineID, tail_no from flight where flightID = ip_flightID;

	-- Ensure the flight exists + assign airline and tail number variables

    if (ip_flightID is null
		or
        not exists (select 1 from airplane where airlineID = plane_airlineID and tail_num = tail_no)) then
		 signal sqlstate '45000' set message_text = 'Assign_pilot: airlineID not found or tail_num not found';
        leave sp_main;
	end if;
	

	-- Ensure the flight is on the ground
    if ((select airplane_status from flight where flightID = ip_flightID) not like 'on_ground') then
		 signal sqlstate '45000' set message_text = 'Assign_pilot: Flight not on ground';
        leave sp_main;
	end if;
	
	-- Ensure that the flight has further legs to be flown
    if (not has_remaining_legs(ip_flightID)) then
		 signal sqlstate '45000' set message_text = 'Assign_pilot: Remaining legs not found';
		leave sp_main;
    end if;

	-- Assign airplane_type and flight_location variables
	select locationID, plane_type into flight_location, airplane_type from airplane
	where airlineID = plane_airlineID and tail_num = tail_no;
    
	if not exists (select 1 from airplane where airlineID = plane_airlineID and tail_num = tail_no) then
		signal sqlstate '45000' set message_text = 'Assign_pilot: AirlineID and Tailnum combination not found';
		leave sp_main;
	end if;
	
	-- Ensure that the pilot exists...
	if not exists (select 1 from pilot where personID = ip_personID) then
		signal sqlstate '45000' set message_text = 'Assign_pilot: Person with associated personID not found';
		leave sp_main;
	end if;

	-- ...and is not already assigned
	if ((select commanding_flight from pilot where personID = ip_personID) is not null) then
		signal sqlstate '45000' set message_text = 'Assign_pilot: Pilot already assigned';
		leave sp_main;
	end if;

	-- Ensure that the pilot has the appropriate license - ERROR
	select count(*) into license_count from pilot_licenses where personID = ip_personID and ((airplane_type is null and license is null) or license = airplane_type);
	if license_count = 0 then
		signal sqlstate '45000' set message_text = 'Assign_pilot: Pilot has no liscense';
		leave sp_main;
	end if;
    
    -- find corresponding current leg by sequence <-> flight_progress, then access departure (airportID), then access locationID
	select a.locationID into airport_location
		from flight f join route_path rp on f.routeID = rp.routeID and rp.sequence = f.progress
			join leg l on rp.legID = l.legID
				join airport a on l.departure = a.airportID
					where f.flightID = ip_flightID;
    
	-- Ensure the pilot is located at the airport of the plane that is supporting the flight
	if ((select locationID from person where personID = ip_personID) <> airport_location) then
		signal sqlstate '45000' set message_text = 'Assign_pilot: Pilot is not at location supporting the flight';
		leave sp_main;
	end if;

	-- Assign the pilot to the flight and update their location to be on the plane
    update person set locationID = flight_location where personID = ip_personID;
	update pilot set commanding_flight = ip_flightID where personID = ip_personID;

end //
delimiter ;

-- [11] recycle_crew()
-- -----------------------------------------------------------------------------
/* This stored procedure releases the assignments for a given flight crew.  The
flight must have ended, and all passengers must have disembarked. */
-- -----------------------------------------------------------------------------
drop procedure if exists recycle_crew;
delimiter //
create procedure recycle_crew (in ip_flightID varchar(50))
sp_main: begin

	-- Ensure that the flight is on the ground
    -- Ensure that the flight does not have any more legs
    
    -- Ensure that the flight is empty of passengers
    
    -- Update assignements of all pilots
    -- Move all pilots to the airport the plane of the flight is located at

    if (
         (select airplane_status from flight where flightID = ip_flightID) = 'on_ground'
         and
         (select progress from flight where flightID = ip_flightID) =
           (select count(*) from route_path where routeID = (select routeID from flight where flightID = ip_flightID))
         and
         not exists (
             select 1 from person
             where locationID = (
                select locationID from airplane
                where airlineID = (select support_airline from flight where flightID = ip_flightID)
                  and tail_num = (select support_tail from flight where flightID = ip_flightID)
             )
             and personID not in (
                select personID from pilot where commanding_flight = ip_flightID
             )
         )
       )
    then
         update person p
         join pilot pi on p.personID = pi.personID
         join flight f on pi.commanding_flight = f.flightID
         join route_path rp on f.routeID = rp.routeID
         join leg l on rp.legID = l.legID
         join airport a on l.arrival = a.airportID
         set p.locationID = a.locationID
         where f.flightID = ip_flightID
           and rp.sequence = (
                select count(*) from route_path where routeID = f.routeID
           );
         
         update pilot p
         join flight f on p.commanding_flight = f.flightID
         set p.commanding_flight = null
         where f.flightID = ip_flightID;
    end if;

end //
delimiter ;

-- [12] retire_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a flight that has ended from the system.  The
flight must be on the ground, and either be at the start its route, or at the
end of its route.  And the flight must be empty - no pilots or passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists retire_flight;
delimiter //
create procedure retire_flight (in ip_flightID varchar(50))
sp_main: begin

	declare f_status varchar(20);
    declare progress int;
    declare leg_max int;
    declare passengers int;
    declare pilots int;
    declare loco varchar(50);
    declare a_tail varchar(50);
    
    select support_tail, airplane_status, progress into a_tail, f_status, progress
	from flight where flightID = ip_flightID;

	-- Ensure that the flight is on the ground
    if f_status != 'on_ground' then
    		signal sqlstate '45000' set message_text = 'Retire flight: flight is not on the ground';

        leave sp_main;
    end if;
    
    -- Ensure that the flight does not have any more legs
    select count(*) into leg_max
	from route_path where routeID = (select routeID from flight where flightID = ip_flightID);

    if progress !=  0 and progress != leg_max then
    		signal sqlstate '45000' set message_text = 'Retire flight: Flight has more legs to fly';

        leave sp_main; 
    end if;
    
    -- Ensure that there are no more people on the plane supporting the flight
    select locationID into loco
      from airplane
     where tail_num = a_tail;

    -- Ensure that there are no passengers at the airplane's location
    select count(*) into passengers
      from person
     where locationID = loco;

    if passengers > 0 then
    		signal sqlstate '45000' set message_text = 'Retire flight: Passengers still exist';

        leave sp_main;  
    end if;

    select count(*) into pilots
      from person
     where locationID = loco;

    if pilots > 0 then
    		signal sqlstate '45000' set message_text = 'Retire flight: More than 0 pilots';

        leave sp_main;  
    end if;
    
    -- Remove the flight from the system
    delete from flight where flightID = ip_flightID;

end //
delimiter ;

-- [13] simulation_cycle()
-- -----------------------------------------------------------------------------
/* This stored procedure executes the next step in the simulation cycle.  The flight
with the smallest next time in chronological order must be identified and selected.
If multiple flights have the same time, then flights that are landing should be
preferred over flights that are taking off.  Similarly, flights with the lowest
identifier in alphabetical order should also be preferred.

If an airplane is in flight and waiting to land, then the flight should be allowed
to land, passengers allowed to disembark, and the time advanced by one hour until
the next takeoff to allow for preparations.

If an airplane is on the ground and waiting to takeoff, then the passengers should
be allowed to board, and the time should be advanced to represent when the airplane
will land at its next location based on the leg distance and airplane speed.

If an airplane is on the ground and has reached the end of its route, then the
flight crew should be recycled to allow rest, and the flight itself should be
retired from the system. */
-- -----------------------------------------------------------------------------
drop procedure if exists simulation_cycle;
delimiter //
create procedure simulation_cycle ()
sp_main: begin

	-- Identify the next flight to be processed
    
    -- If the flight is in the air:
		-- Land the flight and disembark passengers
        -- If it has reached the end:
			-- Recycle crew and retire flight
            
	-- If the flight is on the ground:
		-- Board passengers and have the plane takeoff
        
	-- Hint: use the previously created procedures

    declare next_flightID varchar(50);

	-- Identify the next flight to be processed
	with min_chrono_flights as (select * from flight where next_time = (select min(next_time) from flight)),
	landing_prio_flights as ((select * from min_chrono_flights where airplane_status = 'in_flight')
							union all
							(select * from min_chrono_flights where airplane_status = 'on_ground' 
							and
							not exists (select 1 from min_chrono_flights where airplane_status = 'in_flight')))
	select flightID into next_flightID from landing_prio_flights order by flightID limit 1;
	
	if next_flightID is null then
    		signal sqlstate '45000' set message_text = 'Simulation Cycle: next flight ID is null';

		leave sp_main;
	end if;
    
    -- If the flight is in the air:
    if ((select airplane_status from flight where flightID = next_flightID) = 'in_flight') then
		-- Land the flight...
        call flight_landing(next_flightID);
        -- ...and disembark passengers
        call passengers_disembark(next_flightID);
		
		-- If it has reached the end:
        if (not has_remaining_legs(next_flightID)) then
			-- Recycle crew...
            call recycle_crew(next_flightID);
            -- ...and retire flight
			call retire_flight(next_flightID);
        end if;

	-- If the flight is on the ground:
	else
		-- Board passengers...
		call passengers_board(next_flightID);
        -- ...and have the plane takeoff
        call flight_takeoff(next_flightID);
    end if;


end //
delimiter ;

-- [14] flights_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where flights that are currently airborne are located. 
We need to display what airports these flights are departing from, what airports 
they are arriving at, the number of flights that are flying between the 
departure and arrival airport, the list of those flights (ordered by their 
flight IDs), the earliest and latest arrival times for the destinations and the 
list of planes (by their respective flight IDs) flying these flights. */
-- -----------------------------------------------------------------------------
create or replace view flights_in_the_air (departing_from, arriving_at, num_flights,
	flight_list, earliest_arrival, latest_arrival, airplane_list) as
select departure, arrival, count(*), GROUP_CONCAT(flightID ORDER BY flightID SEPARATOR ', '), min(next_time), max(next_time), GROUP_CONCAT(locationID ORDER BY locationID DESC SEPARATOR ', ')
from airplane a
join flight f on (a.tail_num = f.support_tail and a.airlineID = f.support_airline)
join route_path r on (r.routeID = f.routeID and f.progress = r.sequence)
join leg l on (r.legID = l.legID)
where airplane_status = 'in_flight'
group by l.legID;


-- [15] flights_on_the_ground()
-- ------------------------------------------------------------------------------
/* This view describes where flights that are currently on the ground are 
located. We need to display what airports these flights are departing from, how 
many flights are departing from each airport, the list of flights departing from 
each airport (ordered by their flight IDs), the earliest and latest arrival time 
amongst all of these flights at each airport, and the list of planes (by their 
respective flight IDs) that are departing from each airport.*/
-- ------------------------------------------------------------------------------
create or replace view flights_on_the_ground (departing_from, num_flights,
	flight_list, earliest_arrival, latest_arrival, airplane_list) as 
select 
    a.airportID as departing_from,
    count(distinct f.flightID) as num_flights,
    group_concat(distinct f.flightID order by f.flightID separator ',') as flight_list,
    min(f.next_time) as earliest_arrival,
    max(f.next_time) as latest_arrival,
    group_concat(distinct ap.locationID order by f.flightID separator ',') as airplane_list
from flight f
join airplane ap on f.support_airline = ap.airlineID and f.support_tail = ap.tail_num
join route_path rp on f.routeID = rp.routeID and (f.progress = rp.sequence - 1 or f.progress = rp.sequence)
join leg l on l.legID = rp.legID
join airport a on (f.progress = rp.sequence - 1 and a.airportID = l.departure) or (f.progress = rp.sequence and a.airportID = l.arrival)
where f.airplane_status = 'on_ground' or f.airplane_status is null
group by a.airportID;

-- [16] people_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently airborne are located. We 
need to display what airports these people are departing from, what airports 
they are arriving at, the list of planes (by the location id) flying these 
people, the list of flights these people are on (by flight ID), the earliest 
and latest arrival times of these people, the number of these people that are 
pilots, the number of these people that are passengers, the total number of 
people on the airplane, and the list of these people by their person id. */
-- -----------------------------------------------------------------------------
create or replace view people_in_the_air (departing_from, arriving_at, num_airplanes,
	airplane_list, flight_list, earliest_arrival, latest_arrival, num_pilots,
	num_passengers, joint_pilots_passengers, person_list) as
    select leg.departure as departures, leg.arrival as arrivals,
    COUNT(DISTINCT airplane.airlineID, airplane.tail_num) as num_airplanes,
    GROUP_CONCAT(distinct airplane.locationID) as airplane_list, 
    GROUP_CONCAT(distinct flight.flightID) as flight_list, 
    MIN(flight.next_time) as earliest, MAX(flight.next_time) as latest,
    COUNT(distinct pilot.personID) as num_pilots, COUNT(distinct passenger.personID) as num_passengers,
    COUNT(distinct person.personID) as joint_pilot_passengers,
    GROUP_CONCAT(distinct person.personID) as person_list
FROM flight
	JOIN airplane ON airplane.airlineID = flight.support_airline AND airplane.tail_num = flight.support_tail
    JOIN route_path ON route_path.routeID = flight.routeID AND route_path.sequence = flight.progress
    JOIN leg ON route_path.legID = leg.legID
    JOIN person ON person.locationID = airplane.locationID
    LEFT JOIN pilot on person.personID = pilot.personID
    LEFT JOIN passenger on person.personID = passenger.personID WHERE flight.airplane_status = 'in_flight'
GROUP BY leg.departure, leg.arrival;


-- [17] people_on_the_ground()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently on the ground and in an 
airport are located. We need to display what airports these people are departing 
from by airport id, location id, and airport name, the city and state of these 
airports, the number of these people that are pilots, the number of these people 
that are passengers, the total number people at the airport, and the list of 
these people by their person id. */
-- -----------------------------------------------------------------------------
create or replace view people_on_the_ground (departing_from, airport, airport_name,
	city, state, country, num_pilots, num_passengers, joint_pilots_passengers, person_list) as
select
	a.airportID as departing_from,
    a.locationID as airport,
    a.airport_name as airport_name,
    a.city as city,
    a.state as state,
    a.country as country,
    sum(pl.personID is not null) as num_pilots,
    sum(pl.personID is null) as num_passengers,
    count(p.personID) as joint_pilots_passengers,
    group_concat(p.personID order by p.personID separator ',') as person_list
from person p join airport a on p.locationID = a.locationID left join pilot pl on p.personID = pl.personID group by airportID;


-- [18] route_summary()
-- -----------------------------------------------------------------------------
/* This view will give a summary of every route. This will include the routeID, 
the number of legs per route, the legs of the route in sequence, the total 
distance of the route, the number of flights on this route, the flightIDs of 
those flights by flight ID, and the sequence of airports visited by the route. */
-- -----------------------------------------------------------------------------
create or replace view route_summary (route, num_legs, leg_sequence, route_length,
	num_flights, flight_list, airport_sequence) as
select 
    r.routeID,
    la.num_legs,
    la.leg_sequence,
    la.route_length,
    IFNULL(fa.num_flights, 0) as num_flights,
    IFNULL(fa.flight_list, '') as flight_list,
    la.airport_sequence
from route r
join (
  select 
      rp.routeID,
      count(*) as num_legs,
      group_concat(rp.legID) as leg_sequence,
      sum(l.distance) as route_length,
      group_concat(concat(l.departure, '->', l.arrival)) as airport_sequence
  from route_path rp
  join leg l on rp.legID = l.legID
  group by rp.routeID
) la on r.routeID = la.routeID
left join (
  select 
      routeID,
      count(*) as num_flights,
      group_concat(flightID) as flight_list
  from flight
  group by routeID
) fa on r.routeID = fa.routeID;

-- [19] alternative_airports()
-- -----------------------------------------------------------------------------
/* This view displays airports that share the same city and state. It should 
specify the city, state, the number of airports shared, and the lists of the 
airport codes and airport names that are shared both by airport ID. */
-- -----------------------------------------------------------------------------
create or replace view alternative_airports (city, state, country, num_airports,
	airport_code_list, airport_name_list) as
select 
    city,
    state,
    country,
    count(*) as num_airports,
    group_concat(distinct airportID) as airport_codes,
    group_concat(distinct airport_name order by airportID) as airport_names
from airport
group by city, state, country
having count(*) > 1;

drop function if exists has_remaining_legs;
delimiter //
create function has_remaining_legs(ip_flightID varchar(50))
returns boolean deterministic
sp_main: begin

    declare legs_tobe int;
    declare current_leg int;
    
	select count(routeID) into legs_tobe from route_path where routeID
    in (select routeID from flight where flightID = ip_flightID);
    
    select progress into current_leg from flight where flightID = ip_flightID;
    
    if (current_leg = legs_tobe) then
		return false;
	else
		return true;
	end if;
end //
delimiter ;