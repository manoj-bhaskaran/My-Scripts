CREATE TABLE timeline.control (
    control_key TEXT PRIMARY KEY,
    last_processed_timestamp TIMESTAMPTZ NOT NULL
);
