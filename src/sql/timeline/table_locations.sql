CREATE TABLE timeline.locations (
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    elevation DOUBLE PRECISION,
    -- Optional columns for potential future use or richer data
    accuracy INTEGER,
    activity_type TEXT,
    confidence INTEGER,
    -- Spatial index for efficient location-based queries
    location GEOMETRY (Point, 4326),
    -- Primary key for efficient lookups and to ensure uniqueness (though timestamp might not be strictly unique)
    location_id BIGSERIAL PRIMARY KEY
);

-- Create an index on the timestamp for efficient time-based queries
CREATE INDEX idx_locations_timestamp ON timeline.locations (timestamp);

-- Create a spatial index on the location column for efficient spatial queries
CREATE INDEX idx_locations_location ON timeline.locations USING gist (location);

-- Create a composite index on latitude and longitude for efficient geospatial queries
CREATE INDEX idx_locations_latitude_longitude
ON timeline.locations (latitude, longitude);

-- Create a partial index for locations with elevation not null
CREATE INDEX idx_locations_elevation_not_null
ON timeline.locations (elevation)
WHERE elevation IS NOT NULL;
