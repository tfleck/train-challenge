import tempfile
import zipfile

from pathlib import Path

import geopandas as gpd

from lxml import html

from trainchallenge.common import get_next_after_match


def load_regional_rail_data(kmz_pth: Path | None = None) -> gpd.GeoDataFrame:
    """
    Load the SEPTA Regional Rail data from a KMZ file and return it as a GeoDataFrame.

    The function extracts the KMZ file, processes the KML data, and parses specific
    fields such as `stop_id` and `station_name` from the description.

    Returns
    -------
    geopandas.GeoDataFrame
        A GeoDataFrame containing the SEPTA Regional Rail data with additional
        columns for `stop_id` and `station_name`.

    Raises
    ------
    FileNotFoundError
        If the specified KMZ file does not exist.

    Notes
    -----
    The function expects the KMZ file to be located in the `data` directory
    relative to the module's location. Extracted files are stored in an
    `extracted` subdirectory.
    """

    # check that the kmz file exists
    if kmz_pth is None:
        kmz_pth = Path(__file__).parent / "data" / "SEPTARegionalRailStations2016.kmz"
    if not kmz_pth.exists():
        raise FileNotFoundError(f"SEPTA data file not found: {kmz_pth}")

    # create a temporary directory to hold extracted files
    with tempfile.TemporaryDirectory() as tmp_dir:
        # Open the KMZ file and extract its contents
        with zipfile.ZipFile(kmz_pth, "r") as kmz:
            kmz.extractall(tmp_dir)

        # Load the SEPTA data
        septa_data = gpd.read_file(tmp_dir + "/doc.kml", driver="libkml")

    septa_data["stop_id"] = septa_data["Description"].apply(
        lambda x: get_next_after_match(html.fromstring(x).xpath("//tr/td/text()"), "Stop_ID")
    )
    septa_data["station_name"] = septa_data["Description"].apply(
        lambda x: get_next_after_match(html.fromstring(x).xpath("//tr/td/text()"), "Station_Na")
    )

    return septa_data
