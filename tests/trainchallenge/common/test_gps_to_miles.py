from trainchallenge.common import gps_to_miles


def test_gps_to_miles_basic():
    lat1, lon1 = 34.0522, -118.2437  # Los Angeles
    lat2, lon2 = 36.1699, -115.1398  # Las Vegas
    result = gps_to_miles(lat1, lon1, lat2, lon2)
    assert round(result, 1) == 228.4, "Should calculate the correct distance between LA and Las Vegas"


def test_gps_to_miles_same_location():
    lat1, lon1 = 40.7128, -74.0060  # New York
    lat2, lon2 = 40.7128, -74.0060  # New York
    result = gps_to_miles(lat1, lon1, lat2, lon2)
    assert result == 0.0, "Distance between the same location should be 0"


def test_gps_to_miles_opposite_points():
    lat1, lon1 = 0, 0  # Equator and Prime Meridian
    lat2, lon2 = 0, 180  # Opposite side of the globe
    result = gps_to_miles(lat1, lon1, lat2, lon2)
    assert round(result, 1) == 12436.8, "Should calculate the correct distance for opposite points on the globe"


def test_gps_to_miles_negative_coordinates():
    lat1, lon1 = -34.6037, -58.3816  # Buenos Aires
    lat2, lon2 = -33.8688, 151.2093  # Sydney
    result = gps_to_miles(lat1, lon1, lat2, lon2)
    assert round(result, 1) == 7332.9, "Should handle negative coordinates and calculate the correct distance"


def test_gps_to_miles_large_distance():
    lat1, lon1 = 51.5074, -0.1278  # London
    lat2, lon2 = -33.8688, 151.2093  # Sydney
    result = gps_to_miles(lat1, lon1, lat2, lon2)
    assert round(result, 0) == 10560, "Should calculate the correct large distance between London and Sydney"


def test_gps_to_miles_small_distance():
    lat1, lon1 = 37.7749, -122.4194  # San Francisco
    lat2, lon2 = 37.8044, -122.2711  # Oakland
    result = gps_to_miles(lat1, lon1, lat2, lon2)
    assert round(result, 2) == 8.35, "Should calculate the correct small distance between San Francisco and Oakland"
