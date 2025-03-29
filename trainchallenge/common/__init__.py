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
