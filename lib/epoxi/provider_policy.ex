defmodule Epoxi.ProviderPolicy do
  @moduledoc """
  Defines provider-specific delivery policies for different email providers.
  """

  @type policy :: %{
          max_messages_per_minute: non_neg_integer(),
          max_connections: non_neg_integer(),
          batch_size: non_neg_integer(),
          batch_timeout: non_neg_integer()
        }

  @doc """
  Get the delivery policy for a specific domain.
  """
  @spec get_policy(String.t()) :: policy()
  def get_policy(domain) do
    case normalize_domain(domain) do
      "gmail.com" -> gmail_policy()
      "yahoo.com" -> yahoo_policy()
      "outlook.com" -> outlook_policy()
      "hotmail.com" -> outlook_policy()
      "live.com" -> outlook_policy()
      _ -> default_policy()
    end
  end

  @doc """
  Get batch configuration for a specific domain.
  """
  @spec get_batch_config(String.t()) :: Keyword.t()
  def get_batch_config(domain) do
    policy = get_policy(domain)
    [
      batch_size: policy.batch_size,
      batch_timeout: policy.batch_timeout
    ]
  end

  # Provider-specific policies
  
  defp gmail_policy do
    %{
      max_messages_per_minute: 1000,
      max_connections: 10,
      batch_size: 10,
      batch_timeout: 6_000
    }
  end

  defp yahoo_policy do
    %{
      max_messages_per_minute: 500,
      max_connections: 5,
      batch_size: 5,
      batch_timeout: 10_000
    }
  end

  defp outlook_policy do
    %{
      max_messages_per_minute: 750,
      max_connections: 8,
      batch_size: 8,
      batch_timeout: 8_000
    }
  end

  defp default_policy do
    %{
      max_messages_per_minute: 100,
      max_connections: 2,
      batch_size: 50,
      batch_timeout: 5_000
    }
  end

  # Helper functions

  defp normalize_domain(domain) do
    domain
    |> String.downcase()
    |> String.trim()
  end
end