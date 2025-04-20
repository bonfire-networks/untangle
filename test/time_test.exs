defmodule Untangle.TimeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  require Logger

  # Define a module that uses the time decorators for testing
  defmodule TestModule do
    use Untangle.Time

    @decorate time()
    def fast_function do
      :timer.sleep(5)
      :fast_result
    end

    @decorate time()
    def slow_function do
      :timer.sleep(30)
      :slow_result
    end

    @decorate time_process()
    def repeated_function(sleep_time \\ 10) do
      :timer.sleep(sleep_time)
      :repeated_result
    end

    @decorate time_tree()
    def child_function(sleep_time) do
      :timer.sleep(sleep_time)
      :child_result
    end

    @decorate time_tree()
    def parent_function(sleep_time \\ 10) do
      child_function(sleep_time)

      task =
        Task.async(fn ->
          child_function(sleep_time)
        end)

      Task.await(task)
      :parent_result
    end

    @decorate time_tree()
    def grandparent_function(sleep_time \\ 10) do
      child_function(sleep_time)

      task =
        Task.async(fn ->
          parent_function(sleep_time)
        end)

      Task.await(task)
      :grandparent_result
    end
  end

  describe "time decorator" do
    setup do
      # Store original log level
      original_level = Logger.level()
      # Set log level to debug for the tests
      Logger.configure(level: :debug)

      # Store original threshold setting
      original_threshold = Application.get_env(:untangle, :time_slow_min, 10_000)

      on_exit(fn ->
        # Restore original settings after tests
        Logger.configure(level: original_level)
        Application.put_env(:untangle, :time_slow_min, original_threshold)
      end)

      # Use a lower threshold for testing
      Application.put_env(:untangle, :time_slow_min, 20)

      :ok
    end

    test "doesn't log execution time of fast functions" do
      log =
        capture_log(fn ->
          assert :fast_result = TestModule.fast_function()
        end)

      refute log =~ "ms to run Untangle.TimeTest.TestModule.fast_function/0"
    end

    test "logs execution time of slow functions" do
      log =
        capture_log(fn ->
          assert :slow_result = TestModule.slow_function()
        end)

      assert log =~ "ms to run Elixir.Untangle.TimeTest.TestModule.slow_function/0"
    end
  end

  describe "time_process decorator" do
    setup do
      original_level = Logger.level()
      Logger.configure(level: :debug)
      original_threshold = Application.get_env(:untangle, :time_slow_min, 10_000)

      on_exit(fn ->
        Logger.configure(level: original_level)
        Application.put_env(:untangle, :time_slow_min, original_threshold)
      end)

      # Use a lower threshold for testing
      Application.put_env(:untangle, :time_slow_min, 5)

      :ok
    end

    test "logs execution time with call count" do
      log =
        capture_log(fn ->
          TestModule.repeated_function(30)
        end)

      assert log =~ "ms to run"
      assert log =~ "call #1, total:"
    end

    test "accumulates execution count across multiple calls" do
      log =
        capture_log(fn ->
          TestModule.repeated_function(10)
          TestModule.repeated_function(10)
          TestModule.repeated_function(30)
        end)

      assert log =~ "call #3, total:"
      assert log =~ "avg:"
    end

    test "function returns its original result" do
      capture_log(fn ->
        assert :repeated_result = TestModule.repeated_function()
      end)
    end

    test "doesn't measure time when log level is not debug" do
      Logger.configure(level: :info)

      log =
        capture_log(fn ->
          TestModule.repeated_function(30)
        end)

      refute log =~ "ms to run"
    end
  end

  describe "time_tree decorator" do
    setup do
      original_level = Logger.level()
      Logger.configure(level: :debug)
      original_threshold = Application.get_env(:untangle, :time_slow_min, 10_000)

      on_exit(fn ->
        Logger.configure(level: original_level)
        Application.put_env(:untangle, :time_slow_min, original_threshold)
      end)

      # Use a lower threshold for testing
      Application.put_env(:untangle, :time_slow_min, 5)

      :ok
    end

    test "logs execution time of parent+child function with accumulated data" do
      time = 30

      log =
        capture_log(fn ->
          TestModule.parent_function(time)
        end)

      assert log =~ "ms to run Elixir.Untangle.TimeTest.TestModule.child_function/1"
      assert log =~ "executions in process tree"

      # Extract the total time from the log
      total_time_pattern = ~r/total time: (\d+\.\d+) ms/
      assert [_, total_time_str] = Regex.run(total_time_pattern, log)
      total_time = String.to_float(total_time_str)

      # Check that the total time is at least the expected minimum
      # (should be at least 2*time since we call child_function twice)
      assert total_time > time * 1.9
      assert total_time < time * 2.5
    end

    #  need to find a way to sum all results from the process tree 
    @tag :todo
    test "logs execution time of grandparent+parent+child function with accumulated data" do
      time = 30

      log =
        capture_log(fn ->
          TestModule.parent_function(time)
        end)

      assert log =~ "ms to run Elixir.Untangle.TimeTest.TestModule.child_function/1"
      assert log =~ "executions in process tree"

      # Extract the total time from the log
      total_time_pattern = ~r/total time: (\d+\.\d+) ms/
      assert [_, total_time_str] = Regex.run(total_time_pattern, log)
      total_time = String.to_float(total_time_str)

      # Check that the total time is at least the expected minimum
      # (should be at least 2*time since we call child_function twice)
      assert total_time > time * 2.9
      assert total_time < time * 3.5
    end

    test "function returns its original result" do
      capture_log(fn ->
        assert :parent_result = TestModule.parent_function()
      end)
    end

    @tag :todo
    # Test that falls back to basic timing if ProcessTree not available
    test "falls back to basic timing if ProcessTree not available" do
      # This test only works if we can simulate ProcessTree being unavailable
      # Skip if we can't do that for this test environment
      if Code.ensure_loaded?(ProcessTree) do
        # TODO: use a mocking library to simulate ProcessTree being unavailable
        :skip
      else
        log =
          capture_log(fn ->
            TestModule.parent_function(30)
          end)

        assert log =~ "ProcessTree library not available"
        assert log =~ "ms to run Elixir.Untangle.TimeTest.TestModule.parent_function/1"
      end
    end
  end
end
