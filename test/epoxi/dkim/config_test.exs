defmodule Epoxi.DKIM.ConfigTest do
  use ExUnit.Case, async: true

  alias Epoxi.DKIM.Config

  @valid_private_key """
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpAIBAAKCAQEA0Z5V...
  -----END RSA PRIVATE KEY-----
  """

  @valid_attrs %{
    tenant_id: "tenant1",
    domain: "example.com",
    selector: "default",
    private_key: @valid_private_key
  }

  describe "new/1" do
    test "creates a valid DKIM config with required fields" do
      assert {:ok, config} = Config.new(@valid_attrs)
      assert config.tenant_id == "tenant1"
      assert config.domain == "example.com"
      assert config.selector == "default"
      assert config.algorithm == "rsa-sha256"
      assert config.canonicalization == "relaxed/relaxed"
      assert config.status == :active
      assert is_binary(config.private_key_encrypted)
      assert config.private_key_encrypted != @valid_private_key
    end

    test "encrypts the private key" do
      assert {:ok, config} = Config.new(@valid_attrs)
      # Key should be encrypted, not stored in plaintext
      refute config.private_key_encrypted == @valid_private_key
      assert byte_size(config.private_key_encrypted) >= 32
    end

    test "sets default values for optional fields" do
      assert {:ok, config} = Config.new(@valid_attrs)
      assert config.algorithm == "rsa-sha256"
      assert config.canonicalization == "relaxed/relaxed"
      assert config.status == :active
    end

    test "accepts custom algorithm" do
      attrs = Map.put(@valid_attrs, :algorithm, "rsa-sha1")
      assert {:ok, config} = Config.new(attrs)
      assert config.algorithm == "rsa-sha1"
    end

    test "accepts custom canonicalization" do
      attrs = Map.put(@valid_attrs, :canonicalization, "simple/simple")
      assert {:ok, config} = Config.new(attrs)
      assert config.canonicalization == "simple/simple"
    end

    test "validates tenant_id" do
      attrs = Map.put(@valid_attrs, :tenant_id, "")
      assert {:error, :invalid_tenant_id} = Config.new(attrs)

      attrs = Map.put(@valid_attrs, :tenant_id, "invalid tenant!")
      assert {:error, :invalid_tenant_id} = Config.new(attrs)
    end

    test "validates domain" do
      attrs = Map.put(@valid_attrs, :domain, "invalid domain")
      assert {:error, :invalid_domain} = Config.new(attrs)

      attrs = Map.put(@valid_attrs, :domain, "192.168.1.1")
      assert {:error, :invalid_domain} = Config.new(attrs)

      attrs = Map.put(@valid_attrs, :domain, "nodot")
      assert {:error, :invalid_domain} = Config.new(attrs)
    end

    test "validates selector" do
      attrs = Map.put(@valid_attrs, :selector, "")
      assert {:error, :invalid_selector} = Config.new(attrs)

      attrs = Map.put(@valid_attrs, :selector, "invalid selector!")
      assert {:error, :invalid_selector} = Config.new(attrs)

      # Selector too long (>63 chars)
      long_selector = String.duplicate("a", 64)
      attrs = Map.put(@valid_attrs, :selector, long_selector)
      assert {:error, :invalid_selector} = Config.new(attrs)
    end

    test "validates private_key" do
      attrs = Map.put(@valid_attrs, :private_key, "not a valid key")
      assert {:error, :invalid_private_key} = Config.new(attrs)

      attrs = Map.put(@valid_attrs, :private_key, "")
      assert {:error, :invalid_private_key} = Config.new(attrs)
    end

    test "validates algorithm" do
      attrs = Map.put(@valid_attrs, :algorithm, "invalid")
      assert {:error, :invalid_algorithm} = Config.new(attrs)
    end

    test "validates canonicalization" do
      attrs = Map.put(@valid_attrs, :canonicalization, "invalid")
      assert {:error, :invalid_canonicalization} = Config.new(attrs)
    end

    test "normalizes domain to lowercase" do
      attrs = Map.put(@valid_attrs, :domain, "EXAMPLE.COM")
      assert {:ok, config} = Config.new(attrs)
      assert config.domain == "example.com"
    end
  end

  describe "update/2" do
    setup do
      {:ok, config} = Config.new(@valid_attrs)
      {:ok, config: config}
    end

    test "updates selector", %{config: config} do
      assert {:ok, updated} = Config.update(config, %{selector: "new-selector"})
      assert updated.selector == "new-selector"
      assert updated.domain == config.domain
      assert updated.updated_at != config.updated_at
    end

    test "updates private key and re-encrypts", %{config: config} do
      new_key = """
      -----BEGIN RSA PRIVATE KEY-----
      NewKeyData...
      -----END RSA PRIVATE KEY-----
      """

      assert {:ok, updated} = Config.update(config, %{private_key: new_key})
      refute updated.private_key_encrypted == config.private_key_encrypted
    end

    test "updates status", %{config: config} do
      assert {:ok, updated} = Config.update(config, %{status: :inactive})
      assert updated.status == :inactive
    end

    test "validates updated fields", %{config: config} do
      assert {:error, :invalid_selector} = Config.update(config, %{selector: ""})
      assert {:error, :invalid_domain} = Config.update(config, %{domain: "invalid domain"})
    end
  end

  describe "decrypt_private_key/1" do
    test "decrypts a previously encrypted key" do
      assert {:ok, config} = Config.new(@valid_attrs)
      assert {:ok, decrypted} = Config.decrypt_private_key(config)
      # Should get back the original key (trimmed)
      assert String.trim(decrypted) == String.trim(@valid_private_key)
    end

    test "fails with invalid encrypted data" do
      assert {:ok, config} = Config.new(@valid_attrs)
      # Corrupt the encrypted data
      corrupted_config = %{config | private_key_encrypted: "invalid"}
      assert {:error, :invalid_encrypted_data} = Config.decrypt_private_key(corrupted_config)
    end

    test "different tenants produce different encrypted keys" do
      attrs1 = Map.put(@valid_attrs, :tenant_id, "tenant1")
      attrs2 = Map.put(@valid_attrs, :tenant_id, "tenant2")

      assert {:ok, config1} = Config.new(attrs1)
      assert {:ok, config2} = Config.new(attrs2)

      # Same private key, different tenants = different encryption
      refute config1.private_key_encrypted == config2.private_key_encrypted

      # But both should decrypt to the same key
      assert {:ok, key1} = Config.decrypt_private_key(config1)
      assert {:ok, key2} = Config.decrypt_private_key(config2)
      assert String.trim(key1) == String.trim(key2)
    end
  end
end
