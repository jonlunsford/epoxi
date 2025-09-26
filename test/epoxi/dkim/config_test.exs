defmodule Epoxi.DKIM.ConfigTest do
  use ExUnit.Case, async: true

  alias Epoxi.DKIM.Config

  @valid_private_key """
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpAIBAAKCAQEA1234567890abcdef...
  -----END RSA PRIVATE KEY-----
  """

  describe "new/1" do
    test "creates a valid DKIM config with required fields" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: "default",
        private_key: @valid_private_key
      }

      assert {:ok, %Config{} = config} = Config.new(attrs)
      assert config.tenant_id == "tenant1"
      assert config.domain == "example.com"
      assert config.selector == "default"
      # default
      assert config.algorithm == "rsa-sha256"
      # default
      assert config.canonicalization == "relaxed/relaxed"
      # default
      assert config.status == :active
      assert is_binary(config.private_key_encrypted)
      assert %DateTime{} = config.created_at
      assert %DateTime{} = config.updated_at
    end

    test "creates config with all optional fields" do
      now = DateTime.utc_now()

      attrs = %{
        tenant_id: "tenant2",
        domain: "test.org",
        selector: "custom",
        private_key: @valid_private_key,
        algorithm: "rsa-sha1",
        canonicalization: "simple/simple",
        status: :inactive,
        created_at: now,
        updated_at: now
      }

      assert {:ok, %Config{} = config} = Config.new(attrs)
      assert config.algorithm == "rsa-sha1"
      assert config.canonicalization == "simple/simple"
      assert config.status == :inactive
      assert config.created_at == now
      assert config.updated_at == now
    end

    test "normalizes domain to lowercase" do
      attrs = %{
        tenant_id: "tenant3",
        domain: "EXAMPLE.COM",
        selector: "default",
        private_key: @valid_private_key
      }

      assert {:ok, %Config{} = config} = Config.new(attrs)
      assert config.domain == "example.com"
    end

    test "trims private key whitespace" do
      key_with_whitespace = "  " <> @valid_private_key <> "  "

      attrs = %{
        tenant_id: "tenant4",
        domain: "example.com",
        selector: "default",
        private_key: key_with_whitespace
      }

      assert {:ok, %Config{} = config} = Config.new(attrs)
      # We can't directly check the trimmed key since it's encrypted,
      # but the creation should succeed
      assert is_binary(config.private_key_encrypted)
    end
  end

  describe "new/1 validation errors" do
    test "returns error for missing tenant_id" do
      attrs = %{domain: "example.com", selector: "default", private_key: @valid_private_key}
      assert {:error, :invalid_tenant_id} = Config.new(attrs)
    end

    test "returns error for empty tenant_id" do
      attrs = %{
        tenant_id: "",
        domain: "example.com",
        selector: "default",
        private_key: @valid_private_key
      }

      assert {:error, :invalid_tenant_id} = Config.new(attrs)
    end

    test "returns error for invalid tenant_id characters" do
      attrs = %{
        tenant_id: "tenant@invalid",
        domain: "example.com",
        selector: "default",
        private_key: @valid_private_key
      }

      assert {:error, :invalid_tenant_id} = Config.new(attrs)
    end

    test "returns error for missing domain" do
      attrs = %{tenant_id: "tenant1", selector: "default", private_key: @valid_private_key}
      assert {:error, :invalid_domain} = Config.new(attrs)
    end

    test "returns error for invalid domain format" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "invalid..domain",
        selector: "default",
        private_key: @valid_private_key
      }

      assert {:error, :invalid_domain} = Config.new(attrs)
    end

    test "returns error for missing selector" do
      attrs = %{tenant_id: "tenant1", domain: "example.com", private_key: @valid_private_key}
      assert {:error, :invalid_selector} = Config.new(attrs)
    end

    test "returns error for empty selector" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: "",
        private_key: @valid_private_key
      }

      assert {:error, :invalid_selector} = Config.new(attrs)
    end

    test "returns error for selector too long" do
      long_selector = String.duplicate("a", 64)

      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: long_selector,
        private_key: @valid_private_key
      }

      assert {:error, :invalid_selector} = Config.new(attrs)
    end

    test "returns error for selector with invalid characters" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: "invalid@selector",
        private_key: @valid_private_key
      }

      assert {:error, :invalid_selector} = Config.new(attrs)
    end

    test "returns error for missing private_key" do
      attrs = %{tenant_id: "tenant1", domain: "example.com", selector: "default"}
      assert {:error, :invalid_private_key} = Config.new(attrs)
    end

    test "returns error for invalid private_key format" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: "default",
        private_key: "invalid key"
      }

      assert {:error, :invalid_private_key} = Config.new(attrs)
    end

    test "returns error for invalid algorithm" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: "default",
        private_key: @valid_private_key,
        algorithm: "invalid-algorithm"
      }

      assert {:error, :invalid_algorithm} = Config.new(attrs)
    end

    test "returns error for invalid canonicalization" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: "default",
        private_key: @valid_private_key,
        canonicalization: "invalid/canonicalization"
      }

      assert {:error, :invalid_canonicalization} = Config.new(attrs)
    end

    test "returns error for invalid status" do
      attrs = %{
        tenant_id: "tenant1",
        domain: "example.com",
        selector: "default",
        private_key: @valid_private_key,
        status: :invalid
      }

      assert {:error, :invalid_status} = Config.new(attrs)
    end
  end

  describe "update/2" do
    setup do
      {:ok, config} =
        Config.new(%{
          tenant_id: "tenant1",
          domain: "original.com",
          selector: "original",
          private_key: @valid_private_key,
          algorithm: "rsa-sha256",
          canonicalization: "relaxed/relaxed",
          status: :active
        })

      %{config: config}
    end

    test "updates domain", %{config: config} do
      assert {:ok, updated} = Config.update(config, %{domain: "updated.com"})
      assert updated.domain == "updated.com"
      # Should not change
      assert updated.tenant_id == config.tenant_id
      assert updated.updated_at != config.updated_at
    end

    test "updates selector", %{config: config} do
      assert {:ok, updated} = Config.update(config, %{selector: "updated"})
      assert updated.selector == "updated"
    end

    test "updates algorithm", %{config: config} do
      assert {:ok, updated} = Config.update(config, %{algorithm: "rsa-sha1"})
      assert updated.algorithm == "rsa-sha1"
    end

    test "updates canonicalization", %{config: config} do
      assert {:ok, updated} = Config.update(config, %{canonicalization: "simple/simple"})
      assert updated.canonicalization == "simple/simple"
    end

    test "updates status", %{config: config} do
      assert {:ok, updated} = Config.update(config, %{status: :inactive})
      assert updated.status == :inactive
    end

    test "updates private key", %{config: config} do
      new_key = """
      -----BEGIN RSA PRIVATE KEY-----
      NewKeyContent123...
      -----END RSA PRIVATE KEY-----
      """

      assert {:ok, updated} = Config.update(config, %{private_key: new_key})
      assert updated.private_key_encrypted != config.private_key_encrypted
    end

    test "updates multiple fields", %{config: config} do
      updates = %{
        domain: "multi.com",
        selector: "multi",
        algorithm: "rsa-sha1",
        status: :inactive
      }

      assert {:ok, updated} = Config.update(config, updates)
      assert updated.domain == "multi.com"
      assert updated.selector == "multi"
      assert updated.algorithm == "rsa-sha1"
      assert updated.status == :inactive
    end

    test "returns error for invalid updates", %{config: config} do
      assert {:error, :invalid_domain} = Config.update(config, %{domain: "invalid..domain"})
      assert {:error, :invalid_selector} = Config.update(config, %{selector: ""})
      assert {:error, :invalid_algorithm} = Config.update(config, %{algorithm: "invalid"})
      assert {:error, :invalid_status} = Config.update(config, %{status: :invalid})
    end

    test "preserves original values when not updated", %{config: config} do
      assert {:ok, updated} = Config.update(config, %{domain: "new.com"})
      assert updated.selector == config.selector
      assert updated.algorithm == config.algorithm
      assert updated.canonicalization == config.canonicalization
      assert updated.status == config.status
    end
  end

  describe "decrypt_private_key/1" do
    test "returns error for unimplemented decryption" do
      {:ok, config} =
        Config.new(%{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "default",
          private_key: @valid_private_key
        })

      # Currently returns error since decryption is not implemented
      assert {:error, :decryption_not_implemented} = Config.decrypt_private_key(config)
    end
  end

  describe "algorithm validation" do
    test "accepts valid algorithms" do
      valid_algorithms = ["rsa-sha256", "rsa-sha1"]

      for algorithm <- valid_algorithms do
        attrs = %{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "default",
          private_key: @valid_private_key,
          algorithm: algorithm
        }

        assert {:ok, _} = Config.new(attrs), "Failed for algorithm: #{algorithm}"
      end
    end

    test "rejects invalid algorithms" do
      invalid_algorithms = ["sha256", "rsa", "md5", "sha1", "invalid"]

      for algorithm <- invalid_algorithms do
        attrs = %{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "default",
          private_key: @valid_private_key,
          algorithm: algorithm
        }

        assert {:error, :invalid_algorithm} = Config.new(attrs),
               "Should fail for algorithm: #{algorithm}"
      end
    end
  end

  describe "canonicalization validation" do
    test "accepts valid canonicalizations" do
      valid_canonicalizations = [
        "relaxed/relaxed",
        "relaxed/simple",
        "simple/relaxed",
        "simple/simple"
      ]

      for canonicalization <- valid_canonicalizations do
        attrs = %{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "default",
          private_key: @valid_private_key,
          canonicalization: canonicalization
        }

        assert {:ok, _} = Config.new(attrs), "Failed for canonicalization: #{canonicalization}"
      end
    end

    test "rejects invalid canonicalizations" do
      invalid_canonicalizations = [
        "relaxed",
        "simple",
        "relaxed/invalid",
        "invalid/simple",
        "strict/strict"
      ]

      for canonicalization <- invalid_canonicalizations do
        attrs = %{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "default",
          private_key: @valid_private_key,
          canonicalization: canonicalization
        }

        assert {:error, :invalid_canonicalization} = Config.new(attrs),
               "Should fail for canonicalization: #{canonicalization}"
      end
    end
  end

  describe "selector validation edge cases" do
    test "accepts valid selector formats" do
      valid_selectors = [
        "default",
        "selector1",
        "my-selector",
        "my_selector",
        "my.selector",
        "a",
        "123",
        "sel-123_test.domain"
      ]

      for selector <- valid_selectors do
        attrs = %{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: selector,
          private_key: @valid_private_key
        }

        assert {:ok, _} = Config.new(attrs), "Failed for selector: #{selector}"
      end
    end

    test "rejects invalid selector formats" do
      invalid_selectors = [
        "",
        # starts with hyphen
        "-selector",
        # ends with hyphen
        "selector-",
        # starts with dot
        ".selector",
        # ends with dot
        "selector.",
        # starts with underscore
        "_selector",
        # ends with underscore
        "selector_",
        # invalid character
        "sel@ector",
        # space
        "sel ector",
        # hash
        "sel#ector"
      ]

      for selector <- invalid_selectors do
        attrs = %{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: selector,
          private_key: @valid_private_key
        }

        assert {:error, :invalid_selector} = Config.new(attrs),
               "Should fail for selector: #{selector}"
      end
    end
  end
end
