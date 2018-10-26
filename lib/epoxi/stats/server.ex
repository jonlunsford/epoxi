defmodule Epoxi.Stats.Server do
  @moduledoc """
  Writes stats to disk for very basic profiling using gnuplot
  """

  use GenServer

  @timeres :millisecond

  ## CLIENT API

  # Progress.start_link [:a, :b, :c]
  def start_link(scopes \\ []) do
    GenServer.start_link(__MODULE__, scopes, name: __MODULE__)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  # increment counter for given scope by `n`
  #     Progress.incr(:my_scope)
  #     Progress.incr(:my_scope, 10)
  def incr(scope, n \\ 1) do
    GenServer.cast __MODULE__, {:incr, scope, n}
  end


  ## CALLBACKS

  def init(scopes) do
    # open "progress-{scope}.log" file for every scope
    files = Enum.map(scopes, fn scope ->
      {scope, File.open!("progress-#{scope}.log", [:write])}
    end)

    # keep current counter for every scope
    counts = Enum.map(scopes, fn scope -> {scope, 0} end)

    # save current time
    time = :os.system_time(@timeres)

    # write first data point for every scope with current time and value 0
    # this helps to keep the graph starting nicely at (0,0) point
    Enum.each(files, fn {_, io} -> write(io, time, 0) end)

    {:ok, {time, files, counts}}
  end

  def handle_cast({:incr, scope, n}, {time, files, counts}) do
    # update counter
    {value, counts} = Keyword.get_and_update!(counts, scope, &({&1+n, &1+n}))

    # write new data point
    write(files[scope], time, value)

    {:noreply, {time, files, counts}}
  end

  defp write(file, time, value) do
    time = :os.system_time(@timeres) - time
    IO.write(file, "#{time}\t#{value}\n")
  end
end
