import math

from geopandas import GeoSeries
from shapely.geometry import Point


def get_nearest_point(p: Point, pts: GeoSeries):
    """
    Get the index of the nearest point in a GeoSeries to a given point.

    Parameters
    ----------
    p : Point
        The point for which the nearest point in the GeoSeries is to be found.
    pts : GeoSeries
        A GeoSeries containing points to search for the nearest point.

    Returns
    -------
    int
        The index of the nearest point in the GeoSeries.
    """

    # Check if the GeoSeries is empty
    if pts.empty:
        raise IndexError("GeoSeries is empty. Cannot find nearest point.")
    # Check if the point is empty
    if p.is_empty:
        raise ValueError("Point is empty. Cannot find nearest point.")
    # Check if the point is a valid geometry
    if not p.is_valid:
        raise ValueError("Point is not a valid geometry. Cannot find nearest point.")

    idx = pts.sindex.nearest(p)
    return idx[1][0]


def get_next_after_match(arr: list[str], target: str):
    """
    Get the next element in the array after the target element.

    Parameters
    ----------
    arr : list of str
        Array of elements.
    target : str
        Target element to find.

    Returns
    -------
    str
        The next element in the array after the target element.

    Raises
    ------
    ValueError
        If the target is not found in the array.
    ValueError
        If the target is the last element in the array.
    """

    if target not in arr:
        raise ValueError(f"Target {target} not found in the array.")
    if arr.index(target) == len(arr) - 1:
        raise ValueError(f"Target {target} is the last element in the array.")
    if arr.index(target) == len(arr) - 2:
        return arr[-1]
    return arr[arr.index(target) + 1]


def gps_to_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the distance between two GPS coordinates using the Haversine formula.

    Parameters
    ----------
    lat1 : float
        Latitude of the first point.
    lon1 : float
        Longitude of the first point.
    lat2 : float
        Latitude of the second point.
    lon2 : float
        Longitude of the second point.

    Returns
    -------
    float
        Distance in miles between the two points.

    Raises
    ------
    ValueError
        If any of the latitude or longitude values are not valid floats.
    """

    # Check if all inputs are valid floats
    for val in [lat1, lon1, lat2, lon2]:
        if not isinstance(val, int | float):
            raise ValueError(f"Invalid input: {val}. Must be a float.")

    # Convert latitude and longitude from degrees to radians
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])

    # Haversine formula to calculate distance
    dlon = lon2 - lon1
    dlat = lat2 - lat1

    a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    c = 2 * math.asin(math.sqrt(a))

    # Radius of Earth in miles
    r = 3958.76

    return c * r
