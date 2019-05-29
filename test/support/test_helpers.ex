defmodule Epoxi.Test.Helpers do
  @moduledoc "Generic test helper functions"

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
