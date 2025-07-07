defmodule Epoxi.Email.RoutingKey do
  @moduledoc """
  Handles routing key generation for email batches.
  """
  @type t() :: String.t()

  def generate(domain, ip) do
    domain = sanitize_domain(domain)
    ip_part = format_ip(ip)
    "#{domain}_#{ip_part}"
  end

  defp sanitize_domain(domain) do
    String.replace(domain, ~r/[^a-zA-Z0-9_]/, "_")
  end

  defp format_ip(ip) when is_binary(ip), do: String.replace(ip, ".", "_")
  defp format_ip(nil), do: "default"
end
