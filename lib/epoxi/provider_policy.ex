defmodule Epoxi.ProviderPolicy do
  @moduledoc """
  Defines the policy for email providers based on MX host.
  """

  alias Epoxi.Queue.PipelinePolicy

  def for_mx_host(mx_host) when is_binary(mx_host) do
    provider = determine_provider(mx_host)
    get_policy(provider)
  end

  defp determine_provider(mx_host) do
    cond do
      String.contains?(mx_host, "gmail") or String.contains?(mx_host, "google") -> :google
      String.contains?(mx_host, "yahoo") -> :yahoo
      String.contains?(mx_host, "aol") -> :aol
      String.contains?(mx_host, "outlook") or String.contains?(mx_host, "hotmail") -> :outlook
      String.contains?(mx_host, "icloud") -> :icloud
      true -> :default
    end
  end

  defp get_policy(:google) do
    PipelinePolicy.new(
      name: :google,
      max_connections: 10,
      max_retries: 5,
      batch_size: 10,
      batch_timeout: 5_000,
      allowed_messages: 100,
      message_interval: 60_000
    )
  end

  defp get_policy(:yahoo) do
    PipelinePolicy.new(
      name: :yahoo,
      max_connections: 8,
      max_retries: 3,
      batch_size: 5,
      batch_timeout: 3_000,
      allowed_messages: 50,
      message_interval: 120_000
    )
  end

  defp get_policy(:aol) do
    PipelinePolicy.new(
      name: :aol,
      max_connections: 5,
      max_retries: 3,
      batch_size: 5,
      batch_timeout: 3_000,
      allowed_messages: 30,
      message_interval: 180_000
    )
  end

  defp get_policy(:outlook) do
    PipelinePolicy.new(
      name: :outlook,
      max_connections: 12,
      max_retries: 4,
      batch_size: 8,
      batch_timeout: 4_000,
      allowed_messages: 80,
      message_interval: 90_000
    )
  end

  defp get_policy(:icloud) do
    PipelinePolicy.new(
      name: :icloud,
      max_connections: 3,
      max_retries: 2,
      batch_size: 3,
      batch_timeout: 2_000,
      allowed_messages: 20,
      message_interval: 300_000
    )
  end

  defp get_policy(:default) do
    PipelinePolicy.new(
      name: :default,
      max_connections: 5,
      max_retries: 3,
      batch_size: 5,
      batch_timeout: 5_000,
      allowed_messages: 50,
      message_interval: 5000
    )
  end
end
