defmodule Epoxi.SMTP.UtilsTest do
  use ExUnit.Case
  doctest Epoxi.SMTP.Utils

  alias Epoxi.SMTP.Utils

  test "guess_FQDN returns a non-empty string" do
    assert Utils.guess_FQDN() != ""
  end

  describe "validate_required_option" do
    test "it returns the options if key exists" do
      assert Utils.validate_required_option(%{required: "ok"}, :required)
    end

    test "it returns {:error, reason} if key doesn't exist" do
      assert %{errors: ["relay is required"]} = Utils.validate_required_option(%{}, :relay)
    end
  end

  describe "validate_dependent_options" do
    test "it returns the options if the required key does not exist" do
      options = %{relay: "localhost"}

      assert Utils.validate_dependent_options(options, {{:something, :never}, [:none]}) == options
    end

    test "it returns the options if the dependent options exist" do
      options = %{auth: :always, username: "test", password: "test"}

      assert Utils.validate_dependent_options(options, {{:auth, :always}, [:username, :password]}) == options
    end

    test "it returns an error if dependent options to not exist" do
      options = %{auth: :always, usename: "test"}

      assert %{errors: ["password is required"]} = Utils.validate_dependent_options(options, {{:auth, :always}, [:username, :password]})
    end
  end

  describe "mx_lookup" do
    test "it returns mx records for the provided domain" do
      lookup_handler = fn(_domain) ->
        [
          {30, "alt2.aspmx.l.google.com"},
          {10, "aspmx.l.google.com"},
          {20, "alt1.aspmx.l.google.com"}
        ]
      end

      sorted_result = [
        {10, "aspmx.l.google.com"},
        {20, "alt1.aspmx.l.google.com"},
        {30, "alt2.aspmx.l.google.com"}
      ]

      assert Utils.mx_lookup("google.com", lookup_handler) == sorted_result
    end
  end
end
