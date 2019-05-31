defmodule Epoxi.Metrics.LoadTester do
  @moduledoc """
  Rudimentary load testing module
  """

  def init(send_count, batch_size) do
    tasks =
      Enum.map(1..send_count, fn _ ->
        Task.async(fn -> send_request(batch_size) end)
      end)

    tasks
    |> Enum.each(fn task -> Task.await(task) end)
  end

  defp send_request(batch_size) do
    HTTPotion.post("http://localhost:4000/send", [body: gen_json_payload(batch_size)])
  end

  def gen_json_payload(batch_size) do
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
