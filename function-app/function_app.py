from datetime import datetime
from datetime import timedelta
from os import getenv

import azure.functions as func
import geojson

from azure.functions import Context
from azure.monitor.opentelemetry import configure_azure_monitor
from shapely import Point

import trainchallenge as tc


# Configure OpenTelemetry to use Azure Monitor with the
# APPLICATIONINSIGHTS_CONNECTION_STRING environment variable.
ai_conn_str = getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
if ai_conn_str:
    configure_azure_monitor(
        connection_string=ai_conn_str,
        logger_name="trainchallenge",  # Set the namespace for the logger
    )

# Load the SEPTA Regional Rail data
septa_gdf = tc.septa.load_regional_rail_data()
septa_date_format = "%Y-%m-%d %H:%M:%S.%f"

# Load the DC Metro data
dcmetro_gdf = tc.dcmetro.load_dcmetro_data()

# Require authentication for all functions
app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

# logger = logging.getLogger(
#     "trainchallenge"
# )  # Logging telemetry will be collected from logging calls made with this logger and all of it's children loggers.


def get_lat_long(req: func.HttpRequest) -> tuple[float, float]:
    """
    Extract latitude and longitude from the request parameters or body.

    Parameters
    ----------
    req : func.HttpRequest
        The HTTP request object.

    Returns
    -------
    tuple of float
        A tuple containing latitude and longitude as floats.

    Raises
    ------
    ValueError
        If latitude or longitude cannot be converted to float.
    """

    # parse and validate latitude input
    lat_input = req.params.get("latitude")
    if not lat_input:
        req_body = req.get_json()
        lat_input = req_body.get("latitude")

    lat_float = float(lat_input)

    # parse and validate longitude input
    long_input = req.params.get("longitude")
    if not long_input:
        req_body = req.get_json()
        long_input = req_body.get("longitude")

    long_float = float(long_input)

    return lat_float, long_float


@app.route(route="nearest_septa")
def nearest_septa(req: func.HttpRequest, context: Context) -> func.HttpResponse:
    """
    Get the nearest SEPTA Regional Rail station to the given latitude and longitude.

    Parameters
    --------
    req : func.HttpRequest
        The HTTP request object.
    context : Context
        The invocation context object for the function.

    Returns
    -------
    func.HttpResponse
        A JSON response containing the nearest station's information.
    """

    # Application Insights trace correlation for logging telemetry
    # Store current TraceContext in dictionary format
    # carrier = {
    #     "traceparent": context.trace_context.trace_parent,
    #     "tracestate": context.trace_context.trace_state,
    # }
    # tracer = trace.get_tracer(__name__)
    # # Start a span using the current context
    # with tracer.start_as_current_span(
    #     "http_trigger_span",
    #     context=extract(carrier),
    #     attributes={
    #         "user.id": str(req.headers.get("x-ms-client-principal-id")),
    #         "user.name": str(req.headers.get("x-ms-client-principal-name")),
    #     },
    # ):

    # parse and validate latitude/longitude input
    try:
        lat_float, long_float = get_lat_long(req)
    except ValueError:
        return func.HttpResponse(
            "Invalid latitude or longitude value. Must be a float.",
            status_code=400,
        )

    # get the nearest station
    p = Point(long_float, lat_float, 0)
    nearest_row_idx = tc.common.get_nearest_point(p, septa_gdf["geometry"])  # type: ignore[reportArgumentType]
    if nearest_row_idx is None:
        return func.HttpResponse(  # TODO: possibly a better status code for communicating this to the client
            "There is no SEPTA station within 10 miles of this location",
            status_code=400,
        )
    nearest_station = septa_gdf.loc[nearest_row_idx]

    # return the nearest station as a GeoJSON feature
    ret = geojson.Feature(
        geometry=nearest_station.geometry,
        properties={
            "stop_id": nearest_station.stop_id,
            "station_name": nearest_station.station_name,
            "gmaps_directions": f"https://www.google.com/maps/dir/?api=1&origin={lat_float},{long_float}&destination={nearest_station.geometry.y},{nearest_station.geometry.x}&travelmode=walking&dir_action=navigate",
        },
    )

    return func.HttpResponse(
        geojson.dumps(ret),
        mimetype="application/json",
        status_code=200,
    )


@app.route(route="next_septa")
def next_septa(req: func.HttpRequest, context: Context) -> func.HttpResponse:
    """
    Get the next SEPTA Regional Rail train nearest to the given latitude and longitude
    on a particular line going in a particular direction.

    Parameters
    --------
    req : func.HttpRequest
        The HTTP request object.
    context : Context
        The invocation context object for the function.

    Returns
    -------
    func.HttpResponse
        A JSON response containing the nearest station's information.
    """

    # parse and validate latitude/longitude input
    try:
        lat_float, long_float = get_lat_long(req)
    except ValueError:
        return func.HttpResponse(
            "Invalid latitude or longitude value. Must be a float.",
            status_code=400,
        )

    # parse line name input
    try:
        line_name = req.params.get("line_name")
        if not line_name:
            req_body = req.get_json()
            line_name = req_body.get("line_name")
        if not line_name or len(line_name) < 1:
            raise ValueError("Invalid line_name")
    except ValueError:
        return func.HttpResponse(
            "Invalid line_name value.",
            status_code=400,
        )

    # parse train direction input
    try:
        train_dir = req.params.get("train_dir")
        if not train_dir:
            req_body = req.get_json()
            train_dir = req_body.get("train_dir")
        if not (train_dir == "N" or train_dir == "S"):  # can't do in because of type checking
            raise ValueError("Invalid train direction")
    except ValueError:
        return func.HttpResponse(
            "Invalid train_dir value. Must be N or S",
            status_code=400,
        )

    # get the nearest station
    p = Point(long_float, lat_float, 0)
    nearest_row_idx = tc.common.get_nearest_point(p, septa_gdf["geometry"])  # type: ignore[reportArgumentType]
    if nearest_row_idx is None:
        return func.HttpResponse(  # TODO: possibly a better status code for communicating this to the client
            "There is no SEPTA station within 10 miles of this location",
            status_code=400,
        )
    nearest_station = septa_gdf.loc[nearest_row_idx]

    # get the next train
    next_train = tc.septa.septa_api.get_next_arrival(nearest_station.stop_id, line_name, train_dir)
    time_to_leave = "There are no trains found"
    if next_train is not None:
        # calculate time to reach train station
        # approximate walking speed conservatively at 2 mph
        # also accounting for the fact that we are only computing distance as the crow flies
        train_dist = tc.common.gps_to_miles(
            lat_float, long_float, nearest_station.geometry.y, nearest_station.geometry.x
        )
        travel_time = train_dist / 2.0

        # parse the time the train leaves and compute the time you must leave by
        train_sched = datetime.strptime(next_train["sched_time"], septa_date_format)
        leave_time = train_sched - timedelta(hours=travel_time)

        if datetime.now() < leave_time:  # the current time is before the time to leave
            time_to_leave = leave_time.strftime("%Y-%m-%d %H:%M:%S")
        else:
            time_to_leave = "You can't make the next train in time"

    # return the nearest station as a GeoJSON feature
    ret = geojson.Feature(
        geometry=nearest_station.geometry,
        properties={
            "stop_id": nearest_station.stop_id,
            "station_name": nearest_station.station_name,
            "gmaps_directions": f"https://www.google.com/maps/dir/?api=1&origin={lat_float},{long_float}&destination={nearest_station.geometry.y},{nearest_station.geometry.x}&travelmode=walking&dir_action=navigate",
            "time_to_leave": time_to_leave,
        },
    )

    return func.HttpResponse(
        geojson.dumps(ret),
        mimetype="application/json",
        status_code=200,
    )


@app.route(route="nearest_dcmetro")
def nearest_dcmetro(req: func.HttpRequest, context: Context) -> func.HttpResponse:
    """
    Get the nearest SEPTA Regional Rail station to the given latitude and longitude.

    Parameters
    --------
    req : func.HttpRequest
        The HTTP request object.
    context : Context
        The invocation context object for the function.

    Returns
    -------
    func.HttpResponse
        A JSON response containing the nearest station's information.
    """

    # parse and validate latitude/longitude input
    try:
        lat_float, long_float = get_lat_long(req)
    except ValueError:
        return func.HttpResponse(
            "Invalid latitude or longitude value. Must be a float.",
            status_code=400,
        )

    # get the nearest station
    p = Point(long_float, lat_float, 0)
    nearest_row_idx = tc.common.get_nearest_point(p, dcmetro_gdf["geometry"])  # type: ignore[reportArgumentType]
    if nearest_row_idx is None:
        return func.HttpResponse(  # TODO: possibly a better status code for communicating this to the client
            "There is no DC Metro station within 10 miles of this location",
            status_code=400,
        )
    nearest_station = dcmetro_gdf.loc[nearest_row_idx]

    # return the nearest station as a GeoJSON feature
    ret = geojson.Feature(
        geometry=nearest_station.geometry,
        properties={
            "stop_id": nearest_station.GIS_ID,
            "station_name": nearest_station.NAME,
            "gmaps_directions": f"https://www.google.com/maps/dir/?api=1&origin={lat_float},{long_float}&destination={nearest_station.geometry.y},{nearest_station.geometry.x}&travelmode=walking&dir_action=navigate",
        },
    )

    return func.HttpResponse(
        geojson.dumps(ret),
        mimetype="application/json",
        status_code=200,
    )
