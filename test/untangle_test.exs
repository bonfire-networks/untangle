defmodule Untangle.Test do
  use ExUnit.Case
  import Untangle

  doctest Untangle

  def value(), do: :a_value

  @tag capture_log: false
  test "untangles" do
    Logger.configure(level: :debug)

    dump(value())
    dump(value(), "testing dump with label")

    debug(value())
    debug(value(), "testing debug with label")

    info(value())
    info(value(), "testing info with label")

    warn(value())
    warn(value(), "testing warn with label")

    assert {:error, :a_value} = error(value())
    assert {:error, "testing error with label"} = error(value(), "testing error with label")
    assert {:error, :a_value} = error({:error, value()})

    assert {:error, "testing error tuple with label"} =
             error({:error, value()}, "testing error tuple with label")

    maybe_dbg(value(), "do not debug", [])
    maybe_dbg(value(), "optionally debug", debug: true)

    maybe_info(value(), "not verbose", [])
    maybe_info(value(), "verbose", verbose: true)

    smart(value(), "no smart debugging", [])

    dbg(:dbg_value)

    Logger.configure(level: :info)
  end

  describe "log_truncate_limit/1" do
    setup do
      prev_truncate = Application.get_env(:logger, :truncate)
      prev_console = Application.get_env(:logger, :console)

      on_exit(fn ->
        Application.put_env(:logger, :truncate, prev_truncate)
        Application.put_env(:logger, :console, prev_console)
      end)

      %{console: prev_console || []}
    end

    test "prefers the console handler's :truncate", %{console: console} do
      Application.put_env(:logger, :console, Keyword.put(console, :truncate, 500))
      Application.put_env(:logger, :truncate, 9999)
      assert log_truncate_limit() == 500
    end

    test "falls back to the top-level :logger :truncate", %{console: console} do
      Application.put_env(:logger, :console, Keyword.delete(console, :truncate))
      Application.put_env(:logger, :truncate, 1234)
      assert log_truncate_limit() == 1234
    end

    test "passes through :infinity", %{console: console} do
      Application.put_env(:logger, :console, Keyword.delete(console, :truncate))
      Application.put_env(:logger, :truncate, :infinity)
      assert log_truncate_limit() == :infinity
    end

    test "uses the default when unset", %{console: console} do
      Application.put_env(:logger, :console, Keyword.delete(console, :truncate))
      Application.delete_env(:logger, :truncate)
      assert log_truncate_limit(4242) == 4242
    end
  end

  describe "slice_to_log_limit/2" do
    setup do
      prev_truncate = Application.get_env(:logger, :truncate)
      prev_console = Application.get_env(:logger, :console)

      Application.put_env(:logger, :console, Keyword.delete(prev_console || [], :truncate))
      Application.put_env(:logger, :truncate, 1000)

      on_exit(fn ->
        Application.put_env(:logger, :truncate, prev_truncate)
        Application.put_env(:logger, :console, prev_console)
      end)

      :ok
    end

    test "slices an oversized string down to the limit" do
      assert String.length(slice_to_log_limit(String.duplicate("x", 5000))) == 1000
    end

    test "leaves short strings untouched" do
      assert slice_to_log_limit("short") == "short"
    end

    test "reserves room so the rest of the log line (e.g. a stacktrace) survives" do
      trace = String.duplicate("t", 700)
      sliced = slice_to_log_limit(String.duplicate("b", 5000), reserved: String.length(trace))

      assert String.length(sliced) == 300
      assert String.length(sliced) + String.length(trace) <= 1000
    end

    # the bug: a huge banner + the stacktrace after it overflows Logger's :truncate, so the trace
    # (the actionable tail) gets cut off. Slicing the banner keeps the whole line within budget.
    test "keeps banner + trace within budget where the raw concatenation would overflow" do
      banner = String.duplicate("b", 5000)
      trace = String.duplicate("t", 700)

      assert String.length(banner <> trace) > 1000

      assert String.length(slice_to_log_limit(banner, reserved: String.length(trace)) <> trace) <=
               1000
    end

    test "keeps a floor of the string's head even when reserved exceeds the limit" do
      # reserved (2000) > limit (1000): the banner still shows its first 200 chars
      assert String.length(slice_to_log_limit(String.duplicate("b", 5000), reserved: 2000)) == 200
    end

    test "does not slice when truncation is disabled" do
      Application.put_env(:logger, :truncate, :infinity)
      big = String.duplicate("x", 5000)
      assert slice_to_log_limit(big) == big
    end
  end
end
