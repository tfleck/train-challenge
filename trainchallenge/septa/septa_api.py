from datetime import datetime
from typing import Any
from typing import Literal

import requests


septa_date_format = "%Y-%m-%d %H:%M:%S.%f"


def get_next_arrival(stop_id: str, line_name: str, direction: Literal["N", "S"]) -> Any | None:
    """
    Get the next arriving train at a given station going in a particular direction
    on a particular line.

    Parameters
    ----------
    stop_id: str
        The SEPTA stop id of the station
    line_name : str
        The SEPTA train line name
    direction : str
        Which direction the train is traveling in, either nortbound or southbound ("N", "S")

    Returns
    -------
    Any
        A JSON object with the train data
    """
    params = {"station": stop_id, "direction": direction}
    try:
        response = requests.request(
            method="GET", url="https://www3.septa.org/api/Arrivals/index.php", params=params, timeout=30
        )
        response.raise_for_status()  # Raise an exception for HTTP errors
        rj = response.json()  # Parse and return the JSON response

        # parse returned json
        train_list = next(iter(rj.values()))
        if len(train_list) == 0:
            return None
        if direction == "S":
            train_list = train_list[0]["Southbound"]
        elif direction == "N":
            train_list = train_list[0]["Northbound"]

        train_list = [t for t in train_list if t["line"] == line_name]
        if len(train_list) == 0:
            return None

        # get first scheduled (account for multiple trains on the same line)
        earliest_idx = 0
        if len(train_list) > 1:
            earliest_dt = datetime.strptime(train_list[0]["sched_time"], septa_date_format)
            for train_idx in range(1, len(train_list)):
                train_sched = datetime.strptime(train_list[train_idx]["sched_time"], septa_date_format)
                if train_sched < earliest_dt:
                    earliest_dt = train_sched
                    earliest_idx = train_idx
        return train_list[earliest_idx]

    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"API request failed: {e}") from e
