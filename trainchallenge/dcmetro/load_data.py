from pathlib import Path

import geopandas as gpd


def load_dcmetro_data(geojson_pth: Path | None = None) -> gpd.GeoDataFrame:
    """
    Load the DC metro data from the specified file path.

    Parameters
    ----------
    geojson_pth : Path, optional
        The path to the GeoJSON file. If None, the function will look for the
        file in the default location.
        Defaults to None.
        The default location is the `data` directory relative to the module's
        location.
        The file is named `Metro_Stations_Regional.geojson`.

    Returns
    -------
    geopandas.GeoDataFrame
        A GeoDataFrame containing the DC metro data.

    Raises
    ------
    FileNotFoundError
        If the specified KMZ file does not exist.
    """

    # check that the geojson file exists
    if geojson_pth is None:
        geojson_pth = Path(__file__).parent / "data" / "Metro_Stations_Regional.geojson"
    if not geojson_pth.exists():
        raise FileNotFoundError(f"DC Metro data file not found: {geojson_pth}")

    # Load the metro data
    metro_data = gpd.read_file(geojson_pth)

    return metro_data
