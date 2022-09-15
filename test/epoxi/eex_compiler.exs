# test/epoxi/eex_compiler_test.exs
defmodule Epoxi.EExCompilerTest do
  use ExUnit.Case, async: true

  alias Epoxi.Email
  alias Epoxi.EExCompiler

  test "compile/1 with html" do
    email = %Email{
      html: "<h1>Hello <%= name %></h1>",
      text: "Hello <%= name %>",
      data: [name: "foo"]
    }

    result = EExCompiler.compile(email)

    assert result.html =~ "<h1>Hello foo</h1>"
    assert result.text =~ "Hello foo"
  end
end
