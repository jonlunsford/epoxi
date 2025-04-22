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

  test "POST /messages" do
    json = Helpers.gen_json_payload(1000)
    conn = conn(:post, "/messages", %{"messages" => json})
    conn = Epoxi.Endpoint.call(conn, [])

    assert conn.status == 200
    assert conn.resp_body == "Messages queued"
  end
end
