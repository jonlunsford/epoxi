defmodule Epoxi.Utils do
  @moduledoc """
  Utilities to help with general SMTP interaction
  """

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
end
