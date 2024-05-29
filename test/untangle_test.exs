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
end
