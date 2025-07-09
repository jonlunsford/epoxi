defmodule Epoxi.DNS.Lookup do
  @moduledoc """
  Behavior for MX record lookups.
  """

  @callback lookup(String.t()) :: [tuple()] | []
end

defmodule Epoxi.DNS.MxLookup do
  @moduledoc """
  Default implementation of the Epoxi.DNS.MxLookup behaviour using :inet_res for DNS lookups.
  """
  @behaviour Epoxi.DNS.Lookup

  @doc """
  Accepts a domain name as a string and a lookup_handler function
  Loads name servers from the OS if none are currently loaded
  Returns a sorted list of mx records, by priority, for the specified domain
  """
  @spec lookup(domain :: String.t(), lookup_handler :: function()) ::
          list({non_neg_integer(), String.t()})
  def lookup(domain, lookup_handler \\ &inet_res_lookup/1) do
    with :ok <- load_ns(),
         result <- lookup_handler.(domain),
         do: Enum.sort(result)
  end

  @doc "Default mx lookup handler using :inet_res"
  def inet_res_lookup(domain) do
    cache = :persistent_term.get({:epoxi_dns_cache, domain}, :not_found)

    case cache do
      :not_found ->
        results = :inet_res.lookup(to_charlist(domain), :in, :mx)
        :persistent_term.put({:epoxi_dns_cache, domain}, results)
        results

      cached_results ->
        cached_results
    end
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

defmodule Epoxi.DNS.TestMxLookup do
  @moduledoc """
  Test implementation of the Epoxi.DNS.MxLookup behaviour for testing purposes.
  """
  @behaviour Epoxi.DNS.Lookup

  def lookup("gmail.com"), do: [{10, ~c"gmail-smtp-in.l.google.com"}]
  def lookup("yahoo.com"), do: [{1, ~c"mta5.am0.yahoodns.net"}]
  def lookup(domain), do: [{10, domain}]
end
