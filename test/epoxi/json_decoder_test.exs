defmodule Epoxi.JSONDecoderTest do
  use ExUnit.Case, async: true

  alias Epoxi.JSONDecoder
  alias Epoxi.Test.Helpers

  describe "decode" do
    test "it transforms json strings into %Epoxi.Email{} structs" do
      json = Helpers.gen_json_payload(1)

      email = JSONDecoder.decode(json)

      assert [%Epoxi.Email{}] = email
    end

    test "it parses multiple recipients" do
      json = Helpers.gen_json_payload(3)

      emails = JSONDecoder.decode(json)

      assert Enum.count(emails) == 3
    end

    test "it parses 1000 recipients" do
      json = Helpers.gen_json_payload(1000)

      emails = JSONDecoder.decode(json)

      assert Enum.count(emails) == 1000
    end

    test "it returns errors" do
      json = "{one: two}"

      assert {:error, _reason} = JSONDecoder.decode(json)
    end
  end
end
