defmodule Epoxi.DKIM.RegistryTest do
  use ExUnit.Case, async: false

  alias Epoxi.DKIM.{Config, Registry}

  @valid_private_key """
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpAIBAAKCAQEA0Z5V...
  -----END RSA PRIVATE KEY-----
  """

  setup do
    # Clear registry before each test
    Registry.clear()
    :ok
  end

  describe "register/1" do
    test "registers a DKIM config" do
      {:ok, config} = create_config("example.com")
      assert :ok = Registry.register(config)
    end

    test "prevents duplicate registration" do
      {:ok, config} = create_config("example.com")
      assert :ok = Registry.register(config)
      assert {:error, :already_exists} = Registry.register(config)
    end

    test "normalizes domain to lowercase" do
      {:ok, config} = create_config("EXAMPLE.COM")
      assert :ok = Registry.register(config)
      assert {:ok, _} = Registry.lookup("example.com")
    end
  end

  describe "lookup/1" do
    test "finds a registered config by domain" do
      {:ok, config} = create_config("example.com")
      Registry.register(config)

      assert {:ok, found} = Registry.lookup("example.com")
      assert found.domain == "example.com"
      assert found.selector == "default"
    end

    test "returns error for non-existent domain" do
      assert {:error, :not_found} = Registry.lookup("nonexistent.com")
    end

    test "only returns active configs" do
      {:ok, config} = create_config("example.com", status: :inactive)
      Registry.register(config)

      assert {:error, :not_found} = Registry.lookup("example.com")
    end

    test "lookup is case-insensitive" do
      {:ok, config} = create_config("example.com")
      Registry.register(config)

      assert {:ok, _} = Registry.lookup("EXAMPLE.COM")
      assert {:ok, _} = Registry.lookup("Example.Com")
    end
  end

  describe "lookup_by_tenant/1" do
    test "finds all configs for a tenant" do
      {:ok, config1} = create_config("example.com", tenant_id: "tenant1")
      {:ok, config2} = create_config("another.com", tenant_id: "tenant1")
      {:ok, config3} = create_config("other.com", tenant_id: "tenant2")

      Registry.register(config1)
      Registry.register(config2)
      Registry.register(config3)

      assert {:ok, configs} = Registry.lookup_by_tenant("tenant1")
      assert length(configs) == 2
      domains = Enum.map(configs, & &1.domain) |> Enum.sort()
      assert domains == ["another.com", "example.com"]
    end

    test "returns empty list for tenant with no configs" do
      assert {:ok, []} = Registry.lookup_by_tenant("nonexistent")
    end
  end

  describe "update/1" do
    test "updates an existing config" do
      {:ok, config} = create_config("example.com")
      Registry.register(config)

      {:ok, updated_config} = Config.update(config, %{selector: "new-selector"})
      assert :ok = Registry.update(updated_config)

      assert {:ok, found} = Registry.lookup("example.com")
      assert found.selector == "new-selector"
    end

    test "returns error when updating non-existent config" do
      {:ok, config} = create_config("example.com")
      assert {:error, :not_found} = Registry.update(config)
    end
  end

  describe "remove/1" do
    test "removes a config" do
      {:ok, config} = create_config("example.com")
      Registry.register(config)

      assert :ok = Registry.remove("example.com")
      assert {:error, :not_found} = Registry.lookup("example.com")
    end

    test "removing non-existent config is idempotent" do
      assert :ok = Registry.remove("nonexistent.com")
    end
  end

  describe "list/0" do
    test "lists all registered configs" do
      {:ok, config1} = create_config("example.com")
      {:ok, config2} = create_config("another.com")

      Registry.register(config1)
      Registry.register(config2)

      configs = Registry.list()
      assert length(configs) == 2
      domains = Enum.map(configs, & &1.domain) |> Enum.sort()
      assert domains == ["another.com", "example.com"]
    end

    test "returns empty list when no configs registered" do
      assert [] = Registry.list()
    end
  end

  describe "clear/0" do
    test "removes all configs" do
      {:ok, config1} = create_config("example.com")
      {:ok, config2} = create_config("another.com")

      Registry.register(config1)
      Registry.register(config2)

      assert :ok = Registry.clear()
      assert [] = Registry.list()
    end
  end

  # Helper functions

  defp create_config(domain, opts \\ []) do
    attrs = %{
      tenant_id: Keyword.get(opts, :tenant_id, "tenant1"),
      domain: domain,
      selector: Keyword.get(opts, :selector, "default"),
      private_key: @valid_private_key,
      status: Keyword.get(opts, :status, :active)
    }

    Config.new(attrs)
  end
end
