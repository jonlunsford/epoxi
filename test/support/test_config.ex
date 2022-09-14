defmodule Epoxi.TestConfig do
  @moduledoc "Config for external SMPT adapters"

  # Defaults are bare minimum to get a delivery. Ideally, serious senders
  # configure ssl, tls, dkim, etc.
  defstruct port: 2525
end
