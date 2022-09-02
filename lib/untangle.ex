defmodule Untangle do
  @moduledoc """
  Logging and debug printing that include location information
  """

  @doc "IO.inspect with position information, an optional label and configured not to truncate output too much."
  defmacro dump(thing, label \\ "") do
    pre = format_label(__CALLER__)
    quote do
      unquote(__MODULE__).__dbg__("#{unquote(pre)} #{unquote(label)}", unquote(thing))
    end
  end

  @doc "Like `dump`, but for logging at debug level"
  defmacro debug(thing, label \\ "") do
    pre = format_label(__CALLER__)
    quote do
      require Logger
      {formatted, result} = unquote(__MODULE__).__prepare_dbg__("#{unquote(pre)} #{unquote(label)}", unquote(thing), pretty: true, limit: 10000, printable_limit: 10000)
      Logger.debug(formatted)
      result
    end
  end

  @doc "Like `dump`, but for logging at info level"
  defmacro info(thing, label \\ "") do
    pre = format_label(__CALLER__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      require Logger
      {formatted, result} = unquote(__MODULE__).__prepare_dbg__("#{unquote(pre)} #{unquote(label)}", unquote(thing), pretty: true, limit: 10000, printable_limit: 10000)
      Logger.info(formatted)
      result
    end
  end

  @doc "Like `dump`, but for logging at warn level"
  defmacro warn(thing, label \\ "") do
    pre = format_label(__CALLER__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      require Logger
      {formatted, result} = unquote(__MODULE__).__prepare_dbg__("#{unquote(pre)} #{unquote(label)}", unquote(thing), pretty: true, limit: 10000, printable_limit: 10000)
      Logger.warn(formatted)
      result
    end
  end

  @doc """
  Similar to `dump`, but for logging at error level, and returns an error tuple:
  - an error tuple with the label, if any
  - an error tuple with the passed value otherwise

  iex> error(:value)
  # [error] :value
  {:error, :value}

  iex> error({:error, :value})
  # [error] :value
  {:error, :value}

  iex> error(:value, "with label")
  # [error] with label: :value
  {:error, "with label"}

  iex> error({:error, :value}, "with label")
  # [error] with label: :value
  {:error, "with label"}

  """
  defmacro error(thing, label \\ "") do
    pre = format_label(__CALLER__)
    stacktrace = Exception.format_stacktrace(Macro.Env.stacktrace(__CALLER__))
    quote do
      require Logger
      {formatted, result} = unquote(__MODULE__).__prepare_dbg__("#{unquote(pre)} #{unquote(label)}", Untangle.__naked_error__(unquote(thing)), pretty: true, limit: 10000, printable_limit: 10000)
      Logger.error(formatted)
      Logger.info(unquote(stacktrace))
      Untangle.__return_error__(unquote(label), result)
    end
  end

  @doc "Like `debug`, but will do nothing unless the `:debug` option is truthy"
  defmacro maybe_dbg(thing, label \\ "", options) do
    opts = Macro.var(:opts, __MODULE__)
    quote do
      unquote(opts) = unquote(options)
      if unquote(opts)[:debug] do
        debug(unquote(thing), unquote(label))
      else
        unquote(thing)
      end
    end
  end

  @doc "Like `maybe_dbg`, but requires the `:verbose` option to be set. Intended for large outputs."
  defmacro maybe_info(thing, label \\ "", options) do
    opts = Macro.var(:opts, __MODULE__)
    quote do
      unquote(opts) = unquote(options)
      if unquote(opts)[:verbose] do
        info(unquote(thing), unquote(label))
      else
        unquote(thing)
      end
    end
  end

  @doc """
  Tries to 'do what i mean'. Requires the `debug` option to be set regardless. If `verbose` is also
  set, will inspect else will attempt to print some (hopefully smaller) type-dependent summary of
  the data (list length, map keys).
  """
  defmacro smart(thing, label \\ "", options) do
    pre = format_label(__CALLER__)
    opts = Macro.var(:opts, __MODULE__)
    thang = Macro.var(:thing, __MODULE__)
    quote do
      require Logger
      unquote(opts) = unquote(options)
      unquote(thang) = unquote(thing)
      cond do
        !unquote(opts)[:debug] -> nil
        unquote(opts)[:verbose] ->
          Logger.debug("#{unquote(pre)} #{unquote(label)}: #{inspect(unquote(thang), pretty: true, limit: 10000, printable_limit: 10000)}")
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


  @doc """
  Custom backend for `Kernel.dbg/2`.
  This function provides a backend for `Kernel.dbg/2`.
  This function:
    * may log or print information about the given `env`
    * may log or print information about `code` and its returned value (using `opts` to inspect terms)
    * returns the value returned by evaluating `code`
  """
  def custom_dbg(code, options, %Macro.Env{} = env) do
    header = "#{format_label(env)} #{options[:label]}:"

    quote do
      unquote(__MODULE__).__dbg__(unquote(header), unquote(dbg_ast_to_debuggable(code)), unquote(options))
    end
  end

  if not macro_exported?(Kernel, :dbg, 2) do
    @doc """
    Polyfill for `dbg/2` if running Elixir pre 1.14
    """
    defmacro dbg(code \\ quote(do: binding()), options \\ []) do
      custom_dbg(code, options, __CALLER__)
    end
  end

  # Pipelines - copied from `Macro.dbg/2`
  defp dbg_ast_to_debuggable({:|>, _meta, _args} = pipe_ast) do
    value_var = Macro.unique_var(:value, __MODULE__)
    values_acc_var = Macro.unique_var(:values, __MODULE__)

    [start_ast | rest_asts] = asts = for {ast, 0} <- Macro.unpipe(pipe_ast), do: ast
    rest_asts = Enum.map(rest_asts, &Macro.pipe(value_var, &1, 0))

    string_asts = Enum.map(asts, &to_string/1)

    initial_acc =
      quote do
        unquote(value_var) = unquote(start_ast)
        unquote(values_acc_var) = [unquote(value_var)]
      end

    values_ast =
      for step_ast <- rest_asts, reduce: initial_acc do
        ast_acc ->
          quote do
            unquote(ast_acc)
            unquote(value_var) = unquote(step_ast)
            unquote(values_acc_var) = [unquote(value_var) | unquote(values_acc_var)]
          end
      end

    quote do
      unquote(values_ast)
      {:pipe, unquote(string_asts), Enum.reverse(unquote(values_acc_var))}
    end
  end

  defp dbg_ast_to_debuggable({:value, _, _} = value_ast) do
    value_ast
  end

  # Any other AST
  defp dbg_ast_to_debuggable(ast) do
    quote do: {:value, unquote(to_string(ast)), unquote(ast)}
  end

  # Made public to be called from Macro.dbg/3, so that we generate as little code
  # as possible and call out into a function as soon as we can.
  # copied from `Macro.dbg/2`
  @doc false
  def __dbg__(header_string, to_debug, options \\ []) do

    {formatted, result} = __prepare_dbg__(header_string, to_debug, options)

    IO.write(formatted)

    result
  end

  def __prepare_dbg__(header_string, to_debug, options \\ []) do
    {print_location?, options} = Keyword.pop(options, :print_location, true)
    options = Keyword.merge([width: 80, pretty: true, syntax_colors: syntax_colors], options)

    {formatted, result} = dbg_format_ast_to_debug(to_debug, options)

    formatted =
      if print_location? do
        [:cyan, :italic, header_string, :reset, "\n", formatted]
      else
        [formatted]
      end

    ansi_enabled? = options[:syntax_colors] != []

    {IO.ANSI.format(formatted, ansi_enabled?), result}
  end

  # inspect & format output - copied from `Macro.dbg/2`
  defp dbg_format_ast_to_debug({:pipe, code_asts, values}, options) do
    result = List.last(values)
    [{first_ast, first_value} | asts_with_values] = Enum.zip(code_asts, values)

    first_formatted = [dbg_format_ast(first_ast), " ", inspect(first_value, options), ?\n]

    rest_formatted =
      Enum.map(asts_with_values, fn {code_ast, value} ->
        [:faint, "|> ", :reset, dbg_format_ast(code_ast), " ", inspect(value, options), ?\n]
      end)

    {[first_formatted | rest_formatted], result}
  end

  defp dbg_format_ast_to_debug({:value, code_ast, value}, options) do
    {[dbg_format_ast(code_ast), " ", inspect(value, options), ?\n], value}
  end

  defp dbg_format_ast_to_debug(value, options) do
    {[inspect(value, options), ?\n], value}
  end

  defp dbg_format_ast(ast) do
    [ast, :faint, " #=>", :reset]
  end

  defp syntax_colors do
    if IO.ANSI.enabled?() do
      if function_exported?(IO.ANSI, :syntax_colors, 0), do: IO.ANSI.syntax_colors(),
        else: [ # polyfill for pre-1.14 elixir
        {:atom, :cyan},
        {:binary, :default_color},
        {:boolean, :magenta},
        {:charlist, :yellow},
        {:list, :default_color},
        {:map, :default_color},
        {nil, :magenta},
        {:number, :yellow},
        {:string, :green},
        {:tuple, :default_color}
      ]
    else
      []
    end
  end

  defp format_label(caller) do
    app = if function_exported?(Mix.Project, :config, 0), do: Mix.Project.config[:app]
    file = Path.relative_to_cwd(caller.file)
    case caller.function do
      {fun, arity} -> "[#{app}/#{file}:#{caller.line}@#{module_name(caller.module)}.#{fun}/#{arity}]"
      _ -> "[#{app}/#{file}:#{caller.line}]"
    end
  end

  defp module_name(name) when is_atom(name), do: module_name(Atom.to_string(name))
  defp module_name(name) when is_binary(name), do: String.replace_prefix(name, "Elixir.", "")

  def __naked_error__({:error, e}), do: e
  def __naked_error__(object), do: object

  def __return_error__(_label, {:error, _} = tuple), do: tuple
  def __return_error__(label, object) when is_binary(label) and label !="", do: {:error, label}
  def __return_error__(_label, object), do: {:error, object}

end
