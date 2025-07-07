defmodule Epoxi.Queue.PipelinePolicyTest do
  use ExUnit.Case, async: true

  alias Epoxi.Queue.PipelinePolicy

  describe "new/1" do
    test "creates policy with default values" do
      policy = PipelinePolicy.new()

      assert policy.name == :default
      assert policy.max_connections == 10
      assert policy.max_retries == 5
      assert policy.batch_size == 10
      assert policy.batch_timeout == 5_000
      assert policy.allowed_messages == 100
      assert policy.message_interval == 60_000
    end

    test "creates policy with custom options" do
      opts = [
        name: :test_pipeline,
        max_connections: 20,
        max_retries: 3,
        batch_size: 50,
        batch_timeout: 2_000
      ]

      policy = PipelinePolicy.new(opts)

      assert policy.name == :test_pipeline
      assert policy.max_connections == 20
      assert policy.max_retries == 3
      assert policy.batch_size == 50
      assert policy.batch_timeout == 2_000
      # Unspecified values use defaults
      assert policy.allowed_messages == 100
      assert policy.message_interval == 60_000
    end

    test "ignores unknown options" do
      policy = PipelinePolicy.new(unknown_option: :value)

      assert policy.name == :default
      refute Map.has_key?(policy, :unknown_option)
    end
  end

  describe "broadway_opts/1" do
    test "returns complete Broadway configuration" do
      policy = PipelinePolicy.new(name: :test_queue)
      opts = PipelinePolicy.broadway_opts(policy)

      assert opts[:name] == :test_queue
      assert is_list(opts[:producer])
      assert is_list(opts[:processors])
      assert is_list(opts[:batchers])
    end

    test "producer configuration" do
      policy = PipelinePolicy.new(batch_timeout: 5_000, max_retries: 3)
      opts = PipelinePolicy.broadway_opts(policy)
      producer = opts[:producer]

      assert producer[:concurrency] == 1
      assert {Epoxi.Queue.Producer, producer_opts} = producer[:module]
      assert producer_opts[:poll_interval] == 5_000
      assert producer_opts[:max_retries] == 3
    end

    test "processor configuration" do
      policy = PipelinePolicy.new()
      opts = PipelinePolicy.broadway_opts(policy)
      processors = opts[:processors]

      assert processors[:default][:concurrency] == 2
    end

    test "batcher configuration" do
      policy =
        PipelinePolicy.new(
          batch_size: 50,
          batch_timeout: 2_000,
          max_connections: 8
        )

      opts = PipelinePolicy.broadway_opts(policy)
      batchers = opts[:batchers]

      # Pending batcher uses original values
      pending = batchers[:pending]
      assert pending[:batch_size] == 50
      assert pending[:batch_timeout] == 2_000
      assert pending[:concurrency] == 8

      # Retrying batcher uses calculated values
      retrying = batchers[:retrying]
      # max(5, div(50, 4))
      assert retrying[:batch_size] == 12
      # max(30_000, 2_000 * 2)
      assert retrying[:batch_timeout] == 30_000
      # max(2, div(8, 5))
      assert retrying[:concurrency] == 2
    end
  end

  describe "retry calculations" do
    test "retry_batch_size calculation" do
      # Normal case
      policy = PipelinePolicy.new(batch_size: 100)
      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]
      # div(100, 4)
      assert retrying[:batch_size] == 25

      # Minimum threshold
      policy = PipelinePolicy.new(batch_size: 12)
      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]
      # max(5, div(12, 4))
      assert retrying[:batch_size] == 5

      # Edge case: very small batch size
      policy = PipelinePolicy.new(batch_size: 1)
      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]
      # max(5, div(1, 4))
      assert retrying[:batch_size] == 5
    end

    test "retry_batch_timeout calculation" do
      # Normal case
      policy = PipelinePolicy.new(batch_timeout: 20_000)
      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]
      # 20_000 * 2
      assert retrying[:batch_timeout] == 40_000

      # Minimum threshold
      policy = PipelinePolicy.new(batch_timeout: 10_000)
      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]
      # max(30_000, 10_000 * 2)
      assert retrying[:batch_timeout] == 30_000

      # Edge case: very small timeout
      policy = PipelinePolicy.new(batch_timeout: 100)
      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]
      # max(30_000, 100 * 2)
      assert retrying[:batch_timeout] == 30_000
    end

    test "retry_max_connections calculation" do
      # Normal case
      policy = PipelinePolicy.new(max_connections: 15)
      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]
      # div(15, 5)
      assert retrying[:concurrency] == 3

      # Minimum threshold
      policy = PipelinePolicy.new(max_connections: 8)
      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]
      # max(2, div(8, 5))
      assert retrying[:concurrency] == 2

      # Edge case: very small connection count
      policy = PipelinePolicy.new(max_connections: 1)
      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]
      # max(2, div(1, 5))
      assert retrying[:concurrency] == 2
    end
  end

  describe "edge cases" do
    test "handles zero values gracefully" do
      policy =
        PipelinePolicy.new(
          batch_size: 0,
          batch_timeout: 0,
          max_connections: 0
        )

      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]

      # minimum enforced
      assert retrying[:batch_size] == 5
      # minimum enforced
      assert retrying[:batch_timeout] == 30_000
      # minimum enforced
      assert retrying[:concurrency] == 2
    end

    test "handles large values" do
      policy =
        PipelinePolicy.new(
          batch_size: 10_000,
          batch_timeout: 120_000,
          max_connections: 100
        )

      opts = PipelinePolicy.broadway_opts(policy)
      retrying = opts[:batchers][:retrying]

      # div(10_000, 4)
      assert retrying[:batch_size] == 2_500
      # 120_000 * 2
      assert retrying[:batch_timeout] == 240_000
      # div(100, 5)
      assert retrying[:concurrency] == 20
    end
  end
end
