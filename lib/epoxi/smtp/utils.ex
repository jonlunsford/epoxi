defmodule Epoxi.SMTP.Utils do
  @moduledoc """
  Utilities to help with general SMTP interaction
  """

  @doc "guesses the current hosts FQDN"
  def guess_FQDN() do
    {:ok, hostname} = :inet.gethostname()
    {:ok, hostent} = :inet.gethostbyname(hostname)
    {:hostent, fqdn, _aliases, :inet, _length, _ip_addresses} = hostent
    fqdn
  end

  @doc "Validates required option is present"
  def validate_required_option(options, option) do
    case Map.fetch(options, option) do
      {:ok, _value} -> options
      :error -> Map.update(options, :errors, ["#{option} is required"], &(&1 ++ ["#{option} is required"]))
    end
  end

  @doc "Validates dependent options if the required option and value are present"
  def validate_dependent_options(options, {{key, value}, deps} = _params) do
    case Map.fetch(options, key) do
      {:ok, ^value} ->
        deps
        |> Enum.reduce(fn(dep, _opt) -> validate_required_option(options, dep) end)
      {:ok, _result} -> options
      :error -> options
    end
  end

  @doc """
  Accepts a domain name as a string and a lookup_handler function
  Loads name servers from the OS if none are currently loaded
  Returns a sorted list of mx records, by priority, for the specified domain
  """
  @spec mx_lookup(domain :: String.t(), lookup_handler :: Fun.t()) :: List.t(Tuple.t())
  def mx_lookup(domain, lookup_handler \\ &inet_res_lookup/1) do
    with :ok <- load_ns(),
         result <- lookup_handler.(domain),
      do: Enum.sort(result)
  end

  @doc "Default mx lookup handler using :inet_res"
  def inet_res_lookup(domain) do
    :inet_res.lookup(to_charlist(domain), :in, :mx)
  end

  defp load_ns() do
    case List.keyfind(:inet_db.get_rc(), :nameserver, 0) do
      nil ->
        :inet_config.do_load_resolv(:os.type(), :longnames)
        :ok
      _ ->
        :ok
    end
  end
end
