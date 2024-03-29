defmodule Untangle.Time do
  use Decorator.Define, time: 0
  require Logger

  def time(fn_body, context) do
    quote do
      if Untangle.log_level?(:debug) do
        # skip the measuring depending on log level
        start = :erlang.monotonic_time()
        result = unquote(fn_body)
        finish = :erlang.monotonic_time()

        time = :erlang.convert_time_unit(finish - start, :native, :microsecond)

        Logger.debug(
          "Time to run #{unquote(context.module)}.#{unquote(context.name)}/#{unquote(context.arity)}: #{time / 1_000} ms"
        )

        result
      else
        unquote(fn_body)
      end
    end
  end
end
