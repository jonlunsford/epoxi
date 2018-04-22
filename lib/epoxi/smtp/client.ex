defmodule Epoxi.SMTP.Client do
  @moduledoc """
  This module is used to interact with mail servers over SMTP
  """

  alias Epoxi.SMTP.Utils

  @default_options %{
    ssl: false,
    tls: :always,
    auth: :never,
    hostname: Utils.guess_FQDN(),
    retries: 1
  }

  @doc "Validates options are valid before attempting SMTP connections"
  @spec do_preflight(options :: Map.t()) :: all_options :: Map.t() | {:error, reason :: String.t()}
  def do_preflight(options) do
    all_options = Map.merge(@default_options, options)
    all_options
    |> Utils.validate_required_option(:relay)
    |> Utils.validate_dependent_options({{:auth, :always}, [:username, :password]})
  end

  @spec get_hosts(options :: Map.t(), lookup_handler :: Fun.t()) :: List.t(Tuple.t())
  def get_hosts(options, lookup_handler) do
    mx_records = Utils.mx_lookup(options.relay, lookup_handler)

    case mx_records do
      [] ->
        [{0, options.relay}]
      _ ->
        mx_records
    end
  end
end
