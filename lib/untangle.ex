defmodule Untangle do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()
  require Logger

  defmacro __using__(opts) do
    quote do
      import Untangle, unquote(opts)
      require Logger
      use Untangle.Time
    end
  end

  @doc "IO.inspect but outputs to Logger with position information, an optional label and configured not to truncate output too much."
  defmacro dump(thing, label \\ nil, opts \\ []) do
    # stacktrace = Untangle.get_current_stacktrace() 
    #   stacktrace = Macro.Env.stacktrace(__CALLER__)
    location = format_label(__CALLER__)

    quote do
      # Untangle.__dbg__(
      #   "#{unquote(pre)} #{unquote(label)}",
      #   unquote(thing)
      # )

      require Logger

      opts = unquote(opts)
      # stacktrace = unquote(opts[:stacktrace] || Untangle.get_current_stacktrace()) 

      {formatted, result} =
        Untangle.__prepare_dbg__(
          unquote(label),
          unquote(thing),
          Keyword.merge(
            [
              location:
                if opts[:print_location] != false do
                  unquote(location)
                  # Untangle.format_stacktrace_label(stacktrace, opts[:trace_skip] || 0)
                end,
              pretty: true,
              limit: :infinity,
              printable_limit: :infinity
            ],
            opts
          )
        )

      Untangle.log_or_flood(:info, formatted)
      result
    end
  end

  @doc "Like `dump`, but for logging at debug level"
  defmacro debug(thing, label \\ nil, opts \\ []) do
    # stacktrace = Untangle.get_current_stacktrace() 
    location = format_label(__CALLER__)

    quote do
      if Untangle.log_level?(:debug) do
        require Logger

        opts = unquote(opts)
        # stacktrace = unquote(opts[:stacktrace] || Untangle.get_current_stacktrace()) 

        {formatted, result} =
          Untangle.__prepare_dbg__(
            unquote(label),
            unquote(thing),
            Keyword.merge(
              [
                location:
                  if opts[:print_location] != false do
                    unquote(location)
                    # Untangle.format_stacktrace_label(stacktrace, opts[:trace_skip] || 0)
                  end,
                pretty: true,
                limit: 10000,
                printable_limit: 10000
              ],
              opts
            )
          )

        Untangle.log_or_flood(:debug, formatted)
        result
      else
        unquote(thing)
      end
    end
  end

  @doc "Like `dump`, but for logging at info level"
  defmacro info(thing, label \\ nil, opts \\ []) do
    # stacktrace = Untangle.get_current_stacktrace() 
    location = format_label(__CALLER__)

    quote do
      if Untangle.log_level?(:info) do
        require Logger

        opts = unquote(opts)
        # stacktrace = unquote(opts[:stacktrace] || Untangle.get_current_stacktrace()) 

        {formatted, result} =
          Untangle.__prepare_dbg__(
            unquote(label),
            unquote(thing),
            Keyword.merge(
              [
                location:
                  if opts[:print_location] != false do
                    unquote(location)
                    # Untangle.format_stacktrace_label(stacktrace, opts[:trace_skip] || 0)
                  end,
                pretty: true,
                limit: 10000,
                printable_limit: 10000
              ],
              opts
            )
          )

        Untangle.log_or_flood(:info, formatted)
        result
      else
        unquote(thing)
      end
    end
  end

  @doc "Like `dump`, but for logging at warn level"
  defmacro warn(thing, label \\ nil, opts \\ []) do
    location = format_label(__CALLER__)

    quote do
      if Untangle.log_level?(:warning) do
        require Logger

        opts = unquote(opts)

        {formatted, result} =
          Untangle.__prepare_dbg__(
            unquote(label),
            unquote(thing),
            Keyword.merge(
              [
                # location:
                #   if opts[:print_location] != false do
                #     unquote(location)
                #     # Untangle.format_stacktrace_label(stacktrace, opts[:trace_skip] || 0)
                #   end,
                stacktrace:
                  if opts[:print_location] != false do
                    Untangle.format_stacktrace_sliced(
                      opts[:stacktrace] || Untangle.get_current_stacktrace(),
                      opts[:trace_skip] || 0,
                      opts[:trace_limit] || 5
                    )
                  end,
                pretty: true,
                limit: 10000,
                printable_limit: 10000
              ],
              opts
            )
          )

        Untangle.log_or_flood(:warning, formatted)
        result
      else
        unquote(thing)
      end
    end
  end

  @doc ~S"""
  Similar to `dump`, but for logging at error level, and returns an error tuple:
  - an error tuple with the label, if any
  - an error tuple with the passed value otherwise

    iex> error(:value)
    ### [error] :value
    {:error, :value}

    iex> error({:error, :value})
    ### [error] :value
    {:error, :value}

    iex> error(:value, "with label")
    ### [error] with label: :value
    {:error, "with label"}

    iex> error({:error, :value}, "with label")
    ### [error] with label: :value
    {:error, "with label"}
  """
  defmacro error(thing, label \\ nil, opts \\ []) do
    location = format_label(__CALLER__)

    quote do
      if Untangle.log_level?(:error) do
        require Logger

        opts = unquote(opts)

        {formatted, result} =
          Untangle.__prepare_dbg__(
            unquote(label),
            Untangle.__naked_error__(unquote(thing)),
            Keyword.merge(
              [
                # location:
                #     if opts[:print_location] != false do
                #       unquote(location)
                #       # Untangle.format_stacktrace_label(stacktrace, opts[:trace_skip] || 0)
                #     end,
                stacktrace:
                  if opts[:print_location] != false do
                    Untangle.format_stacktrace_sliced(
                      opts[:stacktrace] || Untangle.get_current_stacktrace(),
                      opts[:trace_skip] || 0,
                      opts[:trace_limit] || 8
                    )
                  end,
                pretty: true,
                limit: 10000,
                printable_limit: 10000
              ],
              opts
            )
          )

        Untangle.log_or_flood(:error, formatted)
        Untangle.__return_error__(unquote(label), result)
      else
        Untangle.__return_error__(unquote(label), unquote(thing))
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
    # stacktrace = Macro.Env.stacktrace(__CALLER__) 

    quote do
      require Logger
      unquote(opts) = unquote(options)
      unquote(thang) = unquote(thing)

      cond do
        !unquote(opts)[:debug] ->
          nil

        unquote(opts)[:verbose] ->
          Logger.debug(
            "#{unquote(pre)} #{unquote(label)}: #{inspect(unquote(thang), pretty: true, limit: 10000, printable_limit: 10000)}"
          )

        is_list(unquote(thang)) ->
          Logger.debug(
            "#{unquote(pre)} #{unquote(label)} (length): #{Enum.count(unquote(thang))}"
          )

        is_struct(unquote(thang)) ->
          Logger.debug("#{unquote(pre)} #{unquote(label)}: %#{unquote(thang).__struct__}{}")

        is_map(unquote(thang)) and not is_struct(unquote(thang)) ->
          Logger.debug(
            "#{unquote(pre)} #{unquote(label)} (keys): #{inspect(Map.keys(unquote(thang)))}"
          )

        true ->
          Logger.debug(
            "#{unquote(pre)} #{unquote(label)} (inspect elided, pass `:verbose` to see)"
          )
      end

      unquote(thang)
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
      Untangle.__dbg__(
        unquote(header),
        unquote(dbg_ast_to_debuggable(code)),
        unquote(options)
      )
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

  def get_current_stacktrace do
    Process.info(self(), :current_stacktrace)
    |> elem(1)
  end

  # TODO: check this at compile time and inline it so we don't check at runtime?
  def log_level?(level) do
    min_level =
      Application.get_env(:untangle, :level) || Application.get_env(:logger, :level) || :debug

    Logger.compare_levels(level, min_level) != :lt
  end

  def to_io? do
    Application.get_env(:untangle, :to_io, false)
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

            unquote(values_acc_var) = [
              unquote(value_var) | unquote(values_acc_var)
            ]
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
  # Copied from `Macro.dbg/2`
  @doc false
  def __dbg__(header_string, to_debug, options \\ []) do
    {formatted, result} = __prepare_dbg__(header_string, to_debug, options)

    IO.write(formatted)

    result
  end

  @doc false
  def __prepare_dbg__(header_string, to_debug, options \\ []) do
    {print_location?, options} = Keyword.pop(options, :print_location, true)

    options =
      Keyword.merge(
        [width: 80, pretty: true, syntax_colors: syntax_colors()],
        options
      )

    {formatted, result} = dbg_format_ast_to_debug(to_debug, options)

    # random_integer = :rand.uniform(1000)

    header_string =
      cond do
        #  "[##{random_integer}]"
        is_nil(header_string) -> ""
        is_binary(header_string) -> "#{header_string}: "
        true -> "#{inspect(header_string)}:"
      end

    formatted =
      cond do
        print_location? && options[:location] ->
          [:italic, header_string, :reset, formatted, :faint, " @ ", options[:location]]

        print_location? && options[:stacktrace] ->
          [:italic, header_string, :reset, formatted, ?\n, :faint, options[:stacktrace]]

        print_location? && header_string != "" ->
          [:italic, header_string, :reset, formatted]

        true ->
          [formatted]
      end

    ansi_enabled? = options[:syntax_colors] != []

    {IO.ANSI.format(formatted, ansi_enabled?), result}
  end

  # inspect & format output - copied from `Macro.dbg/2`
  defp dbg_format_ast_to_debug({:pipe, code_asts, values}, options) do
    result = List.last(values)
    [{first_ast, first_value} | asts_with_values] = Enum.zip(code_asts, values)

    first_formatted = [
      dbg_format_ast(first_ast),
      " ",
      inspect(first_value, options),
      ?\n
    ]

    rest_formatted =
      Enum.map(asts_with_values, fn {code_ast, value} ->
        [
          :faint,
          "|> ",
          :reset,
          dbg_format_ast(code_ast),
          " ",
          inspect(value, options),
          ?\n
        ]
      end)

    {[first_formatted | rest_formatted], result}
  end

  defp dbg_format_ast_to_debug({:value, code_ast, value}, options) do
    {[dbg_format_ast(code_ast), " ", inspect(value, options)], value}
  end

  defp dbg_format_ast_to_debug(value, _options) when is_binary(value) do
    {[value], value}
  end

  defp dbg_format_ast_to_debug(value, options) do
    {[inspect(value, options)], value}
  end

  defp dbg_format_ast(ast) do
    [ast, :faint, " #=>", :reset]
  end

  defp syntax_colors do
    if IO.ANSI.enabled?() do
      if function_exported?(IO.ANSI, :syntax_colors, 0),
        do: IO.ANSI.syntax_colors(),
        # polyfill for pre-1.14 elixir
        else: [
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
    app =
      if function_exported?(Mix.Project, :config, 0),
        do: Mix.Project.config()[:app]

    # TODO: better path handing for deps
    # if dep_path = function_exported?(caller.module, :__info__, 1) and caller.module.__info__(:compile)[:source] do
    #   Path.relative_to_cwd(dep_path) 
    # else
    file =
      "#{app}/#{Path.relative_to_cwd(caller.file)}"

    # end

    case caller.function do
      {fun, arity} ->
        "#{file}:#{caller.line} @ #{module_name(caller.module)}.#{fun}/#{arity}"

      _ ->
        "#{file}:#{caller.line}"
    end
  end

  def format_stacktrace_label(stacktrace, skip \\ 0) do
    stacktrace
    |> Enum.at(skip)
    |> format_stacktrace_entry()
  end

  def format_stacktrace_sliced(stacktrace, starts \\ 0, amount \\ 5)

  def format_stacktrace_sliced(stacktrace, nil, nil) when is_list(stacktrace) do
    format_stacktrace_sliced(stacktrace, 0, 100)
  end

  def format_stacktrace_sliced(stacktrace, starts, nil) when is_list(stacktrace) do
    format_stacktrace_sliced(stacktrace, starts, 100)
  end

  def format_stacktrace_sliced(stacktrace, nil, amount) when is_list(stacktrace) do
    format_stacktrace_sliced(stacktrace, 0, amount)
  end

  def format_stacktrace_sliced(stacktrace, starts, amount) when is_list(stacktrace) do
    stacktrace
    |> Enum.slice(starts + 2, amount + 2)
    |> format_stacktrace()
  end

  def format_stacktrace_sliced(_stacktrace, _, _), do: nil

  @doc """
  Formats the stacktrace.

  A stacktrace must be given as an argument. If not, the stacktrace
  is retrieved from `Process.info/2`.
  """
  @spec format_stacktrace(Exception.stacktrace() | nil) :: String.t()
  def format_stacktrace(trace \\ nil) do
    trace =
      if trace do
        trace
      else
        case Process.info(self(), :current_stacktrace) do
          {:current_stacktrace, t} -> Enum.drop(t, 3)
        end
      end

    case trace do
      [] -> "\n"
      _ -> "    " <> Enum.map_join(trace, "\n    ", &format_stacktrace_entry(&1)) <> "\n"
    end
  end

  @doc """
  Receives a stacktrace entry and formats it into a string.
  """
  @spec format_stacktrace_entry(Exception.stacktrace_entry()) :: String.t()
  def format_stacktrace_entry(entry)

  # From Macro.Env.stacktrace and :elixir_compiler_*
  def format_stacktrace_entry({module, mod, arity, location})
      when mod in [:__MODULE__, :__FILE__] and arity in [0, 1] do
    Exception.format_stacktrace_entry({module, mod, arity, location})
  end

  def format_stacktrace_entry({app, module, fun, arity, location}) do
    Exception.format_mfa(module, fun, arity) <>
      " @ " <> format_application_location(app, module, location)
  end

  def format_stacktrace_entry({module, fun, arity, location}) do
    Exception.format_mfa(module, fun, arity) <>
      " @ " <> format_application_location(module, location)
  end

  def format_stacktrace_entry(other) do
    format_stacktrace_entry(other)
  end

  def format_application_location(app \\ nil, module, location) do
    if dep_path = function_exported?(module, :__info__, 1) and module.__info__(:compile)[:source] do
      format_location(Path.relative_to_cwd(dep_path), location)
    else
      case app || :application.get_application(module) do
        # We cannot use Application here due to bootstrap issues
        {:ok, app} ->
          case :application.get_key(app, :vsn) do
            {:ok, vsn} when is_list(vsn) ->
              "(" <> Atom.to_string(app) <> " " <> List.to_string(vsn) <> ") "

            _ ->
              "(" <> Atom.to_string(app) <> ") "
          end

        :undefined ->
          ""
      end <> format_location(location)
    end
  end

  def format_location(dep_path \\ nil, opts) when is_list(opts) do
    dep_path = dep_path || Keyword.get(opts, :file)

    case opts[:column] do
      nil ->
        Exception.format_file_line(dep_path, Keyword.get(opts, :line), "")

      col ->
        Exception.format_file_line_column(dep_path, Keyword.get(opts, :line), col, "")
    end
    |> String.trim_trailing(":")
  end

  def module_name(name) when is_atom(name),
    do: module_name(Atom.to_string(name))

  def module_name(name) when is_binary(name),
    do: String.replace_prefix(name, "Elixir.", "")

  @doc false
  def __naked_error__({:error, e}), do: e
  def __naked_error__(object), do: object

  @doc false
  def __return_error__(_label, {:error, _} = tuple), do: tuple

  def __return_error__(label, _object) when is_binary(label) and label != "",
    do: {:error, label}

  def __return_error__(_label, object), do: {:error, object}

  @doc "Like `IO.inspect/2`, but accepts a string as second argument and does not truncate the output"
  def flood(msg) when is_binary(msg), do: flood(nil, msg)
  def flood(data) when not is_binary(data), do: flood(data, "Inspect")

  def flood(data, msg) when is_binary(msg) do
    IO.inspect(data, label: msg, limit: :infinity)
  end

  @doc """
  Logs or raises errors based on environment.

  This function handles errors differently depending on the environment:
  - In test: raises an exception
  - In dev: prints a warning
  - In production: logs a warning

  ## Examples

      # With just a message
      iex> # When in dev/prod (not test), prints a warning and does not raise
      iex> # Note: Only testing return value here, not side effects
      iex> Process.put([:bonfire, :env], :dev)
      iex> err("error message")
      # Prints: [warning] error message
      nil

      # With just data
      iex> Process.put([:bonfire, :env], :dev)
      iex> err(%{key: "value"})
      # Prints: [warning] An error occurred: %{key: "value"}
      %{key: "value"}

      # With both data and message
      iex> Process.put([:bonfire, :env], :dev)
      iex> err(%{key: "value"}, "Custom error message")
      # Prints: [warning] Custom error message: %{key: "value"}
      %{key: "value"}

  In test environment, it raises an exception:

      iex> Process.put([:bonfire, :env], :test)
      iex> err("test error")
      ** (RuntimeError) test error
  """
  def err(msg) when is_binary(msg), do: err(nil, msg)
  def err(data) when not is_binary(data), do: err(data, "An error occurred")

  def err(data, msg, opts \\ []) when is_binary(msg) do
    case Application.get_env(:untangle, :env) do
      :test ->
        if data, do: io_warn(data, opts[:stacktrace])
        raise msg

      :dev ->
        # error(data, msg)
        if data,
          do: io_warn("[error] #{msg}: #{inspect(data)}", opts[:stacktrace]),
          else: io_warn("[error] #{msg}", opts[:stacktrace])

        data

      _prod_etc ->
        error(data, msg, opts)
    end
  end

  defp io_warn(msg, nil) do
    IO.warn(if is_binary(msg), do: msg, else: inspect(msg))
  end

  defp io_warn(msg, stacktrace_info) do
    IO.warn(if(is_binary(msg), do: msg, else: inspect(msg)), stacktrace_info)
  end

  # Add this helper function at module level (private)
  def log_or_flood(level, formatted) when is_binary(formatted) or is_list(formatted) do
    if to_io?() do
      IO.puts(formatted)
    else
      Logger.log(level, formatted)
    end
  catch
    _e -> log_or_flood(level, inspect(formatted))
  end

  def log_or_flood(level, formatted) do
    log_or_flood(level, inspect(formatted))
  end
end
