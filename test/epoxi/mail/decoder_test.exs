defmodule Epox.Mail.DecoderTest do
  use ExUnit.Case

  alias Epoxi.Mail.Decoder
  alias Epoxi.Test.Helpers

  describe "handle_events" do
    test "it transforms json strings into %Mailman.Email{} structs" do
      json = Helpers.gen_json_payload(1)

      {:noreply, _emails, :no_state} = Decoder.handle_events([json], 234, :no_state)

      assert [_emails] = [%Mailman.Email{}]
    end

    test "it parses multiple recipients" do
      json = Helpers.gen_json_payload(3)

      {:noreply, emails, :no_state} = Decoder.handle_events([json], 234, :no_state)

      assert Enum.count(emails) == 3
    end

    test "it parses 1000 recipients" do
      json = Helpers.gen_json_payload(1000)

      {:noreply, emails, :no_state} = Decoder.handle_events([json], 234, :no_state)

      assert Enum.count(emails) == 1000
    end
  end

end
