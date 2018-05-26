defmodule Epox.Mail.DecoderTest do
  use ExUnit.Case

  alias Epoxi.Mail.Decoder
  alias Epoxi.SMTP.Utils
  alias Epoxi.Test.Helpers

  describe "handle_events" do
    test "it parses JSON strings" do
      json = Helpers.test_json_string()
      {:ok, email} = Poison.decode(json)
      struct = Utils.atomize_keys(email)
      struct = update_in(struct[:data], fn(map) -> Map.to_list(map) end)
      email = Map.merge(%Mailman.Email{}, struct)

      assert Decoder.handle_events([Helpers.test_json_string()], 234, :no_state) == {:noreply, [email], :no_state}
    end
  end
end
