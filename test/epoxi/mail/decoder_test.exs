defmodule Epox.Mail.DecoderTest do
  use ExUnit.Case

  alias Epoxi.Mail.Decoder
  alias Epoxi.SMTP.Utils
  alias Epoxi.Test.Helpers

  describe "handle_events" do
    test "it transforms json strings into %Mailman.Email{} structs" do
      json =
        """
        {
          "from": "test@test.com",
          "to": ["test1@test.com"],
          "subject": "Test Subject",
          "text": "Hello Text! <%= name %>",
          "html": "Hello HTML! <%= name %>",
          "data": {
            "test1@test.com": { "name": "test1first" }
          }
        }
        """
        |> String.trim()

      {:ok, json_map} = Poison.decode(json)

      valid_map =
        json_map
        |> Utils.atomize_keys()
        |> Map.put(:data, [name: "test1first"])

      expected_struct = struct(Mailman.Email, valid_map)

      assert Decoder.handle_events([json], 234, :no_state) == {:noreply, [expected_struct], :no_state}
    end

    test "it parses multiple recipients" do
      json =
        """
        {
          "from": "test@test.com",
          "to": ["test1@test.com", "test2@test.com", "test3@test.com"],
          "subject": "Test Subject",
          "text": "Hello Text! <%= first_name %> <%= last_name %>",
          "html": "Hello HTML! <%= first_name %> <%= last_name %>",
          "data": {
            "test1@test.com": { "first_name": "test1first", "last_name": "test1last" },
            "test2@test.com": { "first_name": "test2first", "last_name": "test2last" },
            "test3@test.com": { "first_name": "test3first", "last_name": "test3last" }
          }
        }
        """
        |> String.trim()

      {:noreply, emails, :no_state} = Decoder.handle_events([json], 234, :no_state)

      assert Enum.count(emails) == 3
    end
  end
end
