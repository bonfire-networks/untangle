defmodule Untangle.PerfTest do
  @moduledoc """
  Logging must not be expensive enough to change how the system behaves.

  These come from a live incident: a node sat at a sustained load of 2 for a day because every
  logged stacktrace made one `File.cwd()` call per frame, and `File.cwd()` is a `GenServer.call` to
  the single global `:file_server_2`. Five websocket connections looping over an error were enough
  to serialise the whole VM behind one mailbox.
  """

  use ExUnit.Case, async: false

  require Untangle

  import ExUnit.CaptureLog
  import ExUnit.CaptureIO

  describe "format_stacktrace/1" do
    # The prod behaviour — a cwd cached in :persistent_term, so formatting makes no calls to the
    # global :file_server_2 — cannot be asserted from here: `cwd/0` is chosen by
    # `Application.compile_env(:untangle, :env)`, and dev/test deliberately keep looking it up
    # because Mix.Project.in_project/4 moves the working directory while compiling deps.
    # What is checkable is that both branches answer correctly, and that a stacktrace still formats.
    test "resolves paths against the working directory" do
      assert Untangle.cwd() == File.cwd!()
    end

    test "still resolves paths to something readable" do
      stack = Process.info(self(), :current_stacktrace) |> elem(1) |> Enum.take(3)

      formatted = Untangle.format_stacktrace(stack)

      assert formatted =~ "Untangle.PerfTest"
      refute formatted =~ "/Users/"
    end
  end

  describe "inspect limits" do
    setup do
      previous_truncate = Application.get_env(:logger, :truncate)
      previous_console = Application.get_env(:logger, :console)

      # log_truncate_limit/1 consults :console first, so clear it to test the general setting
      Application.put_env(:logger, :console, Keyword.delete(previous_console || [], :truncate))

      on_exit(fn ->
        Application.put_env(:logger, :truncate, previous_truncate)
        Application.put_env(:logger, :console, previous_console)
      end)

      :ok
    end

    test "follow the configured Logger truncate rather than a constant" do
      # rendering more than Logger will emit is waste, but dev deliberately raises this, so the
      # ceiling has to track configuration instead of being pinned to a number
      Application.put_env(:logger, :truncate, 512)
      assert Untangle.log_truncate_limit() == 512

      Application.put_env(:logger, :truncate, 65_536)
      assert Untangle.log_truncate_limit() == 65_536
    end

    test "are unbounded when truncation is disabled" do
      Application.put_env(:logger, :truncate, :infinity)
      assert Untangle.log_truncate_limit() == :infinity
    end
  end

  describe "log_or_flood/2" do
    setup do
      previous = Application.get_env(:untangle, :to_io, false)
      Application.put_env(:untangle, :to_io, true)
      on_exit(fn -> Application.put_env(:untangle, :to_io, previous) end)
      :ok
    end

    test "a failing write does not escape into the caller" do
      # IO.puts/1 raises on a list that is not chardata; logging must not break what it logs about
      capture_io(:stderr, fn ->
        assert Untangle.log_or_flood(:error, [:not_chardata]) == :ok
      end)
    end

    test "a failing write is reported once, without re-entering" do
      stderr = capture_io(:stderr, fn -> Untangle.log_or_flood(:error, [:not_chardata]) end)

      # exactly one fallback line: retrying through the same path would recurse until the
      # process died, since inspect/1 of a binary is still a binary
      assert length(String.split(stderr, "untangle", trim: true)) == 2
    end
  end
end
