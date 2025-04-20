defmodule Untangle.Time do
  @moduledoc """
  Provides timing utilities for measuring function execution time.

  This module offers decorators for measuring and logging the execution time of functions:
  - `time()`: Basic measurement of single function calls
  - `time_process()`: Tracks count and total time across multiple calls
  - `time_tree()`: Captures timing across process trees
  """

  use Decorator.Define,
    time: 0,
    time_process: 0,
    time_tree: 0,
    time: 1,
    time_process: 1,
    time_tree: 1

  require Logger

  # Check at compile time if ProcessTree is available
  @disable? !Untangle.log_level?(:debug)
  @process_tree_available Code.ensure_loaded?(ProcessTree)

  @doc """
  Decorator that measures and logs execution time of functions.

  When applied to a function, this decorator will:
  - Measure the function's execution time if the logger level is set to `:debug` 
  - Log the execution time if it exceeds a configured threshold (default: 10,000 microseconds)
  - Return the function's result unchanged

  ## Configuration

  The minimum time threshold for logging can be configured in your application:

  ```elixir
  config :untangle, :time_slow_min, 10_000  # microseconds
  ```

  ## Examples

      defmodule Demo do
        use Untangle.Time
        
        @decorate time()
        def slow_function(ms) do
          Process.sleep(ms)
          :ok
        end
      end
  """
  def time(slow_ms \\ nil, fn_body, context) do
    # At compile time, check if we're in debug environment
    if @disable? do
      # Not in debug mode at compile time, just return original function
      quote do
        unquote(fn_body)
      end
    else
      # In debug mode or can't determine at compile time, include runtime check
      quote do
        if Untangle.log_level?(:debug) do
          start = :erlang.monotonic_time()
          result = unquote(fn_body)
          finish = :erlang.monotonic_time()

          time = :erlang.convert_time_unit(finish - start, :native, :microsecond)

          if time > (unquote(slow_ms) || Application.get_env(:untangle, :time_slow_min, 10_000)) do
            Logger.debug(
              "#{time / 1_000} ms to run #{unquote(context.module)}.#{unquote(context.name)}/#{unquote(context.arity)}"
            )
          end

          result
        else
          unquote(fn_body)
        end
      end
    end
  end

  @doc """
  Decorator that aggregates execution counts and times across multiple calls.

  When applied to a function, this decorator will:
  - Track each call in the process dictionary
  - Count the number of executions
  - Sum total execution time
  - Log detailed statistics when execution time exceeds threshold
  - Return the function's result unchanged

  ## Examples

      defmodule Demo do
        use Untangle.Time
        
        @decorate time_process()
        def repeated_function(ms) do
          Process.sleep(ms)
          :ok
        end
      end

  After multiple calls, logs will include call count and total time.
  """
  def time_process(slow_ms \\ nil, fn_body, context) do
    # At compile time, check if we're in debug environment
    if @disable? do
      # Not in debug mode at compile time, just return original function
      quote do
        unquote(fn_body)
      end
    else
      function_key = "#{context.module}.#{context.name}/#{context.arity}"

      quote do
        if Untangle.log_level?(:debug) do
          # Get current stats or initialize
          previous_data =
            Process.get({:untangle_time_process, unquote(Macro.escape(function_key))}, %{
              count: 0,
              time: 0
            })

          # Measure this execution
          start = :erlang.monotonic_time()
          result = unquote(fn_body)
          finish = :erlang.monotonic_time()

          time = :erlang.convert_time_unit(finish - start, :native, :microsecond)

          # Update accumulated data with this process's information
          current_data = %{
            count: previous_data.count + 1,
            time: previous_data.time + time
          }

          if time > (unquote(slow_ms) || Application.get_env(:untangle, :time_slow_min, 10_000)) do
            Logger.debug(
              "#{time / 1_000} ms to run #{unquote(Macro.escape(function_key))} " <>
                "(call ##{current_data.count}, total: #{current_data.time / 1_000} ms, avg: #{current_data.time / current_data.count / 1_000} ms)"
            )
          end

          # Store updated data
          Process.put({:untangle_time_process, unquote(Macro.escape(function_key))}, current_data)

          result
        else
          unquote(fn_body)
        end
      end
    end
  end

  @doc """
  Decorator that measures execution time across a process tree.

  When applied to a function, this decorator will:
  - Track execution time of the function in the current process and all processes it spawns
  - Log detailed timing statistics when execution completes
  - Return the function's result unchanged

  Requires the [ProcessTree](https://www.hex.pm/packages/process_tree) library to be added to your app's dependencies.

  ## Examples

      defmodule Demo do
        use Untangle.Time
        
        @decorate time_tree()
        def spawn_function(depth \\ 1) do
          Process.sleep(50) 
          if depth < 3 do
            Task.async(fn -> 
              Demo.spawn_function(depth + 1)
            end) 
            |> Task.await()
          end
          :ok
        end
      end
  """
  def time_tree(slow_ms \\ nil, fn_body, context) do
    # At compile time, check if we're in debug mode and ProcessTree is available
    cond do
      @disable? ->
        # Not in debug mode at compile time, just return original function
        quote do
          unquote(fn_body)
        end

      not @process_tree_available ->
        # ProcessTree not available at compile time, fall back to time_process
        time_process(fn_body, context)

      true ->
        # Both debug mode possible and ProcessTree available, include runtime check
        function_key = "#{context.module}.#{context.name}/#{context.arity}"

        quote do
          if Untangle.log_level?(:debug) do
            # Get accumulated time from parent processes, if any
            parent_data =
              ProcessTree.get({:untangle_time_tree, unquote(Macro.escape(function_key))},
                cache: false,
                default: %{count: 0, time: 0}
              )

            # TODO: at the moment this will only return the execution times from the current process or the first parent process that has recorded data, rather than the sum of the data from all parents

            # Execute function while tracking time
            start = :erlang.monotonic_time()
            result = unquote(fn_body)
            finish = :erlang.monotonic_time()

            # Calculate this process's execution time
            time = :erlang.convert_time_unit(finish - start, :native, :microsecond)

            # Update accumulated data with this process's information
            current_data = %{
              count: parent_data.count + 1,
              time: parent_data.time + time
            }

            # Log results including parent process data
            if time > (unquote(slow_ms) || Application.get_env(:untangle, :time_slow_min, 10_000)) do
              if parent_data.count > 0 do
                # Include parent process information if available
                Logger.debug(
                  "#{time / 1_000} ms to run #{unquote(Macro.escape(function_key))} " <>
                    "(#{current_data.count} executions in process tree, total time: #{current_data.time / 1_000} ms, avg: #{current_data.time / current_data.count / 1_000} ms)"
                )
              else
                # Just log this process's information
                Logger.debug("#{time / 1_000} ms to run #{unquote(Macro.escape(function_key))}")
              end
            end

            # Store this data in process dictionary for child processes
            Process.put({:untangle_time_tree, unquote(Macro.escape(function_key))}, current_data)

            result
          else
            unquote(fn_body)
          end
        end
    end
  end

  def disabled?, do: @disable?
end
