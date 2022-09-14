# test/epoxi/email_test.exs
defmodule Epoxi.EmailTest do
  use ExUnit.Case, async: true

  alias Epoxi.Email

  describe "put_content_type/1" do
    test "it handles html" do
      email =
        %Email{html: "foo"}
        |> Email.put_content_type()


      assert %{content_type: "text/html"} = email
    end

    test "it handles text" do
      email =
        %Email{text: "foo"}
        |> Email.put_content_type()


      assert %{content_type: "text/plain"} = email
    end

    test "it handles mixed" do
      email =
        %Email{text: "foo", html: "bar"}
        |> Email.put_content_type()


      assert %{content_type: "multipart/mixed"} = email
    end

    test "it defaults to text/html" do
      email =
        %Email{}
        |> Email.put_content_type()

      assert %{content_type: "text/html"} = email
    end
  end
end
