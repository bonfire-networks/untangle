defmodule Untangle.Time do
  use Decorator.Define, time: 0
  require Logger

  # skip the measuring depending on env

  def time(fn_body, context) do
    quote do
      start = :erlang.monotonic_time()
      result = unquote(fn_body)
      finish = :erlang.monotonic_time()

      time = :erlang.convert_time_unit(finish - start, :native, :millisecond)

      Logger.info(
        "Time to run #{unquote(context.module)}.#{unquote(context.name)}/#{unquote(context.arity)}: #{time} ms"
      )

      result
    end
  end
end
