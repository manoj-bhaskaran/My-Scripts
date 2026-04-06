"""Regression tests for seat_assignment import behavior."""

from importlib import import_module


def test_seat_assignment_import_does_not_require_pandas_at_import_time():
    module = import_module("src.python.data.seat_assignment")
    assert hasattr(module, "allocate_seats")
    assert hasattr(module, "_get_pandas")
