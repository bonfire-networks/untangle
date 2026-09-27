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
      if Untangle.log_enabled?(:debug) do
        require Logger

        opts = unquote(opts)
        limit = Untangle.log_truncate_limit()
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
                limit: limit,
                printable_limit: limit
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
      if Untangle.log_enabled?(:info) do
        require Logger

        opts = unquote(opts)
        limit = Untangle.log_truncate_limit()
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
                limit: limit,
                printable_limit: limit
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
      if Untangle.log_enabled?(:warning) do
        require Logger

        opts = unquote(opts)
        limit = Untangle.log_truncate_limit()

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
                limit: limit,
                printable_limit: limit
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

  @doc "Like `warn`, but for logging at notice level, e.g. for warnings meant for developers which a production log level should filter out"
  defmacro notice(thing, label \\ nil, opts \\ []) do
    quote do
      if Untangle.log_enabled?(:notice) do
        require Logger

        opts = unquote(opts)
        limit = Untangle.log_truncate_limit()

        {formatted, result} =
          Untangle.__prepare_dbg__(
            unquote(label),
            unquote(thing),
            Keyword.merge(
              [
                stacktrace:
                  if opts[:print_location] != false do
                    Untangle.format_stacktrace_sliced(
                      opts[:stacktrace] || Untangle.get_current_stacktrace(),
                      opts[:trace_skip] || 0,
                      opts[:trace_limit] || 5
                    )
                  end,
                pretty: true,
                limit: limit,
                printable_limit: limit
              ],
              opts
            )
          )

        Untangle.log_or_flood(:notice, formatted)
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
      if Untangle.log_enabled?(:error) do
        require Logger

        opts = unquote(opts)
        limit = Untangle.log_truncate_limit()

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
                limit: limit,
                printable_limit: limit
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
          limit = Untangle.log_truncate_limit()

          Logger.debug(
            "#{unquote(pre)} #{unquote(label)}: #{inspect(unquote(thang), pretty: true, limit: limit, printable_limit: limit)}"
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

  @doc "Whether a message at `level` would actually be logged (vs discarded by the current minimum level). Use to skip expensive work that only feeds a log line."
  def log_enabled?(level) do
    # `Logger.level/0` (not the :logger app env) so runtime `Logger.configure/1` changes apply
    min_level = Application.get_env(:untangle, :level) || Logger.level()

    Logger.compare_levels(level, min_level) != :lt
  end

  def to_io? do
    Application.get_env(:untangle, :to_io, false)
  end

  @cwd_key {__MODULE__, :cwd}

  @doc """
  The working directory, looked up once per node.

  `Path.relative_to_cwd/1` calls `File.cwd()`, which is a `GenServer.call` to the single global `:file_server_2`. Formatting a stacktrace touches this once per frame, so a node logging errors in a loop serialises every one of those calls through one mailbox. A release's working directory cannot change under it, so the answer is cached.
  """
  if Application.compile_env(:untangle, :env) in [:dev, :test] do
    # under Mix the working directory moves: `Mix.Project.in_project/4` cd's into each dependency
    # while compiling it, so a cached value could misreport every path for the rest of the session
    def cwd, do: File.cwd!()
  else
    def cwd do
      case :persistent_term.get(@cwd_key, nil) do
        nil ->
          cwd = File.cwd!()
          # the write forces a global GC scan, which is why it happens exactly once
          :persistent_term.put(@cwd_key, cwd)
          cwd

        cwd ->
          cwd
      end
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
          # slice the inspected value here, while the structural ANSI is still symbolic atoms, so the stacktrace after it survives Logger's `:truncate` without any risk of clipping an escape sequence mid-slice
          reserved =
            String.length(to_string(header_string)) +
              String.length(to_string(options[:stacktrace])) + 8

          data = slice_to_log_limit(IO.iodata_to_binary(formatted), reserved: reserved)

          [:italic, header_string, :reset, data, ?\n, :faint, options[:stacktrace]]

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

  @doc "The configured Logger `:truncate` limit (bytes) beyond which log messages get cut off. Returns `:infinity` when truncation is disabled."
  def log_truncate_limit(default \\ 8096) do
    console = Application.get_env(:logger, :console) || []

    case console[:truncate] || Application.get_env(:logger, :truncate, default) do
      :infinity -> :infinity
      n when is_integer(n) and n > 0 -> n
      _ -> default
    end
  end

  @doc """
  Slice `string` so it fits within the Logger `:truncate` budget (keeping the head), so the useful part survives rather than being cut off mid-message. Pass `reserved` to leave room for other parts of the same log line, e.g. slice a huge exception banner while reserving space for the stacktrace
  that follows it.
  """
  def slice_to_log_limit(string, opts \\ []) do
    string = to_string(string)

    case opts[:log_limit] || log_truncate_limit() do
      :infinity ->
        string

      limit ->
        # Give `string` whatever budget is left after `reserved`, but never below a small floor (min) so its head (e.g. an exception's type + message) always shows — even when `reserved` (a long stacktrace) would otherwise leave no room. In that rare case the line exceeds `limit` and Logger trims the tail instead.
        String.slice(string, 0, max(opts[:min] || 200, limit - (opts[:reserved] || 0)))
    end
  end

  @doc """
  Formats the stacktrace.

  A stacktrace must be given as an argument. If not, the stacktrace
  is retrieved from `Process.info/2`.

  Options, for a caller showing it somewhere other than a log (such as an in-app error page):
  - `:indent`, put before each frame (default four spaces, the log's layout)
  - `:link_to_code`, a `fn text, module_name, fun_name -> text end` wrapping each frame's location, e.g. in a link to its source
  - `:entry_max_length`, a cap on each frame's length
  """
  @spec format_stacktrace(Exception.stacktrace() | nil, keyword()) :: String.t()
  def format_stacktrace(trace \\ nil, opts \\ []) do
    trace =
      if trace do
        trace
      else
        Enum.drop(get_current_stacktrace(), 3)
      end

    indent = Keyword.get(opts, :indent, "    ")

    case trace do
      [] ->
        "\n"

      _ ->
        indent <>
          Enum.map_join(trace, "\n" <> indent, &format_stacktrace_entry(&1, opts)) <> "\n"
    end
  end

  @doc """
  Receives a stacktrace entry and formats it into a string, taking the options `format_stacktrace/2` does.

  ## Examples

      iex> Untangle.format_stacktrace_entry({Foo, :bar, 1, [file: ~c"lib/foo.ex", line: 42]})
      "Foo.bar/1 @ lib/foo.ex:42"
  """
  @spec format_stacktrace_entry(Exception.stacktrace_entry(), keyword()) :: String.t()
  def format_stacktrace_entry(entry, opts \\ [])

  # From Macro.Env.stacktrace and :elixir_compiler_*
  def format_stacktrace_entry({module, mod, arity, location}, _opts)
      when mod in [:__MODULE__, :__FILE__] and arity in [0, 1] do
    Exception.format_stacktrace_entry({module, mod, arity, location})
  end

  def format_stacktrace_entry({app, module, fun, arity, location}, opts) do
    (format_mfa(module, fun, arity) <>
       " @ " <>
       maybe_link_to_code(format_application_location(app, module, location), module, fun, opts))
    |> maybe_cap_entry(opts)
  end

  def format_stacktrace_entry({module, fun, arity, location}, opts) do
    (format_mfa(module, fun, arity) <>
       " @ " <>
       maybe_link_to_code(format_application_location(module, location), module, fun, opts))
    |> maybe_cap_entry(opts)
  end

  # an anonymous function called from an erlang frame, with no module
  def format_stacktrace_entry({fun, arity, location}, opts) do
    (Exception.format_fa(fun, arity) <> " @ " <> format_location(location))
    |> maybe_cap_entry(opts)
  end

  def format_stacktrace_entry(other, _opts) do
    inspect(other)
  end

  defp maybe_link_to_code(text, module, fun, opts) do
    case opts[:link_to_code] do
      link when is_function(link, 3) ->
        {mod, fun} = mf_names(module, fun)
        link.(text, mod, fun)

      _ ->
        text
    end
  end

  defp maybe_cap_entry(entry, opts) do
    case opts[:entry_max_length] do
      max when is_integer(max) -> String.slice(entry, 0, max)
      _ -> entry
    end
  end

  @doc """
  Formats a module, function and arity as shown in stacktraces. The arity may also be the list of arguments a call was made with, as in the frame that raised.

  An anonymous function reads as "anonymous fn/arity in Module.fun/arity", rather than the compiler's `-fun/arity-fun-count-`.

  Arguments are inspected within the log's `:truncate` budget and sliced to a quarter of it. The frame that raised carries its arguments, and one of them (a whole LiveView socket) could otherwise fill the budget by itself and cut off every frame after it. The exception's banner keeps up to half the budget, and the frames after this one need the rest.

  ## Examples

      iex> Untangle.format_mfa(Foo, :bar, 1)
      "Foo.bar/1"

      iex> Untangle.format_mfa(Foo, :bar, [])
      "Foo.bar()"

      iex> Untangle.format_mfa(Foo, :bar, [1, :two])
      "Foo.bar(1, :two)"
  """
  def format_mfa(module, fun, arity_or_args) when is_atom(module) and is_atom(fun) do
    mod = Macro.inspect_atom(:literal, module)

    case Code.Identifier.extract_anonymous_fun_parent(fun) do
      {outer_name, outer_arity} ->
        "anonymous fn#{format_arity(arity_or_args)} in " <>
          "#{mod}.#{Macro.inspect_atom(:remote_call, outer_name)}/#{outer_arity}"

      :error ->
        "#{mod}.#{Macro.inspect_atom(:remote_call, fun)}#{format_arity(arity_or_args)}"
    end
  end

  def format_mfa(module, fun, arity_or_args), do: Exception.format_mfa(module, fun, arity_or_args)

  # the names a link to a frame's code is built from: an anonymous function's is the function it is in
  defp mf_names(module, fun) do
    mod = Macro.inspect_atom(:literal, module)

    case Code.Identifier.extract_anonymous_fun_parent(fun) do
      {outer_name, _outer_arity} -> {mod, Macro.inspect_atom(:remote_call, outer_name)}
      :error -> {mod, Macro.inspect_atom(:remote_call, fun)}
    end
  end

  defp format_arity(args) when is_list(args) do
    limit = log_truncate_limit()

    formatted_args =
      args
      |> Enum.map_join(", ", &inspect(&1, limit: limit, printable_limit: limit))
      |> slice_to_log_limit(
        min: 0,
        reserved: if(is_integer(limit), do: limit - div(limit, 4), else: 0)
      )

    "(#{formatted_args})"
  end

  defp format_arity(arity) when is_integer(arity), do: "/#{arity}"

  def format_application_location(app \\ nil, module, location) do
    if dep_path = function_exported?(module, :__info__, 1) and module.__info__(:compile)[:source] do
      format_location(Path.relative_to(dep_path, cwd()), location)
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
  def io_inspect(msg_or_data) when is_binary(msg_or_data) do
    IO.puts(msg_or_data)
    msg_or_data
  end

  def io_inspect(data) when not is_binary(data), do: io_inspect(data, "Inspect")

  def io_inspect(data, msg) when is_binary(msg) do
    IO.inspect(data, label: msg, limit: 10_000)
  end

  @doc """
  Logs or raises errors based on environment.

  The `:untangle, :env` config picks the behaviour at compile time:
  - In test: prints a warning and raises the message as a `RuntimeError`
  - In dev: prints a warning and returns an error tuple wrapping the data
  - Otherwise: logs at error level and returns an error tuple, like `error/3`

  ## Examples

  These run with `:env` unset, so they show the last behaviour:

      iex> err("error message")
      {:error, "error message"}

      iex> err(%{key: "value"})
      {:error, "An error occurred"}

      iex> err(%{key: "value"}, "Custom error message")
      {:error, "Custom error message"}
  """
  def err(msg) when is_binary(msg), do: err(nil, msg)
  def err(data) when not is_binary(data), do: err(data, "An error occurred")

  if Application.compile_env(:untangle, :env) == :test do
    def err(data, msg, opts \\ []) when is_binary(msg) do
      io_warn(data, opts[:stacktrace])
      raise msg
    end
  end

  if Application.compile_env(:untangle, :env) == :dev do
    def err(data, msg, opts \\ []) when is_binary(msg) do
      # error(data, msg)
      case data do
        nil ->
          io_warn("[error] #{msg}", opts[:stacktrace])
          {:error, nil}

        {:error, data} ->
          io_warn("[error] #{msg}: #{inspect(data)}", opts[:stacktrace])
          {:error, data}

        _ ->
          io_warn("[error] #{msg}: #{inspect(data)}", opts[:stacktrace])
          {:error, data}
      end
    end
  end

  if Application.compile_env(:untangle, :env) not in [:dev, :test] do
    def err(data, msg, opts \\ []) when is_binary(msg) do
      error(data, msg, opts)
    end
  end

  def warner(msg) when is_binary(msg), do: warner(nil, msg)
  def warner(data) when not is_binary(data), do: warner(data, "Warning")

  if Application.compile_env(:untangle, :env) in [:dev, :test] do
    def warner(data, msg, opts \\ []) when is_binary(msg) do
      if data,
        do:
          io_warn(
            "#{msg}: #{if(is_binary(data), do: data, else: inspect(data))}",
            opts[:stacktrace]
          ),
        else: io_warn("#{msg}", opts[:stacktrace])

      data
    end
  else
    def warner(data, msg, opts \\ []) when is_binary(msg) do
      warn(data, msg, opts)
    end
  end

  defp io_warn(msg, nil) do
    IO.warn(if is_binary(msg), do: msg, else: inspect(msg))
  end

  defp io_warn(msg, stacktrace_info) do
    IO.warn(if(is_binary(msg), do: msg, else: inspect(msg)), stacktrace_info)
  end

  def log_or_flood(level, formatted) when is_binary(formatted) or is_list(formatted) do
    if to_io?() do
      IO.puts(formatted)
    else
      Logger.log(level, formatted)
    end
  rescue
    e -> log_failed(level, formatted, :error, e)
  catch
    kind, e -> log_failed(level, formatted, kind, e)
  end

  def log_or_flood(level, formatted) do
    log_or_flood(level, inspect(formatted))
  end

  # Deliberately does not go back through `log_or_flood/2`: as retrying would re-enter the same clause and might recurse until the process died. One attempt on stderr, then give up, logging must never become the reason something breaks
  defp log_failed(level, formatted, kind, reason) do
    IO.puts(
      :stderr,
      "[#{level}] untangle could not log (#{Exception.format_banner(kind, reason)}): " <>
        inspect(formatted, limit: 10, printable_limit: 512)
    )

    :ok
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end
end
