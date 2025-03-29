# import logging

from os import getenv

import azure.functions as func

from azure.functions import Context
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace
from opentelemetry.propagate import extract


# Configure OpenTelemetry to use Azure Monitor with the
# APPLICATIONINSIGHTS_CONNECTION_STRING environment variable.
configure_azure_monitor(
    connection_string=getenv("APPLICATIONINSIGHTS_CONNECTION_STRING"),
    logger_name="trainchallenge",  # Set the namespace for the logger
)
# logger = logging.getLogger(
#     "trainchallenge"
# )  # Logging telemetry will be collected from logging calls made with this logger and all of it's children loggers.


app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


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
            "user_id": str(req.headers.get("x-ms-client-principal-id")),
        },
    ):
        print("Python HTTP trigger function processed a request.")

        print(f"User id: {req.headers.get('x-ms-client-principal-id')}")
        print(f"User name: {req.headers.get('x-ms-client-principal-name')}")

        name = req.params.get("name")
        if not name:
            try:
                req_body = req.get_json()
            except ValueError:
                pass
            else:
                name = req_body.get("name")

        if name:
            return func.HttpResponse(f"Hello, {name}. This HTTP triggered function executed successfully.")
        else:
            return func.HttpResponse(
                "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.",
                status_code=200,
            )
