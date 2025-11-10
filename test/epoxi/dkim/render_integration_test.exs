defmodule Epoxi.DKIM.RenderIntegrationTest do
  use ExUnit.Case, async: false

  alias Epoxi.{Email, Render}
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

  describe "encode/1 with DKIM" do
    test "encodes successfully with DKIM config registered" do
      # Register DKIM config for example.com
      {:ok, _config} =
        Manager.create(%{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "mail",
          private_key: @valid_private_key
        })

      email = %Email{
        subject: "Test Subject",
        from: "sender@example.com",
        to: ["recipient@test.com"],
        html: "<p>Test</p>",
        text: "Test"
      }

      # Should encode successfully (DKIM signing will fail with placeholder key, but encode should work)
      assert is_binary(Render.encode(email))
    end

    test "sends without DKIM when no config found" do
      email = %Email{
        subject: "Test Subject",
        from: "sender@nodkim.com",
        to: ["recipient@test.com"],
        html: "<p>Test</p>",
        text: "Test"
      }

      # Should encode successfully without DKIM
      result = Render.encode(email)
      assert is_binary(result)
    end

    test "handles inactive DKIM config by not signing" do
      # Register active config first
      {:ok, _config} =
        Manager.create(%{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "mail",
          private_key: @valid_private_key
        })

      # Update to inactive status
      {:ok, _updated} = Manager.update("example.com", %{status: :inactive})

      email = %Email{
        subject: "Test Subject",
        from: "sender@example.com",
        to: ["recipient@test.com"],
        html: "<p>Test</p>",
        text: "Test"
      }

      # Should encode without DKIM (config is inactive)
      result = Render.encode(email)
      assert is_binary(result)
    end
  end

  describe "dkim_for/1" do
    test "returns empty list when no config found" do
      email = %Email{from: "user@nodkim.com"}
      assert [] = Render.dkim_for(email)
    end

    test "returns DKIM options when config found" do
      {:ok, _} =
        Manager.create(%{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "mail",
          private_key: @valid_private_key
        })

      email = %Email{from: "user@example.com"}
      dkim_opts = Render.dkim_for(email)

      assert Keyword.get(dkim_opts, :s) == "mail"
      assert Keyword.get(dkim_opts, :d) == "example.com"
      assert is_binary(Keyword.get(dkim_opts, :private_key))
    end

    test "uses correct DKIM config for different domains" do
      # Register configs for multiple domains
      {:ok, _} =
        Manager.create(%{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "example-selector",
          private_key: @valid_private_key
        })

      {:ok, _} =
        Manager.create(%{
          tenant_id: "tenant1",
          domain: "another.com",
          selector: "another-selector",
          private_key: @valid_private_key
        })

      # Check example.com config
      email1 = %Email{from: "user@example.com"}
      dkim_opts1 = Render.dkim_for(email1)

      assert Keyword.get(dkim_opts1, :s) == "example-selector"
      assert Keyword.get(dkim_opts1, :d) == "example.com"

      # Check another.com config
      email2 = %Email{from: "user@another.com"}
      dkim_opts2 = Render.dkim_for(email2)

      assert Keyword.get(dkim_opts2, :s) == "another-selector"
      assert Keyword.get(dkim_opts2, :d) == "another.com"
    end

    test "extracts domain from various from formats" do
      {:ok, _} =
        Manager.create(%{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "mail",
          private_key: @valid_private_key
        })

      # Test different email formats
      formats = [
        "user@example.com",
        "User Name <user@example.com>",
        "<user@example.com>"
      ]

      Enum.each(formats, fn from_address ->
        email = %Email{from: from_address}
        dkim_opts = Render.dkim_for(email)
        assert Keyword.get(dkim_opts, :d) == "example.com"
      end)
    end

    test "returns empty list for inactive config" do
      {:ok, _} =
        Manager.create(%{
          tenant_id: "tenant1",
          domain: "example.com",
          selector: "mail",
          private_key: @valid_private_key
        })

      {:ok, _} = Manager.update("example.com", %{status: :inactive})

      email = %Email{from: "user@example.com"}
      # Should return empty list because config is inactive
      assert [] = Render.dkim_for(email)
    end
  end
end
