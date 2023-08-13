defmodule Epoxi.Context do
  @moduledoc """
  Interface contexts must implement
  """

  defstruct adapter: Epoxi.Adapters.SMTP,
            compiler: Epoxi.EExCompiler,
            config: %Epoxi.SmtpConfig{},
            socket: nil

  @type t :: %__MODULE__{
          adapter: Epoxi.Adapter.t(),
          compiler: Epoxi.Compiler.t(),
          config: Epoxi.SmtpConfig.t(),
          socket: pid()
        }
end
