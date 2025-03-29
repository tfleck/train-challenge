from pathlib import Path

import geopandas as gpd


def load_dcmetro_data():
    """
    Load the DC metro data from the specified file path.

    Returns
    -------
    geopandas.GeoDataFrame
        A GeoDataFrame containing the DC metro data.

    Raises
    ------
    FileNotFoundError
        If the specified KMZ file does not exist.

    Notes
    -----
    The function expects the GeoJSON file to be located in the `data` directory
    relative to the module's location. The file is named `Metro_Stations_Regional.geojson`.
    """

    # make directory to hold extracted files
    data_pth = Path(__file__).parent / "data" / "Metro_Stations_Regional.geojson"
    if not data_pth.exists():
        raise FileNotFoundError(f"DC Metro data file not found: {data_pth}")

    # Load the metro data
    metro_data = gpd.read_file(data_pth)

    return metro_data
