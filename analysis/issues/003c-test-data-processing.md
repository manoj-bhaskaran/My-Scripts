# Issue #003c: Test Data Processing Scripts

**Parent Issue**: [#003: Low Test Coverage](./003-low-test-coverage.md)
**Phase**: Phase 1 - Critical Paths
**Effort**: 6-8 hours

## Description
Add tests for data transformation scripts that process CSV, GPX, and timeline data. Data integrity is critical for these operations.

## Scope
- `src/python/data/csv_to_gpx.py` - GPS data conversion
- `src/python/data/validators.py` - Data validation
- `src/python/data/extract_timeline_locations.py` - Location extraction

## Implementation

### CSV to GPX Tests
```python
# tests/python/unit/test_csv_to_gpx.py (expand existing)

def test_csv_to_gpx_conversion(tmp_path):
    """Test basic CSV to GPX conversion."""
    # Create test CSV
    csv_file = tmp_path / "test.csv"
    csv_file.write_text("""lat,lng,time
37.7749,-122.4194,2024-01-01T12:00:00Z
37.7750,-122.4195,2024-01-01T12:01:00Z
""")

    gpx_file = tmp_path / "output.gpx"

    # Convert
    csv_to_gpx(str(csv_file), str(gpx_file))

    # Verify GPX structure
    assert gpx_file.exists()
    content = gpx_file.read_text()
    assert '<gpx' in content
    assert '<trkpt lat="37.7749" lon="-122.4194">' in content

def test_csv_to_gpx_with_elevation(tmp_path, mocker):
    """Test elevation data is included."""
    mocker.patch('elevation.get_elevation', return_value=100.5)

    csv_file = tmp_path / "test.csv"
    csv_file.write_text("lat,lng,time\n37.7749,-122.4194,2024-01-01T12:00:00Z")
    gpx_file = tmp_path / "output.gpx"

    csv_to_gpx(str(csv_file), str(gpx_file))

    content = gpx_file.read_text()
    assert '<ele>100.50</ele>' in content

def test_csv_to_gpx_handles_invalid_csv(tmp_path):
    """Test error handling for invalid CSV."""
    csv_file = tmp_path / "invalid.csv"
    csv_file.write_text("not,valid,csv\ndata")
    gpx_file = tmp_path / "output.gpx"

    with pytest.raises(KeyError):  # Missing required columns
        csv_to_gpx(str(csv_file), str(gpx_file))
```

### Validator Tests
```python
# tests/python/unit/test_validators.py (expand existing)

def test_validate_latitude():
    """Test latitude validation."""
    assert validate_latitude(0.0) == True
    assert validate_latitude(90.0) == True
    assert validate_latitude(-90.0) == True
    assert validate_latitude(91.0) == False
    assert validate_latitude(-91.0) == False

def test_validate_longitude():
    """Test longitude validation."""
    assert validate_longitude(0.0) == True
    assert validate_longitude(180.0) == True
    assert validate_longitude(-180.0) == True
    assert validate_longitude(181.0) == False

def test_validate_timestamp_format():
    """Test timestamp format validation."""
    assert validate_timestamp("2024-01-01T12:00:00Z") == True
    assert validate_timestamp("invalid") == False
```

## Acceptance Criteria
- [ ] csv_to_gpx.py has 50%+ coverage
- [ ] validators.py has 60%+ coverage
- [ ] extract_timeline_locations.py has 40%+ coverage
- [ ] Edge cases tested (empty files, invalid data)
- [ ] Error handling validated

## Benefits
- Ensures data integrity
- Catches transformation errors
- Validates GPS coordinate accuracy
- Documents expected formats

## Related
- Issue #003b (database backup tests)
- Issue #003d (cloud integration tests)
