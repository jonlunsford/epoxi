defmodule Epoxi.SMTP.Router do
  @moduledoc """
  This module is used to route recipient hostnames to their corresponding MX records
  """

  alias Epoxi.SMTP.Utils

  @spec get_mx_hosts(hostname :: String.t(), lookup_handler :: Fun.t()) :: List.t(Tuple.t())
  def get_mx_hosts(hostname, lookup_handler \\ &Utils.inet_res_lookup/1) do
    mx_records = Utils.mx_lookup(hostname, lookup_handler)

    case mx_records do
      [] ->
        [{0, hostname}]
      _ ->
        mx_records
    end
  end
end
