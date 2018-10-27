defmodule Epoxi.Stats.LoadTester do
  @moduledoc """
  Rudimentary load testing module

  TODO:
    - Make concurrent and configurable
  """

  def init(send_count, batch_size) do
    Epoxi.Stats.Server.start_link([:request, :decode, :send, :failure])

    for _n <- 1..send_count do
      HTTPotion.post("http://localhost:4000/send", [body: test_json_string(batch_size)])
    end

    Epoxi.Stats.Server.stop()
  end

  def test_json_string(batch_size) do
    data = build_batch_data(batch_size)
    recipients = Map.keys(data)

    %{
      from: "test@test.com",
      to: recipients,
      subject: "Test Subject",
      text: "Hello Text! <%= first_name %> <%= last_name %>",
      html: "Hello HTML! <%= first_name %> <%= last_name %>",
      data: data
    }
    |> Poison.encode!
  end

  def build_batch_data(size) do
    (1..size)
    |> Enum.reduce(%{}, &generate_data/2)
  end

  def generate_data(num, map) do
    map
    |> Map.put("test#{num}@test.com", %{first_name: "test#{num}first", last_name: "test#{num}last"})
  end
end
