defmodule Epoxi.Email.BatchTest do
  use ExUnit.Case, async: true

  alias Epoxi.Email.Batch

  describe "new/1" do
    test "creates a new batch with default values" do
      batch = Batch.new()

      assert %Batch{
               emails: [],
               size: 50,
               target_domain: "",
               ip: "",
               ip_pool: ""
             } = batch
    end
  end

  describe "from_emails/1" do
    test "returns a list of batches, emails grouped by domain & ip" do
      # Create emails with different domains and IPs
      emails = [
        %Epoxi.Email{to: ["user1@example.com"], delivery: %{ip: "192.168.1.1"}},
        %Epoxi.Email{to: ["user2@example.com"], delivery: %{ip: "192.168.1.1"}},
        %Epoxi.Email{to: ["user3@example.com"], delivery: %{ip: "192.168.1.2"}},
        %Epoxi.Email{to: ["user1@gmail.com"], delivery: %{ip: "192.168.1.1"}},
        %Epoxi.Email{to: ["user2@gmail.com"], delivery: %{ip: "192.168.1.1"}}
      ]

      batches = Batch.from_emails(emails)

      # Should create 3 batches (example.com+192.168.1.1, example.com+192.168.1.2, gmail.com+192.168.1.1)
      assert length(batches) == 3

      # Find batches by domain and IP
      example_com_ip1 =
        Enum.find(batches, &(&1.target_domain == "example.com" && &1.ip == "192.168.1.1"))

      example_com_ip2 =
        Enum.find(batches, &(&1.target_domain == "example.com" && &1.ip == "192.168.1.2"))

      gmail_com_ip1 =
        Enum.find(batches, &(&1.target_domain == "gmail.com" && &1.ip == "192.168.1.1"))

      assert example_com_ip1 && length(example_com_ip1.emails) == 2
      assert example_com_ip2 && length(example_com_ip2.emails) == 1
      assert gmail_com_ip1 && length(gmail_com_ip1.emails) == 2
    end

    test "respects batch size when grouping emails" do
      # Create 5 emails for the same domain and IP
      emails =
        for i <- 1..5 do
          %Epoxi.Email{to: ["user#{i}@example.com"], delivery: %{ip: "192.168.1.1"}}
        end

      batches = Batch.from_emails(emails, size: 2)

      # Should create 3 batches (2 + 2 + 1)
      assert length(batches) == 3

      # All should have same domain and IP
      assert Enum.all?(batches, &(&1.target_domain == "example.com" && &1.ip == "192.168.1.1"))

      # Check batch sizes
      email_counts = Enum.map(batches, &length(&1.emails))
      assert email_counts == [2, 2, 1]
    end

    test "handles emails with multiple recipients" do
      emails = [
        %Epoxi.Email{
          to: ["user1@example.com", "user2@example.com"],
          delivery: %{ip: "192.168.1.1"}
        },
        %Epoxi.Email{to: ["user3@gmail.com"], delivery: %{ip: "192.168.1.1"}}
      ]

      batches = Batch.from_emails(emails)

      # Should create 2 batches based on the first recipient's domain
      assert length(batches) == 2

      example_batch = Enum.find(batches, &(&1.target_domain == "example.com"))
      gmail_batch = Enum.find(batches, &(&1.target_domain == "gmail.com"))

      assert example_batch && length(example_batch.emails) == 1
      assert gmail_batch && length(gmail_batch.emails) == 1
    end

    test "returns empty list for empty input" do
      assert Batch.from_emails([]) == []
    end

    test "handles emails without delivery info" do
      emails = [
        %Epoxi.Email{to: ["user1@example.com"], delivery: nil},
        %Epoxi.Email{to: ["user2@example.com"], delivery: %{ip: "192.168.1.1"}}
      ]

      batches = Batch.from_emails(emails)

      # Should create 2 batches - one with empty IP, one with IP
      assert length(batches) == 2

      no_ip_batch = Enum.find(batches, &(&1.ip == nil))
      with_ip_batch = Enum.find(batches, &(&1.ip == "192.168.1.1"))

      assert no_ip_batch && length(no_ip_batch.emails) == 1
      assert with_ip_batch && length(with_ip_batch.emails) == 1
    end
  end
end
