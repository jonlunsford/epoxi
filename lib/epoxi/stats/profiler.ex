defmodule Epoxi.Stats.LoadTester do
  @moduledoc """
  Rudimentary load testing module

  TODO:
    - Make concurrent and configurable
    - Be able to send various payloads / batch sizes
  """

  alias Epox.Test.Helpers

  def init(send_count) do
    Epoxi.Stats.Server.start_link([:dispatch, :decode, :send])

    for n <- 1..send_count do
      HTTPotion.post("http://localhost:4000/send", [body: Helpers.test_json_string()])
    end

    Epoxi.Stats.Server.stop()
  end
end
