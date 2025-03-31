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
    nearest_row_idx = tc.common.get_nearest_point(p, dcmetro_gdf["geometry"])  # type: ignore[reportArgumentType]
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
