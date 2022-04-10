defmodule Where do
  @moduledoc """
  Logging and debug printing that include location information
  """

  defp debug_label(caller) do
    file = Path.relative_to_cwd(caller.file)
    case caller.function do
      {fun, arity} -> "[#{file}:#{caller.line}@#{module_name(caller.module)}.#{fun}/#{arity}]"
      _ -> "[#{file}:#{caller.line}]"
    end
  end

  defp module_name(name) when is_atom(name), do: module_name(Atom.to_string(name))
  defp module_name(name) when is_binary(name), do: String.replace_prefix(name, "Elixir.", "")

  @doc "IO.inspect with position information, an optional label and configured not to truncate output."
  defmacro dump(thing, label \\ "") do
    pre = debug_label(__CALLER__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      unquote(thang) = unquote(thing)
      limit = :infinity
      IO.inspect(unquote(thang), label: "#{unquote(pre)} #{unquote(label)}", pretty: true, limit: limit, printable_limit: limit)
      unquote(thang)
    end
  end

  @doc "Like `dump`, but logging at debug level"
  defmacro debug(thing, label \\ "") do
    pre = debug_label(__CALLER__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      require Logger
      unquote(thang) = unquote(thing)
      Logger.debug("#{unquote(pre)} #{unquote(label)}: #{inspect(unquote(thang), pretty: true, printable_limit: :infinity)}")
      unquote(thang)
    end
  end

  @doc "Like `dump`, but logging at warn level"
  defmacro warn(thing, label \\ "") do
    pre = debug_label(__CALLER__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      require Logger
      unquote(thang) = unquote(thing)
      Logger.warn("#{unquote(pre)} #{unquote(label)}: #{inspect(unquote(thang), pretty: true, printable_limit: :infinity)}")
      unquote(thang)
    end
  end

  @doc "Like `dump`, but logging at error level"
  defmacro error(thing, label \\ "") do
    pre = debug_label(__CALLER__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      require Logger
      unquote(thang) = unquote(thing)
      Logger.error("#{unquote(pre)} #{unquote(label)}: #{inspect(unquote(thang), pretty: true, printable_limit: :infinity)}")
      unquote(thang)
    end
  end

  @doc "Like `debug`, but will do nothing unless the `:debug` option is truthy"
  defmacro debug?(thing, label \\ "", options) do
    pre = debug_label(__CALLER__)
    opts = Macro.var(:opts, __MODULE__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      require Logger
      unquote(opts) = unquote(options)
      unquote(thang) = unquote(thing)
      if unquote(opts)[:debug] do
        Logger.debug("#{unquote(pre)} #{unquote(label)}: #{inspect(unquote(thang), pretty: true, printable_limit: :infinity)}")
      end
      unquote(thang)
    end
  end

  @doc "Like `debug?`, but additionally required the `:verbose` option to be set. Intended for large output."
  defmacro verbose?(thing, label \\ "", options) do
    pre = debug_label(__CALLER__)
    opts = Macro.var(:opts, __MODULE__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      require Logger
      unquote(opts) = unquote(options)
      unquote(thang) = unquote(thing)
      if unquote(opts)[:debug] && unquote(opts)[:verbose] do
        Logger.debug("#{unquote(pre)} #{unquote(label)}: #{inspect(unquote(thang), pretty: true, printable_limit: :infinity)}")
      end
      unquote(thang)
    end
  end

  @doc """
  Tries to 'do what i mean'. Requires the `debug` option to be set regardless. If `verbose` is also
  set, will inspect else will attempt to print some (hopefully smaller) type-dependent summary of
  the data (list length, map keys).
  """
  defmacro smart(thing, label \\ "", options) do
    pre = debug_label(__CALLER__)
    opts = Macro.var(:opts, __MODULE__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      require Logger
      unquote(opts) = unquote(options)
      unquote(thang) = unquote(thing)
      cond do
        !unquote(opts)[:debug] -> nil
        unquote(opts)[:verbose] ->
          Logger.debug("#{unquote(pre)} #{unquote(label)}: #{inspect(unquote(thang), pretty: true, printable_limit: :infinity)}")
        is_list(unquote(thang)) ->
          Logger.debug("#{unquote(pre)} #{unquote(label)} (length): #{Enum.count(unquote(thang))}")
        is_struct(unquote(thang)) ->
          Logger.debug("#{unquote(pre)} #{unquote(label)}: %#{unquote(thang).__struct__}{}")
        is_map(unquote(thang)) and not is_struct(unquote(thang)) ->
          Logger.debug("#{unquote(pre)} #{unquote(label)} (keys): #{inspect(Map.keys(unquote(thang)))}")
        true ->
          Logger.debug("#{unquote(pre)} #{unquote(label)} (inspect elided, pass `:verbose` to see)")
      end
      unquote(thang)
    end
  end

end
