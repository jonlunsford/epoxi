defmodule Epoxi.TestContext do
  @moduledoc "Context for test SMPT adapters"

  # Defaults are bare minimum to get a delivery. Ideally, serious senders
  # configure ssl, tls, dkim, etc.
  defstruct adapter: Epoxi.Adapters.SMTP,
            compiler: Epoxi.Compilers.EEx,
            config: %Epoxi.SmtpConfig{
              port: 2525,
              relay: "localhost",
              hostname: "localhost",
              auth: :never
            }
end
