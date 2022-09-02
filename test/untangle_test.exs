defmodule UntangleTest do
  use ExUnit.Case
  import Untangle

  doctest Untangle

  def value(), do: :a_value

  @tag capture_log: false
  test "untangles" do
    Logger.configure(level: :debug)

    dump(value())
    dump(value(), "testing dump")

    debug(value())
    debug(value(), "testing debug")

    info(value())
    info(value(), "testing info")

    warn(value())
    warn(value(), "testing warn")

    error(value())
    error(value(), "testing error")
    error({:error, value()})
    error({:error, value()}, "test error")

    maybe_dbg(value(), "do not debug", [])
    maybe_dbg(value(), "optionally debug", debug: true)

    maybe_info(value(), "not verbose", [])
    maybe_info(value(), "verbose", verbose: true)

    smart(value(), "no smart debugging", [])

    dbg(:dbg_value)

    Logger.configure(level: :info)
  end
end
