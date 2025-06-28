defmodule Epoxi.Utils do
  @moduledoc """
  Utilities to help with general SMTP interaction
  """

  @doc """
  Accepts a domain name as a string and a lookup_handler function
  Loads name servers from the OS if none are currently loaded
  Returns a sorted list of mx records, by priority, for the specified domain
  """
  @spec mx_lookup(domain :: String.t(), lookup_handler :: (String.t() -> list(tuple()))) :: list(tuple())
  def mx_lookup(domain, lookup_handler \\ &inet_res_lookup/1) do
    with :ok <- load_ns(),
         result <- lookup_handler.(domain),
         do: Enum.sort(result)
  end

  @doc "Default mx lookup handler using :inet_res"
  def inet_res_lookup(domain) do
    :inet_res.lookup(to_charlist(domain), :in, :mx)
  end

  @doc """
  Convert map string keys to :atom keys
  """
  def atomize_keys(nil), do: nil

  # Structs don't do enumerable and anyway the keys are already
  # atoms
  def atomize_keys(struct = %{__struct__: _}) do
    struct
  end

  def atomize_keys(map = %{}) do
    map
    |> Enum.map(fn {k, v} -> {String.to_atom(k), atomize_keys(v)} end)
    |> Enum.into(%{})
  end

  # Walk the list and atomize the keys of
  # of any map members
  def atomize_keys([head | rest]) do
    [atomize_keys(head) | atomize_keys(rest)]
  end

  def atomize_keys(not_a_map) do
    not_a_map
  end

  def map_to_list(map) do
    map
    |> Enum.into([], fn {k, v} -> {k, v} end)
  end

  def group_by_domain(emails) do
    group_by_domain(emails, partition_size: 100)
  end

  @doc """
  Accepts a list of emails and partitions them by the recipients (to) hostname.
  """
  @spec group_by_domain([Epoxi.Email.t()], partition_size: integer) ::
          [{String.t(), [Epoxi.Email.t()]}]
  def group_by_domain(emails, partition_size: partition_size) do
    emails
    |> Enum.group_by(fn email ->
      Epoxi.Parsing.get_hostname(email.to)
    end)
    |> Enum.flat_map(fn {hostname, emails} ->
      emails
      |> Enum.chunk_every(partition_size)
      |> Enum.map(fn part -> {hostname, part} end)
    end)
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
