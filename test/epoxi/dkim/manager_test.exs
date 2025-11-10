defmodule Epoxi.DKIM.ManagerTest do
  use ExUnit.Case, async: false

  alias Epoxi.DKIM.{Manager, Registry}

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

  describe "create/1" do
    test "creates and registers a new DKIM config" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: "default",
        private_key: @valid_private_key
      }

      assert {:ok, config} = Manager.create(attrs)
      assert config.domain == "example.com"

      # Verify it's registered
      assert {:ok, _} = Registry.lookup("example.com")
    end

    test "returns error for invalid attributes" do
      attrs = %{
        tenant_id: "",
        domain: "example.com",
        selector: "default",
        private_key: @valid_private_key
      }

      assert {:error, :invalid_tenant_id} = Manager.create(attrs)
    end

    test "returns error when domain already exists" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: "default",
        private_key: @valid_private_key
      }

      assert {:ok, _} = Manager.create(attrs)
      assert {:error, :already_exists} = Manager.create(attrs)
    end
  end

  describe "update/2" do
    test "updates an existing config" do
      create_config("example.com")

      assert {:ok, updated} = Manager.update("example.com", %{selector: "new-selector"})
      assert updated.selector == "new-selector"
    end

    test "returns error for non-existent domain" do
      assert {:error, :not_found} = Manager.update("nonexistent.com", %{})
    end

    test "validates updated attributes" do
      create_config("example.com")

      assert {:error, :invalid_selector} = Manager.update("example.com", %{selector: ""})
    end
  end

  describe "get/1" do
    test "retrieves a config without exposing private key" do
      create_config("example.com")

      assert {:ok, config} = Manager.get("example.com")
      assert config.domain == "example.com"
      assert config.selector == "default"
      # Should not contain private key
      refute Map.has_key?(config, :private_key_encrypted)
    end

    test "returns error for non-existent domain" do
      assert {:error, :not_found} = Manager.get("nonexistent.com")
    end
  end

  describe "list/0" do
    test "lists all configs without exposing private keys" do
      create_config("example.com")
      create_config("another.com")

      configs = Manager.list()
      assert length(configs) == 2

      Enum.each(configs, fn config ->
        assert Map.has_key?(config, :domain)
        refute Map.has_key?(config, :private_key_encrypted)
      end)
    end
  end

  describe "list_by_tenant/1" do
    test "lists configs for a specific tenant" do
      create_config("example.com", tenant_id: "tenant1")
      create_config("another.com", tenant_id: "tenant1")
      create_config("other.com", tenant_id: "tenant2")

      assert {:ok, configs} = Manager.list_by_tenant("tenant1")
      assert length(configs) == 2
    end
  end

  describe "remove/1" do
    test "removes a config" do
      create_config("example.com")

      assert :ok = Manager.remove("example.com")
      assert {:error, :not_found} = Manager.get("example.com")
    end
  end

  # Helper functions

  defp create_config(domain, opts \\ []) do
    attrs = %{
      tenant_id: Keyword.get(opts, :tenant_id, "tenant1"),
      domain: domain,
      selector: "default",
      private_key: @valid_private_key
    }

    {:ok, _} = Manager.create(attrs)
  end
end
