defmodule Epoxi.EExCompiler do
  @moduledoc """
  Compiles %Epoxi.Email{} content with EEx
  """

  def compile(%Epoxi.Email{html: h, text: t, data: data} = email)
      when is_bitstring(h) and is_bitstring(t) do
    case data do
      %{} ->
        email

      _ ->
        html = EEx.eval_string(h, data)
        text = EEx.eval_string(t, data)

        %{email | html: html, text: text}
    end
  end

  def compile(email), do: email
end
