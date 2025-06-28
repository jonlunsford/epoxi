defmodule Epoxi.IpPool do
  @moduledoc """
  Manages a pool of outgoing IP addresses for SMTP connections.
  """

  # Placeholder: Replace with your actual outgoing IP addresses
  @ips ["127.0.0.1"]
  @current_ip_index :epoxi_ip_pool_current_index

  @doc """
  Initializes the IP pool by setting the current index to 0.
  This should be called once, e.g., in your application's start callback.
  """
  def init do
    :persistent_term.put(@current_ip_index, 0)
  end

  @doc """
  Retrieves the next IP address from the pool using a round-robin strategy.
  """
  def get_next_ip do
    index = :persistent_term.get(@current_ip_index)
    ip = Enum.at(@ips, index)
    new_index = rem(index + 1, length(@ips))
    :persistent_term.put(@current_ip_index, new_index)
    ip
  end
end
