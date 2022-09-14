defmodule Epoxi.Context do
  @moduledoc """
  Responsible for composing sending config and other context needed for delivery
  """
  defstruct config: %Epoxi.SmtpConfig{},
    compiler: Epoxi.EExCompiler

  @type t :: %__MODULE__{
    config: Epoxi.SmtpConfig.t(),
    compiler: Atom.t()
  }
end
