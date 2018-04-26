defmodule Epoxi.Test.Router do
  @moduledoc """
  This module is used to stand in as a real Epoxi.SMTP.Router in test
  """

  alias Epoxi.SMTP.Utils

  @spec get_mx_hosts(hostname :: String.t(), lookup_handler :: Fun.t()) :: List.t(Tuple.t())
  def get_mx_hosts(hostname, lookup_handler \\ &test_res_lookup/1) do
    mx_records = Utils.mx_lookup(hostname, lookup_handler)

    case mx_records do
      [] ->
        [{0, hostname}]
      _ ->
        mx_records
    end
  end

  def test_res_lookup(_domain) do
    [
      {30, "alt2.aspmx.l.google.com"},
      {10, "aspmx.l.google.com"},
      {20, "alt1.aspmx.l.google.com"}
    ]
  end
end
