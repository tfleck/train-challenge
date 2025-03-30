import logging

from os import getenv

import azure.functions as func
import geojson

from azure.functions import Context
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace
from opentelemetry.propagate import extract
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

# Authentiation is done by Azure App Service proxy, so we set the auth level to anonymous.
app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

logger = logging.getLogger(
    "trainchallenge"
)  # Logging telemetry will be collected from logging calls made with this logger and all of it's children loggers.


@app.route(route="http_trigger")
def http_trigger(req: func.HttpRequest, context: Context) -> func.HttpResponse:
    # Store current TraceContext in dictionary format
    carrier = {
        "traceparent": context.trace_context.trace_parent,
        "tracestate": context.trace_context.trace_state,
    }
    tracer = trace.get_tracer(__name__)
    # Start a span using the current context
    with tracer.start_as_current_span(
        "http_trigger_span",
        context=extract(carrier),
        attributes={
            "user.id": str(req.headers.get("x-ms-client-principal-id")),
            "user.name": str(req.headers.get("x-ms-client-principal-name")),
        },
    ):
        logger.info("Python HTTP trigger function processed a request.")

        logger.info(f"User id: {req.headers.get('x-ms-client-principal-id')}")
        logger.info(f"User name: {req.headers.get('x-ms-client-principal-name')}")

        lat_input = req.params.get("latitude")
        if not lat_input:
            try:
                req_body = req.get_json()
            except ValueError:
                return func.HttpResponse(
                    "Invalid JSON in request body",
                    status_code=400,
                )
            else:
                lat_input = req_body.get("latitude")

        lat_float = None
        try:
            lat_float = float(lat_input)
        except ValueError:
            return func.HttpResponse(
                "Invalid latitude value. Must be a float.",
                status_code=400,
            )

        long_input = req.params.get("longitude")
        if not long_input:
            try:
                req_body = req.get_json()
            except ValueError:
                return func.HttpResponse(
                    "Invalid JSON in request body",
                    status_code=400,
                )
            else:
                long_input = req_body.get("longitude")

        long_float = None
        try:
            long_float = float(long_input)
        except ValueError:
            return func.HttpResponse(
                "Invalid longitude value. Must be a float.",
                status_code=400,
            )

        # check that lat and long are not None
        if lat_float is None or long_float is None:
            return func.HttpResponse(
                "Please pass latitude and longitude in the query string or in the request body",
                status_code=400,
            )

        p = Point(long_float, lat_float, 0)
        nearest_row_idx = tc.common.get_nearest_point(p, septa_gdf["geometry"])  # type: ignore[reportArgumentType]

        nearest_station = septa_gdf.loc[nearest_row_idx]

        ret = geojson.Feature(
            geometry=nearest_station.geometry,
            properties={
                "stop_id": nearest_station.stop_id,
                "station_name": nearest_station.station_name,
            },
        )

        return func.HttpResponse(
            geojson.dumps(ret),
            mimetype="application/json",
            status_code=200,
        )
