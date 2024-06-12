import config

from dune_client.types import QueryParameter
from dune_client.client import DuneClient
from dune_client.query import QueryBase

query_id = '3816057'

dune = DuneClient(
    api_key=config.dune_api_key,
    base_url="https://api.dune.com",
    request_timeout=(config.request_timeout)
)

query_result = dune.get_latest_result_dataframe(
    query=query_id
    # # filter for users account more than a month old and more than bottom active tier
    # , filters="account_age > 30 and fid_active_tier > 1"
    # # sort result by number of channels they are follow in descending order
    # , sort_by=["channels desc"]
)

query_result.to_csv('query_result.csv', index=False)