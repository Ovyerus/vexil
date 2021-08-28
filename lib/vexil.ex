defmodule Vexil do
  @moduledoc """
  Documentation for `Vexil`.
  """
  require Vexil.Parsers
  alias Vexil.{Parsers, Structs, Utils}

  @type argv() :: Utils.argv()
  @type flags() :: list({atom(), Structs.Flags.t()})
  @type options() :: list({atom(), Structs.Options.t()})

  @type found() :: list({:ok | :error, atom(), any()})

  @type validate_argv_error() :: {:error, :invalid_argv}
  @type validate_opts_error() ::
          {:error, :invalid_flag | :invalid_option | :conflicting_key, atom()}

  @type parse_spec_item() ::
          {:flags, flags()}
          | {:options, options()}
          | {:obey_double_dash, boolean()}
          | {:error_early, boolean()}
  @type parse_spec() :: list(parse_spec_item())
  @type parsed_items() :: %{:flags => parsed_flags(), :options => parsed_options(), argv: argv()}
  @type parse_result() ::
          {:ok, parsed_items(), {list(find_options_error()), list(find_flags_error())}}
          | validate_opts_error()
          | validate_argv_error()
          | find_options_error()
          | find_flags_error()

  @type find_options_error() ::
          {:error, :unknown_option, String.t()}
          | {:error, :duplicate_option, atom()}
          | {:error, :invalid_value, atom(), String.t()}
          | {:error, :missing_required_options, list(atom())}
          | {:error, :unknown_parser, atom()}
  @type parsed_options() :: list({atom(), any()})
  @type find_options_result() ::
          {:ok, parsed_options(), list(find_options_error()), argv()} | find_options_error()

  @type find_flags_error() ::
          {:error, :unknown_flag, String.t()}
          | {:error, :duplicate_flag, atom()}
  @type parsed_flags() :: list({atom(), pos_integer() | true})
  @type find_flags_result() ::
          {:ok, parsed_flags(), list(find_flags_error()), argv()}
          | find_flags_error()

  @ungreedy_parsers [:integer, :float]

  @spec parse(argv(), parse_spec()) :: parse_result()
  def parse(argv, opts \\ []) do
    double_dash = Keyword.get(opts, :obey_double_dash, false)
    error_early = Keyword.get(opts, :error_early, false)
    opt_flags = Keyword.get(opts, :flags, [])
    opt_options = Keyword.get(opts, :options, [])

    with :ok <- validate_argv(argv),
         :ok <- validate_opts(opt_flags, opt_options),
         {argv, argv_remainder} <- Utils.split_double_dash(argv, double_dash),
         {:ok, options, option_errors, argv} <-
           find_options(argv, opt_options, opt_flags, error_early),
         {:ok, flags, flag_errors, argv} <-
           find_flags(argv, opt_flags, opt_options, error_early) do
      {
        :ok,
        %{flags: flags, options: options, argv: argv ++ argv_remainder},
        {option_errors, flag_errors}
      }
    end
  end

  @spec parse!(argv(), parse_spec()) :: any()
  def parse!(argv, opts \\ []) do
    case Vexil.parse(argv, opts) do
      {:ok, result, {[], []}} ->
        result

      # TODO: MultiError?
      {:ok, _, {[err | _], _}} ->
        Utils.bangify_parse_error(err)

      {:ok, _, {_, [err | _]}} ->
        Utils.bangify_parse_error(err)

      err ->
        Utils.bangify_parse_error(err)
    end
  end

  @spec validate_argv(argv()) :: :ok | validate_argv_error()
  defp validate_argv(argv) when is_list(argv) do
    if Enum.all?(argv, &is_binary/1) do
      :ok
    else
      {:error, :invalid_argv}
    end
  end

  @spec validate_opts(flags(), options()) :: :ok | validate_opts_error()
  defp validate_opts(flags, options) do
    {bad_flag, _} =
      Enum.find(flags, {nil, nil}, fn {_, struct} -> !match?(%Structs.Flag{}, struct) end)

    {bad_option, _} =
      Enum.find(options, {nil, nil}, fn {_, struct} -> !match?(%Structs.Option{}, struct) end)

    {required_option_has_default, _} =
      Enum.find(options, {nil, nil}, fn {_, struct} ->
        struct.required && struct.default != nil
      end)

    {invalid_parser, _} =
      Enum.find(options, {nil, nil}, fn {_, struct} ->
        struct.parser not in Parsers.all() and not is_function(struct.parser)
      end)

    flag_names =
      Enum.map(flags, fn {_, flag} -> {flag.short, flag.long} end)
      |> Enum.reduce([], fn {short, long}, acc -> [short | [long | acc]] end)

    option_names =
      Enum.map(options, fn {_, opt} -> {opt.short, opt.long} end)
      |> Enum.reduce([], fn {short, long}, acc -> [short | [long | acc]] end)

    conflicts =
      flag_names
      |> Enum.reduce(option_names, fn key, acc -> [key | acc] end)
      |> Enum.frequencies()
      |> Enum.filter(fn {_, v} -> v != 1 end)
      |> Enum.map(fn {k, _} -> k end)

    cond do
      bad_flag != nil ->
        {:error, :invalid_flag, bad_flag}

      bad_option != nil ->
        {:error, :invalid_option, bad_option}

      conflicts != [] ->
        {:error, :conflicting_key, List.first(conflicts)}

      required_option_has_default != nil ->
        {:error, :required_option_has_default, required_option_has_default}

      invalid_parser != nil ->
        {:error, :invalid_parser, invalid_parser}

      true ->
        :ok
    end
  end

  @spec find_options(argv(), options(), flags(), boolean(), found(), argv()) ::
          find_options_result()
  defp find_options(
         argv,
         wanted_options,
         wanted_flags,
         error_early,
         seen_options \\ [],
         remainder \\ []
       ) do
    consume_option = fn lookup_name, tail, comparison_key ->
      {name, option} =
        Enum.find(wanted_options, {nil, nil}, fn {_, opt} ->
          case comparison_key do
            :long -> opt.long == lookup_name
            :short -> opt.short == lookup_name
          end
        end)

      is_flag =
        Enum.find(wanted_flags, fn {_, flag} ->
          case comparison_key do
            :long -> flag.long == lookup_name
            :short -> flag.short == lookup_name
          end
        end)

      cond do
        # Ignore anything that is listed as a flag so that we don't error right after for unknown option
        is_flag ->
          fixed_name =
            case comparison_key do
              :long -> "--" <> lookup_name
              :short -> "-" <> lookup_name
            end

          find_options(tail, wanted_options, wanted_flags, error_early, seen_options, [
            fixed_name | remainder
          ])

        !option ->
          err = {:error, :unknown_option, lookup_name}

          fixed_name =
            case comparison_key do
              :long -> "--" <> lookup_name
              :short -> "-" <> lookup_name
            end

          if error_early,
            do: err,
            else:
              find_options(
                tail,
                wanted_options,
                wanted_flags,
                error_early,
                [err | seen_options],
                [fixed_name | remainder]
              )

        not option.multiple && seen_options[name] ->
          err = {:error, :duplicate_option, name}

          if error_early,
            do: err,
            else:
              find_options(
                tail,
                wanted_options,
                wanted_flags,
                error_early,
                [err | seen_options],
                remainder
              )

        true ->
          {value, tail} =
            if option.greedy and option.parser not in @ungreedy_parsers do
              Utils.consume_argv_greedy(tail)
            else
              [head | tail] = tail
              {[head], tail}
            end

          {success, value} =
            case option.parser do
              parser when parser in Parsers.all() ->
                apply(Parsers, parser, [value, option.greedy])

              # Run custom parser
              parser when is_function(parser) ->
                parser.(value, option.greedy)
            end

          result =
            if success == :error,
              do: {:error, :invalid_value, name, value},
              else: {success, name, value}

          if success == :error and error_early,
            do: result,
            else:
              find_options(
                tail,
                wanted_options,
                wanted_flags,
                error_early,
                [result | seen_options],
                remainder
              )
      end
    end

    case argv do
      [] ->
        found_options =
          seen_options
          |> Enum.filter(&match?({:ok, _, _}, &1))
          |> Enum.reduce([], fn {_, name, value}, acc ->
            should_be_list = wanted_options[name].multiple || wanted_options[name].greedy

            cond do
              should_be_list and acc[name] ->
                val =
                  case value do
                    [item] -> [item | acc[name]]
                    # might need to fiddle with some ordering memes (or just dont care about ordering)
                    [_ | _] -> value ++ acc[name]
                    _ -> [value | acc[name]]
                  end

                Keyword.put(acc, name, val)

              should_be_list ->
                val =
                  case value do
                    [_ | _] -> value
                    _ -> [value]
                  end

                Keyword.put(acc, name, val)

              true ->
                Keyword.put(acc, name, value)
            end
          end)

        found_names = Enum.map(found_options, &elem(&1, 0))

        all_errors =
          Enum.filter(seen_options, fn
            {:error, _type, _arg0, _arg1} -> true
            {:error, _type, _arg0} -> true
            _ -> false
          end)

        defaulted_options =
          wanted_options
          |> Enum.filter(fn {name, opt} -> not opt.required and name not in found_names end)
          |> Enum.map(fn {name, opt} -> {name, opt.default} end)

        missing =
          wanted_options
          |> Enum.filter(fn {name, opt} -> opt.required and name not in found_names end)
          |> Enum.map(fn {name, _} -> name end)

        missing = if missing != [], do: {:error, :missing_required_options, missing}, else: nil
        all_errors = if missing, do: [missing | all_errors], else: all_errors

        if error_early && missing do
          missing
        else
          {
            :ok,
            found_options ++ defaulted_options,
            all_errors,
            Enum.reverse(remainder)
          }
        end

      ["--" <> long | tail] ->
        {long, tail} = Utils.split_eq(long, tail)
        consume_option.(long, tail, :long)

      ["-" <> short = original | tail] ->
        {short, tail} = Utils.split_eq(short, tail)

        if String.length(short) > 1 do
          find_options(tail, wanted_options, wanted_flags, error_early, seen_options, [
            original | remainder
          ])
        else
          consume_option.(short, tail, :short)
        end

      [head | tail] ->
        find_options(tail, wanted_options, wanted_flags, error_early, seen_options, [
          head | remainder
        ])
    end
  end

  @spec find_flags(argv(), flags(), options(), boolean(), found(), argv()) :: find_flags_result()
  defp find_flags(
         argv,
         wanted_flags,
         wanted_options,
         error_early,
         seen_flags \\ [],
         remainder \\ []
       ) do
    consume_flag = fn lookups, tail, comparison_key ->
      results =
        lookups
        |> Enum.reduce({[], []}, fn lookup_name, {result_acc, name_acc} ->
          {name, flag} =
            Enum.find(wanted_flags, {nil, nil}, fn {_, flag} ->
              case comparison_key do
                :long -> flag.long == lookup_name
                :short -> flag.short == lookup_name
              end
            end)

          is_option =
            Enum.find(wanted_options, fn {_, opt} ->
              case comparison_key do
                :long -> opt.long == lookup_name
                :short -> opt.short == lookup_name
              end
            end)

          cond do
            # TODO: do we add prefix? Also this probably doesn't actually need
            # to be checked since options get consumed prior to flags (we also
            # need to special case grouped flags in options parsing but I'm too
            # lazy to do so right now oopsie)
            is_option ->
              prefix = if comparison_key == :long, do: "--", else: "-"
              value = {:remainder, prefix <> lookup_name}

              {[value | result_acc], name_acc}

            !flag ->
              value = {:error, :unknown_flag, lookup_name}

              {[value | result_acc], name_acc}

            # TODO: there's probably a more elegant solution to this
            not flag.multiple &&
                (name in name_acc ||
                   Enum.find(seen_flags, fn
                     {:ok, flag_name, _} -> flag_name == name
                     _ -> false
                   end)) ->
              value = {:error, :duplicate_flag, name}

              {[value | result_acc], name_acc}

            true ->
              value = {:ok, name, true}

              {[value | result_acc], [name | name_acc]}
          end
        end)
        |> elem(0)

      first_error = results |> Enum.find(&match?({:error, _, _}, &1))
      results_no_remainders = Enum.filter(results, fn x -> !match?({:remainder, _, _}, x) end)

      remainders =
        results
        |> Enum.filter(&match?({:remainder, _}, &1))
        |> Enum.map(&elem(&1, 1))

      if error_early and first_error,
        do: first_error,
        else:
          find_flags(
            tail,
            wanted_flags,
            wanted_options,
            error_early,
            results_no_remainders ++ seen_flags,
            remainders ++ remainder
          )
    end

    case argv do
      [] ->
        found_flags =
          seen_flags
          |> Enum.filter(&match?({:ok, _, _}, &1))
          # Get amount of times each name occurs (used for multiple flags like verbosity)
          # Doing this manually instead of Enum.frequencies so that we maintain the order,
          # as Enum.frequencies puts it into a map which is sorted alphabeticallyQ
          |> Enum.reduce([], fn {_, key, _}, acc ->
            Keyword.put(
              acc,
              key,
              case acc[key] do
                nil -> 1
                i -> i + 1
              end
            )
          end)
          |> Enum.map(fn
            {name, count} ->
              if wanted_flags[name].multiple,
                do: {name, count},
                else: {name, true}
          end)

        unprovided_flags =
          wanted_flags
          |> Enum.filter(fn {name, _} -> found_flags[name] == nil end)
          |> Enum.map(fn {name, _} -> {name, false} end)

        all_errors = seen_flags |> Enum.filter(&match?({:error, _type, _arg0}, &1)) |> Enum.uniq()

        {:ok, found_flags ++ unprovided_flags, all_errors, Enum.reverse(remainder)}

      ["--" <> long | tail] ->
        consume_flag.([long], tail, :long)

      ["-" <> short | tail] ->
        # Allow grouping short flags together like `-abcdeeee`
        flags =
          if(String.length(short) > 1, do: String.graphemes(short), else: [short])
          |> Enum.reverse()

        consume_flag.(flags, tail, :short)

      [head | tail] ->
        find_flags(tail, wanted_flags, wanted_options, error_early, seen_flags, [head | remainder])
    end
  end
end
