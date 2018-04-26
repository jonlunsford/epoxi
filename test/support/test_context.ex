defmodule Epoxi.Test.Context do
  @moduledoc "Responsible to configuring SMTP test context"

  @doc "Returns %Mailman.Context{} configured for testing"
  @spec set(hostname :: String.t()) :: %Mailman.Context{}
  def set(_hostname) do
    %Mailman.Context{
      config: %Mailman.TestConfig{},
      composer: %Mailman.EexComposeConfig{}
    }
  end
end
