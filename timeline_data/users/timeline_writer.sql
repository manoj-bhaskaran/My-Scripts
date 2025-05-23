-- Create timeline_writer user if it doesn't already exist
-- Create timeline_writer user if it doesn't already exist
DO
$$
BEGIN
   IF NOT EXISTS (
       SELECT FROM pg_catalog.pg_roles WHERE rolname = 'timeline_writer'
   ) THEN
       CREATE USER timeline_writer;
   END IF;
END
$$;
-- Allow only timeline_writer to connect to this
GRANT CONNECT ON DATABASE timeline_data TO timeline_writer;

-- Grant minimal required privileges
GRANT USAGE ON SCHEMA timeline TO timeline_writer;
GRANT SELECT, INSERT, UPDATE, DELETE ON timeline.locations TO timeline_writer;
GRANT SELECT, INSERT, UPDATE ON timeline.control to timeline_writer;
GRANT USAGE, SELECT, UPDATE ON SEQUENCE timeline.locations_location_id_seq TO timeline_writer;
