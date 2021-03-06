defmodule Paco do

  def parse!(text, p, opts \\ []) do
    parse(text, p, Keyword.merge(opts, [on_failure: :raise]))
  end

  def parse(text, p, opts \\ []) do
    p = Paco.Parser.box(p)
    p.parse.(Paco.State.from(text, opts), p)
    |> handle_failure(Keyword.get(opts, :on_failure, :yield))
    |> format(Keyword.get(opts, :format, :tagged))
  end

  def parse_all!(text, p, opts \\ []) do
    parse_all(text, p, Keyword.merge(opts, [on_failure: :raise]))
  end

  def parse_all(text, p, opts \\ []) do
    [text]
    |> Paco.Stream.parse(p, Keyword.merge(opts, [format: :raw, on_failure: :yield]))
    |> Enum.map(&handle_failure(&1, Keyword.get(opts, :on_failure, :yield)))
    |> Enum.map(&format(&1, Keyword.get(opts, :format, :tagged)))
  end

  @doc false
  defmacro __using__(_) do
    quote do
      import Paco.Macro.ParserModuleDefinition
      import Paco.Parser

      Module.register_attribute(__MODULE__, :paco_root_parser, accumulate: false)
      Module.register_attribute(__MODULE__, :paco_parsers, accumulate: true)

      @before_compile Paco
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    root_parser = pick_root_parser_between(
      Module.get_attribute(env.module, :paco_root_parser),
      Module.get_attribute(env.module, :paco_parsers) |> Enum.reverse
    )
    quote do
      def parse(s, opts \\ []), do: Paco.parse(s, apply(__MODULE__, unquote(root_parser), []), opts)
      def parse!(s, opts \\ []), do: Paco.parse!(s, apply(__MODULE__, unquote(root_parser), []), opts)
    end
  end

  defp pick_root_parser_between(nil, []), do: nil
  defp pick_root_parser_between(nil, [pn]), do: pn
  defp pick_root_parser_between(nil, [_|pns]), do: pick_root_parser_between(nil, pns)
  defp pick_root_parser_between(pn, _) when is_atom(pn), do: pn
  defp pick_root_parser_between(pn, _) when is_binary(pn), do: String.to_atom(pn)

  defp format(%Paco.Success{} = success, how), do: Paco.Success.format(success, how)
  defp format(%Paco.Failure{} = failure, how), do: Paco.Failure.format(failure, how)

  defp handle_failure(%Paco.Failure{} = failure, :raise), do: raise failure
  defp handle_failure(result, _), do: result
end
