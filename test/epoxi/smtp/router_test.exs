defmodule Epoxi.SMTP.RouterTest do
  use ExUnit.Case

  alias Epoxi.SMTP.Router

  describe "get_mx_hosts" do
    test "it returns sorted hosts if they're found" do
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

      assert Router.get_mx_hosts("gmail.com", lookup_handler) == sorted_result
    end

    test "it returns the relay host if no mx records are found" do
      lookup_handler = fn(_domain) -> [] end

      assert Router.get_mx_hosts("gmail.com", lookup_handler) == [{0, "gmail.com"}]
    end
  end
end
