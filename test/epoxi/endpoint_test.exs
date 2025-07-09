defmodule Epoxi.EndpointTest do
  use ExUnit.Case, async: true
  import Plug.Test
  alias Epoxi.Test.Helpers

  test "GET /ping" do
    conn = conn(:get, "/ping")
    conn = Epoxi.Endpoint.call(conn, [])

    assert conn.status == 200
    assert conn.resp_body == "pong!"
  end

  describe "POST /messages" do
    test "it routes messages to the :default ip_pool when one is not specified" do
      json = Helpers.gen_json_payload(1000)

      conn = conn(:post, "/messages", %{"message" => json})
      conn = Epoxi.Endpoint.call(conn, [])

      assert conn.status == 200

      assert String.contains?(conn.resp_body, "Successfully routed 1000 emails")
    end

    @tag :distributed
    test "it routes messages to remote ip_pools" do
      json = Helpers.gen_json_payload(1000)

      conn = conn(:post, "/messages", %{"message" => json})
      conn = Epoxi.Endpoint.call(conn, [])

      assert conn.status == 200

      assert String.contains?(conn.resp_body, "Successfully routed 1000 emails")
    end
  end
end
