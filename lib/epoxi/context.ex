defmodule Epoxi.Context do
  @moduledoc """
  Interface contexts must implement
  """

  defstruct client: Epoxi.SmtpClient,
            compiler: Epoxi.EExCompiler,
            config: %Epoxi.SmtpConfig{},
            socket: nil

  @type t :: %__MODULE__{
          client: module(),
          compiler: Epoxi.Compiler.t(),
          config: Epoxi.SmtpConfig.t(),
          socket: pid()
        }

  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    smtp_config = Application.get_env(:epoxi, :smtp_config, %Epoxi.SmtpConfig{})
    smtp_config = struct(Epoxi.SmtpConfig, smtp_config)

    %__MODULE__{
      client: Keyword.get(opts, :client, Epoxi.SmtpClient),
      compiler: Keyword.get(opts, :compiler, Epoxi.EExCompiler),
      config: smtp_config,
      socket: Keyword.get(opts, :socket, nil)
    }
  end
end
