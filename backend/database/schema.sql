-- =========================================================
-- MUNICIPAL WASTE COLLECTION MANAGEMENT SYSTEM
-- DATABASE SCHEMA
-- PostgreSQL
-- =========================================================


-- =========================================================
-- 1. USERS
-- Stores login accounts for Citizen, Driver and Admin
-- =========================================================

CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,

    full_name VARCHAR(100) NOT NULL,

    email VARCHAR(150) UNIQUE,

    phone VARCHAR(15) UNIQUE NOT NULL,

    password_hash TEXT NOT NULL,

    role VARCHAR(20) NOT NULL
        CHECK (role IN ('CITIZEN', 'DRIVER', 'ADMIN')),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- =========================================================
-- 2. WARDS
-- =========================================================

CREATE TABLE wards (
    ward_id BIGSERIAL PRIMARY KEY,

    ward_name VARCHAR(100) NOT NULL,

    ward_number VARCHAR(20) UNIQUE NOT NULL,

    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- =========================================================
-- 3. AREAS
-- =========================================================

CREATE TABLE areas (
    area_id BIGSERIAL PRIMARY KEY,

    ward_id BIGINT NOT NULL,

    area_name VARCHAR(150) NOT NULL,

    description TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_area_ward
        FOREIGN KEY (ward_id)
        REFERENCES wards(ward_id)
        ON DELETE RESTRICT
);


-- =========================================================
-- 4. CITIZEN DETAILS
-- One citizen account can have one citizen profile
-- =========================================================

CREATE TABLE citizen_profiles (
    citizen_id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL UNIQUE,

    area_id BIGINT,

    address TEXT,

    latitude DECIMAL(9,6),

    longitude DECIMAL(9,6),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_citizen_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_citizen_area
        FOREIGN KEY (area_id)
        REFERENCES areas(area_id)
        ON DELETE SET NULL
);


-- =========================================================
-- 5. DRIVERS
-- Driver-specific information
-- =========================================================

CREATE TABLE drivers (
    driver_id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL UNIQUE,

    employee_code VARCHAR(50) UNIQUE NOT NULL,

    license_number VARCHAR(100) UNIQUE,

    joining_date DATE,

    is_available BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_driver_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);


-- =========================================================
-- 6. VEHICLES
-- =========================================================

CREATE TABLE vehicles (
    vehicle_id BIGSERIAL PRIMARY KEY,

    vehicle_number VARCHAR(50) UNIQUE NOT NULL,

    registration_number VARCHAR(50) UNIQUE NOT NULL,

    vehicle_type VARCHAR(50),

    capacity_kg DECIMAL(10,2),

    manufacturer VARCHAR(100),

    model VARCHAR(100),

    status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE'
        CHECK (
            status IN (
                'AVAILABLE',
                'ASSIGNED',
                'MAINTENANCE',
                'INACTIVE'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- =========================================================
-- 7. STOPS
-- Waste collection stops / collection points
-- =========================================================

CREATE TABLE stops (
    stop_id BIGSERIAL PRIMARY KEY,

    area_id BIGINT NOT NULL,

    stop_name VARCHAR(150) NOT NULL,

    address TEXT,

    latitude DECIMAL(9,6) NOT NULL,

    longitude DECIMAL(9,6) NOT NULL,

    stop_order_default INTEGER,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_stop_area
        FOREIGN KEY (area_id)
        REFERENCES areas(area_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_stop_order
        CHECK (
            stop_order_default IS NULL
            OR stop_order_default > 0
        )
);


-- =========================================================
-- 8. ROUTES
-- =========================================================

CREATE TABLE routes (
    route_id BIGSERIAL PRIMARY KEY,

    route_name VARCHAR(150) NOT NULL,

    route_code VARCHAR(50) UNIQUE NOT NULL,

    description TEXT,

    estimated_duration_minutes INTEGER,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_route_duration
        CHECK (
            estimated_duration_minutes IS NULL
            OR estimated_duration_minutes > 0
        )
);


-- =========================================================
-- 9. ROUTE STOPS
-- Defines which stops belong to which route and in what order
-- =========================================================

CREATE TABLE route_stops (
    route_stop_id BIGSERIAL PRIMARY KEY,

    route_id BIGINT NOT NULL,

    stop_id BIGINT NOT NULL,

    stop_sequence INTEGER NOT NULL,

    estimated_minutes_from_start INTEGER,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_route_stop_route
        FOREIGN KEY (route_id)
        REFERENCES routes(route_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_route_stop_stop
        FOREIGN KEY (stop_id)
        REFERENCES stops(stop_id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_route_stop_sequence
        UNIQUE (route_id, stop_sequence),

    CONSTRAINT uq_route_stop
        UNIQUE (route_id, stop_id),

    CONSTRAINT chk_stop_sequence
        CHECK (stop_sequence > 0)
);


-- =========================================================
-- 10. SCHEDULES
-- Regular collection schedule for a route
-- =========================================================

CREATE TABLE schedules (
    schedule_id BIGSERIAL PRIMARY KEY,

    route_id BIGINT NOT NULL,

    day_of_week SMALLINT NOT NULL,

    start_time TIME NOT NULL,

    end_time TIME,

    collection_type VARCHAR(30) NOT NULL DEFAULT 'DOOR_TO_DOOR'
        CHECK (
            collection_type IN (
                'DOOR_TO_DOOR',
                'COMMUNITY_POINT',
                'MIXED'
            )
        ),

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_schedule_route
        FOREIGN KEY (route_id)
        REFERENCES routes(route_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_day_of_week
        CHECK (day_of_week BETWEEN 0 AND 6),

    CONSTRAINT chk_schedule_time
        CHECK (
            end_time IS NULL
            OR end_time > start_time
        )
);


-- =========================================================
-- 11. ASSIGNMENTS
-- Specific driver + vehicle + schedule + collection date
-- =========================================================

CREATE TABLE assignments (
    assignment_id BIGSERIAL PRIMARY KEY,

    schedule_id BIGINT NOT NULL,

    driver_id BIGINT NOT NULL,

    vehicle_id BIGINT NOT NULL,

    assignment_date DATE NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'SCHEDULED'
        CHECK (
            status IN (
                'SCHEDULED',
                'STARTED',
                'COMPLETED',
                'CANCELLED',
                'DELAYED'
            )
        ),

    start_time TIMESTAMPTZ,

    end_time TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_assignment_schedule
        FOREIGN KEY (schedule_id)
        REFERENCES schedules(schedule_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assignment_driver
        FOREIGN KEY (driver_id)
        REFERENCES drivers(driver_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_assignment_vehicle
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicles(vehicle_id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_schedule_assignment
        UNIQUE (schedule_id, assignment_date)
);


-- =========================================================
-- 12. TRACKING SESSIONS
-- A vehicle has a tracking session.
-- Current provider = driver's phone GPS.
-- =========================================================

CREATE TABLE tracking_sessions (
    tracking_session_id BIGSERIAL PRIMARY KEY,

    assignment_id BIGINT NOT NULL,

    vehicle_id BIGINT NOT NULL,

    driver_id BIGINT NOT NULL,

    provider VARCHAR(30) NOT NULL DEFAULT 'PHONE_GPS'
        CHECK (
            provider IN (
                'PHONE_GPS',
                'VEHICLE_GPS'
            )
        ),

    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    ended_at TIMESTAMPTZ,

    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (
            status IN (
                'ACTIVE',
                'ENDED'
            )
        ),

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_tracking_assignment
        FOREIGN KEY (assignment_id)
        REFERENCES assignments(assignment_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_tracking_vehicle
        FOREIGN KEY (vehicle_id)
        REFERENCES vehicles(vehicle_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_tracking_driver
        FOREIGN KEY (driver_id)
        REFERENCES drivers(driver_id)
        ON DELETE RESTRICT
);


-- =========================================================
-- 13. GPS LOCATIONS
-- Stores location points from the tracking session
-- =========================================================

CREATE TABLE gps_locations (
    gps_location_id BIGSERIAL PRIMARY KEY,

    tracking_session_id BIGINT NOT NULL,

    latitude DECIMAL(9,6) NOT NULL,

    longitude DECIMAL(9,6) NOT NULL,

    accuracy_meters DECIMAL(8,2),

    speed_kmph DECIMAL(8,2),

    heading_degrees DECIMAL(6,2),

    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_gps_tracking_session
        FOREIGN KEY (tracking_session_id)
        REFERENCES tracking_sessions(tracking_session_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_latitude
        CHECK (
            latitude BETWEEN -90 AND 90
        ),

    CONSTRAINT chk_longitude
        CHECK (
            longitude BETWEEN -180 AND 180
        ),

    CONSTRAINT chk_speed
        CHECK (
            speed_kmph IS NULL
            OR speed_kmph >= 0
        )
);


-- =========================================================
-- 14. COLLECTION EVENTS
-- Records what happened at each stop during an assignment
-- =========================================================

CREATE TABLE collection_events (
    collection_event_id BIGSERIAL PRIMARY KEY,

    assignment_id BIGINT NOT NULL,

    route_stop_id BIGINT NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (
            status IN (
                'PENDING',
                'ARRIVED',
                'COLLECTED',
                'MISSED',
                'SKIPPED'
            )
        ),

    arrived_at TIMESTAMPTZ,

    completed_at TIMESTAMPTZ,

    remarks TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_collection_assignment
        FOREIGN KEY (assignment_id)
        REFERENCES assignments(assignment_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_collection_route_stop
        FOREIGN KEY (route_stop_id)
        REFERENCES route_stops(route_stop_id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_assignment_route_stop
        UNIQUE (assignment_id, route_stop_id)
);


-- =========================================================
-- 15. DELAY REPORTS
-- =========================================================

CREATE TABLE delay_reports (
    delay_report_id BIGSERIAL PRIMARY KEY,

    assignment_id BIGINT NOT NULL,

    driver_id BIGINT NOT NULL,

    reason VARCHAR(200) NOT NULL,

    description TEXT,

    reported_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    resolved BOOLEAN NOT NULL DEFAULT FALSE,

    resolved_at TIMESTAMPTZ,

    CONSTRAINT fk_delay_assignment
        FOREIGN KEY (assignment_id)
        REFERENCES assignments(assignment_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_delay_driver
        FOREIGN KEY (driver_id)
        REFERENCES drivers(driver_id)
        ON DELETE RESTRICT
);


-- =========================================================
-- 16. COMPLAINTS
-- =========================================================

CREATE TABLE complaints (
    complaint_id BIGSERIAL PRIMARY KEY,

    citizen_id BIGINT NOT NULL,

    area_id BIGINT,

    stop_id BIGINT,

    subject VARCHAR(200) NOT NULL,

    description TEXT NOT NULL,

    image_path TEXT,

    category VARCHAR(50) NOT NULL,

    status VARCHAR(30) NOT NULL DEFAULT 'SUBMITTED'
        CHECK (
            status IN (
                'SUBMITTED',
                'UNDER_REVIEW',
                'ASSIGNED',
                'IN_PROGRESS',
                'RESOLVED',
                'CLOSED',
                'REJECTED',
                'FALSE'
            )
        ),

    assigned_to BIGINT,

    admin_remark TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    resolved_at TIMESTAMPTZ,

    CONSTRAINT fk_complaint_citizen
        FOREIGN KEY (citizen_id)
        REFERENCES citizen_profiles(citizen_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_complaint_area
        FOREIGN KEY (area_id)
        REFERENCES areas(area_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_complaint_stop
        FOREIGN KEY (stop_id)
        REFERENCES stops(stop_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_complaint_admin
        FOREIGN KEY (assigned_to)
        REFERENCES users(user_id)
        ON DELETE SET NULL
);


-- =========================================================
-- 17. NOTIFICATIONS
-- =========================================================

CREATE TABLE notifications (
    notification_id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL,

    title VARCHAR(200) NOT NULL,

    message TEXT NOT NULL,

    notification_type VARCHAR(50) NOT NULL,

    related_assignment_id BIGINT,

    is_read BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notification_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_notification_assignment
        FOREIGN KEY (related_assignment_id)
        REFERENCES assignments(assignment_id)
        ON DELETE SET NULL
);


-- =========================================================
-- INDEXES
-- =========================================================

CREATE INDEX idx_users_role
    ON users(role);

CREATE INDEX idx_areas_ward
    ON areas(ward_id);

CREATE INDEX idx_stops_area
    ON stops(area_id);

CREATE INDEX idx_route_stops_route
    ON route_stops(route_id);

CREATE INDEX idx_route_stops_stop
    ON route_stops(stop_id);

CREATE INDEX idx_schedules_route
    ON schedules(route_id);

CREATE INDEX idx_assignments_date
    ON assignments(assignment_date);

CREATE INDEX idx_assignments_driver
    ON assignments(driver_id);

CREATE INDEX idx_assignments_vehicle
    ON assignments(vehicle_id);

CREATE INDEX idx_tracking_assignment
    ON tracking_sessions(assignment_id);

CREATE INDEX idx_tracking_status
    ON tracking_sessions(status);

CREATE INDEX idx_gps_tracking_time
    ON gps_locations(tracking_session_id, recorded_at);

CREATE INDEX idx_collection_assignment
    ON collection_events(assignment_id);

CREATE INDEX idx_complaints_citizen
    ON complaints(citizen_id);

CREATE INDEX idx_complaints_status
    ON complaints(status);

CREATE INDEX idx_notifications_user
    ON notifications(user_id, is_read);