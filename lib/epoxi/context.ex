defmodule Epoxi.Context do
  @moduledoc """
  Responsible for composing sending config and other context needed for delivery
  """
  defstruct config: %Epoxi.SmtpConfig{}, composer: nil

  @type t :: %__MODULE__{
    config: Epoxi.SmtpConfig.t(),
    composer: nil
  }
end
