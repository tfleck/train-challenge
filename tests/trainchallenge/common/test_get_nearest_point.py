import pytest

from geopandas import GeoSeries
from shapely.geometry import Point

from trainchallenge.common import get_nearest_point


def test_get_nearest_point_basic():
    pts = GeoSeries([Point(0, 0), Point(1, 1), Point(2, 2)])
    p = Point(1.1, 1.1)
    result = get_nearest_point(p, pts)
    assert result == 1, "Should return the index of the nearest point"


def test_get_nearest_point_exact_match():
    pts = GeoSeries([Point(0, 0), Point(1, 1), Point(2, 2)])
    p = Point(1, 1)
    result = get_nearest_point(p, pts)
    assert result == 1, "Should return the index of the exact match"


def test_get_nearest_point_empty_geoseries():
    pts = GeoSeries([])
    p = Point(1, 1)
    with pytest.raises(IndexError, match="GeoSeries is empty. Cannot find nearest point."):
        get_nearest_point(p, pts)


def test_get_nearest_point_multiple_points_same_distance():
    pts = GeoSeries([Point(0, 0), Point(1, 1), Point(2, 2), Point(1, 1)])
    p = Point(1.1, 1.1)
    result = get_nearest_point(p, pts)
    assert result == 1, "Should return the first index of the nearest point when distances are equal"


def test_get_nearest_point_far_point():
    pts = GeoSeries([Point(0, 0), Point(1, 1), Point(2, 2)])
    p = Point(100, 100)
    result = get_nearest_point(p, pts)
    assert result is None, "Should return the index of the farthest point when it's the closest"
