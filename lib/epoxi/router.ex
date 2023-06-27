defmodule Epoxi.Router do
  @moduledoc """
  Routes emails to the appropriate node
  """

  def route(from_domain, mod, fun, args) do
    entry =
      Enum.find(table(), fn {domain, _node} ->
        domain == from_domain
      end) || no_entry_error(from_domain)

    if elem(entry, 1) == node() do
      apply(mod, fun, args)
    else
      {Epoxi.RouterTasks, elem(entry, 1)}
      |> Task.Supervisor.async(Epoxi.Router, :route, [from_domain, mod, fun, args])
      |> Task.await()
    end
  end

  def table do
    # TODO: Replace with ETS table and add registration as nodes come online
    [
      {"local-foo.com", :foo@jl},
      {"local-bar.com", :bar@jl},
      {"local-biz.com", :biz@jl}
    ]
  end

  defp no_entry_error(from_domain) do
    raise "No node found to send from #{from_domain}"
  end
end
