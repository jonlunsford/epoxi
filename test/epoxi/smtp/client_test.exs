defmodule Epoxi.SMTP.ClientTest do
  use ExUnit.Case

  alias Epoxi.SMTP.Client
  alias Epoxi.SMTP.Utils

  setup do
    opts = [:binary, packet: :raw, active: false]
    {:ok, socket} = :gen_tcp.listen(9876, opts)

    %{socket: socket}
  end

  describe "do_preflight" do
    test "it returns {:error, reason} when relay is missing" do
      assert %{errors: ["relay is required"]} = Client.do_preflight(%{})
    end

    test "it returns {:error, reason} when dependent options are missing" do
      options = %{auth: :always, username: "test", relay: "localhost"}

      assert %{errors: ["password is required"]} = Client.do_preflight(options)
    end

    test "it returns all options if they are valid" do
      expected_options = %{
        ssl: false,
        tls: :always,
        auth: :never,
        hostname: Utils.guess_FQDN(),
        retries: 1,
        relay: "localhost"
      }

      all_options = Client.do_preflight(%{relay: "localhost"})

      assert Map.equal?(expected_options, all_options)
    end
  end

  describe "get_hosts" do
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

      assert Client.get_hosts(%{relay: "gmail.com"}, lookup_handler) == sorted_result
    end

    test "it returns the relay host if no mx records are found" do
      lookup_handler = fn(_domain) -> [] end

      assert Client.get_hosts(%{relay: "gmail.com"}, lookup_handler) == [{0, "gmail.com"}]
    end
  end
end
