defmodule Epoxi.TenantTest do
  use ExUnit.Case, async: true

  alias Epoxi.Tenant

  describe "new/1" do
    test "creates a valid tenant with required fields" do
      attrs = %{
        id: "tenant1",
        name: "Test Tenant",
        domains: ["example.com"]
      }

      assert {:ok, %Tenant{} = tenant} = Tenant.new(attrs)
      assert tenant.id == "tenant1"
      assert tenant.name == "Test Tenant"
      assert tenant.domains == ["example.com"]
      assert tenant.status == :active
      assert tenant.metadata == %{}
      assert %DateTime{} = tenant.created_at
      assert %DateTime{} = tenant.updated_at
    end

    test "creates tenant with all optional fields" do
      now = DateTime.utc_now()

      attrs = %{
        id: "tenant2",
        name: "Full Tenant",
        domains: ["example.com", "test.org"],
        status: :inactive,
        metadata: %{"key" => "value"},
        created_at: now,
        updated_at: now
      }

      assert {:ok, %Tenant{} = tenant} = Tenant.new(attrs)
      assert tenant.status == :inactive
      assert tenant.metadata == %{"key" => "value"}
      assert tenant.created_at == now
      assert tenant.updated_at == now
    end

    test "normalizes domain names to lowercase" do
      attrs = %{
        id: "tenant3",
        name: "Case Test",
        domains: ["EXAMPLE.COM", "Test.ORG"]
      }

      assert {:ok, %Tenant{} = tenant} = Tenant.new(attrs)
      assert tenant.domains == ["example.com", "test.org"]
    end

    test "trims whitespace from name" do
      attrs = %{
        id: "tenant4",
        name: "  Trimmed Name  ",
        domains: ["example.com"]
      }

      assert {:ok, %Tenant{} = tenant} = Tenant.new(attrs)
      assert tenant.name == "Trimmed Name"
    end
  end

  describe "new/1 validation errors" do
    test "returns error for missing id" do
      attrs = %{name: "Test", domains: ["example.com"]}
      assert {:error, :invalid_id} = Tenant.new(attrs)
    end

    test "returns error for empty id" do
      attrs = %{id: "", name: "Test", domains: ["example.com"]}
      assert {:error, :invalid_id} = Tenant.new(attrs)
    end

    test "returns error for invalid id characters" do
      attrs = %{id: "tenant@invalid", name: "Test", domains: ["example.com"]}
      assert {:error, :invalid_id} = Tenant.new(attrs)
    end

    test "returns error for missing name" do
      attrs = %{id: "tenant1", domains: ["example.com"]}
      assert {:error, :invalid_name} = Tenant.new(attrs)
    end

    test "returns error for empty name" do
      attrs = %{id: "tenant1", name: "", domains: ["example.com"]}
      assert {:error, :invalid_name} = Tenant.new(attrs)
    end

    test "returns error for name too long" do
      long_name = String.duplicate("a", 256)
      attrs = %{id: "tenant1", name: long_name, domains: ["example.com"]}
      assert {:error, :invalid_name} = Tenant.new(attrs)
    end

    test "returns error for missing domains" do
      attrs = %{id: "tenant1", name: "Test"}
      assert {:error, :invalid_domains} = Tenant.new(attrs)
    end

    test "returns error for empty domains list" do
      attrs = %{id: "tenant1", name: "Test", domains: []}
      assert {:error, :invalid_domains} = Tenant.new(attrs)
    end

    test "returns error for invalid domain format" do
      attrs = %{id: "tenant1", name: "Test", domains: ["invalid..domain"]}
      assert {:error, :invalid_domains} = Tenant.new(attrs)
    end

    test "returns error for domain without TLD" do
      attrs = %{id: "tenant1", name: "Test", domains: ["localhost"]}
      assert {:error, :invalid_domains} = Tenant.new(attrs)
    end

    test "returns error for domain starting with hyphen" do
      attrs = %{id: "tenant1", name: "Test", domains: ["-example.com"]}
      assert {:error, :invalid_domains} = Tenant.new(attrs)
    end

    test "returns error for domain ending with hyphen" do
      attrs = %{id: "tenant1", name: "Test", domains: ["example-.com"]}
      assert {:error, :invalid_domains} = Tenant.new(attrs)
    end

    test "returns error for invalid status" do
      attrs = %{id: "tenant1", name: "Test", domains: ["example.com"], status: :invalid}
      assert {:error, :invalid_status} = Tenant.new(attrs)
    end

    test "returns error for non-map metadata" do
      attrs = %{id: "tenant1", name: "Test", domains: ["example.com"], metadata: "invalid"}
      assert {:error, :invalid_metadata} = Tenant.new(attrs)
    end
  end

  describe "update/2" do
    setup do
      {:ok, tenant} =
        Tenant.new(%{
          id: "tenant1",
          name: "Original Name",
          domains: ["original.com"],
          status: :active,
          metadata: %{"key" => "value"}
        })

      %{tenant: tenant}
    end

    test "updates name", %{tenant: tenant} do
      assert {:ok, updated} = Tenant.update(tenant, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
      # ID should not change
      assert updated.id == tenant.id
      assert updated.updated_at != tenant.updated_at
    end

    test "updates domains", %{tenant: tenant} do
      new_domains = ["new.com", "another.org"]
      assert {:ok, updated} = Tenant.update(tenant, %{domains: new_domains})
      assert updated.domains == new_domains
    end

    test "updates status", %{tenant: tenant} do
      assert {:ok, updated} = Tenant.update(tenant, %{status: :suspended})
      assert updated.status == :suspended
    end

    test "updates metadata", %{tenant: tenant} do
      new_metadata = %{"new_key" => "new_value"}
      assert {:ok, updated} = Tenant.update(tenant, %{metadata: new_metadata})
      assert updated.metadata == new_metadata
    end

    test "updates multiple fields", %{tenant: tenant} do
      updates = %{
        name: "Multi Update",
        status: :inactive,
        metadata: %{"multi" => "update"}
      }

      assert {:ok, updated} = Tenant.update(tenant, updates)
      assert updated.name == "Multi Update"
      assert updated.status == :inactive
      assert updated.metadata == %{"multi" => "update"}
    end

    test "returns error for invalid updates", %{tenant: tenant} do
      assert {:error, :invalid_name} = Tenant.update(tenant, %{name: ""})
      assert {:error, :invalid_domains} = Tenant.update(tenant, %{domains: []})
      assert {:error, :invalid_status} = Tenant.update(tenant, %{status: :invalid})
    end

    test "preserves original values when not updated", %{tenant: tenant} do
      assert {:ok, updated} = Tenant.update(tenant, %{name: "New Name"})
      assert updated.domains == tenant.domains
      assert updated.status == tenant.status
      assert updated.metadata == tenant.metadata
    end
  end

  describe "domain validation edge cases" do
    test "accepts valid domain formats" do
      valid_domains = [
        "example.com",
        "sub.example.com",
        "deep.sub.example.com",
        "test-domain.org",
        "123domain.net",
        "domain123.co.uk"
      ]

      for domain <- valid_domains do
        attrs = %{id: "test", name: "Test", domains: [domain]}
        assert {:ok, _} = Tenant.new(attrs), "Failed for domain: #{domain}"
      end
    end

    test "rejects invalid domain formats" do
      invalid_domains = [
        "",
        ".",
        ".com",
        "example.",
        "ex..ample.com",
        "-example.com",
        "example-.com",
        "example.com-",
        "example..com",
        # no TLD
        "localhost",
        # IP address
        "192.168.1.1"
      ]

      for domain <- invalid_domains do
        attrs = %{id: "test", name: "Test", domains: [domain]}
        assert {:error, :invalid_domains} = Tenant.new(attrs), "Should fail for domain: #{domain}"
      end
    end
  end
end
