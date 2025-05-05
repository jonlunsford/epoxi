# test/epoxi/email_test.exs
defmodule Epoxi.EmailTest do
  use ExUnit.Case, async: true

  alias Epoxi.Email

  describe "put_content_type/1" do
    test "it handles html" do
      email =
        %Email{html: "foo"}
        |> Email.put_content_type()

      assert %{content_type: "text/html"} = email
    end

    test "it handles text" do
      email =
        %Email{text: "foo"}
        |> Email.put_content_type()

      assert %{content_type: "text/plain"} = email
    end

    test "it handles mixed" do
      email =
        %Email{text: "foo", html: "bar"}
        |> Email.put_content_type()

      assert %{content_type: "multipart/mixed"} = email
    end

    test "it defaults to text/html" do
      email =
        %Email{}
        |> Email.put_content_type()

      assert %{content_type: "text/html"} = email
    end
  end

  describe "time_to_retry?/1" do
    test "returns false when max retries have been reached" do
      email = %Email{retry_count: 5}

      refute Email.time_to_retry?(email)
    end

    test "returns false for failed status" do
      email = %Email{status: :failed}

      refute Email.time_to_retry?(email)
    end

    test "returns false for pending status" do
      email = %Email{status: :pending}

      refute Email.time_to_retry?(email)
    end

    test "returns true for retrying status with nil next_retry_at" do
      email = %Email{status: :retrying, next_retry_at: nil}

      assert Email.time_to_retry?(email)
    end

    test "returns true for retrying status with next_retry_at in the past" do
      # 1 minute ago
      past = DateTime.utc_now() |> DateTime.add(-60)
      email = %Email{status: :retrying, next_retry_at: past}

      assert Email.time_to_retry?(email)
    end

    test "returns false for retrying status with next_retry_at in the future" do
      # 1 minute in future
      future = DateTime.utc_now() |> DateTime.add(60)
      email = %Email{status: :retrying, next_retry_at: future}

      refute Email.time_to_retry?(email)
    end
  end

  describe "retrying?/1" do
    test "returns true for retrying status" do
      email = %Email{status: :retrying}

      assert Email.retrying?(email)
    end

    test "returns false for pending status" do
      email = %Email{status: :pending}

      refute Email.retrying?(email)
    end

    test "returns false for failed status" do
      email = %Email{status: :failed}

      refute Email.retrying?(email)
    end
  end
end
