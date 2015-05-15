defmodule Paco.Parser do
  import Paco.Helper

  defstruct id: nil, name: nil, combine: nil, parse: nil

  def from(%Paco.Parser{} = p), do: p
  def from(%Regex{} = r), do: regex(r)

  defp notify(nil, _what), do: :ok
  defp notify(collector, what), do: GenEvent.notify(collector, what)


  parser_ maybe(%Paco.Parser{} = parser) do
    fn %Paco.State{at: at, text: text, collector: collector} = state, this ->
      notify(collector, {:started, Paco.describe(this)})
      case parser.parse.(state, parser) do
        %Paco.Success{from: from, to: to, at: at} = success ->
          notify(collector, {:matched, from, to, at})
          success
        %Paco.Failure{} ->
          notify(collector, {:matched, at, at, at})
          %Paco.Success{from: at, to: at, at: at, tail: text, skip: true}
      end
    end
  end

  parser_ skip(%Paco.Parser{} = parser) do
    fn %Paco.State{} = state, _this ->
      case parser.parse.(state, parser) do
        %Paco.Success{} = success ->
          %Paco.Success{success | skip: true}
        %Paco.Failure{} = failure ->
          failure
      end
    end
  end

  parser_ sequence_of([]) do
    raise ArgumentError, message: "Must give at least one parser to sequence_of combinator"
  end
  parser_ sequence_of(parsers) do
    fn %Paco.State{at: from, collector: collector} = state, this ->
      notify(collector, {:started, Paco.describe(this)})
      result = Enum.reduce(parsers, {state, from, []},
                           fn
                             (%Paco.Parser{} = parser, {state, _, results}) ->
                               case parser.parse.(state, parser) do
                                 %Paco.Success{to: to, at: at, tail: tail, skip: true} ->
                                   {%Paco.State{state | at: at, text: tail}, to, results}
                                 %Paco.Success{to: to, at: at, tail: tail, result: result} ->
                                   {%Paco.State{state | at: at, text: tail}, to, [result|results]}
                                 %Paco.Failure{} = failure ->
                                   failure
                               end
                             (_, %Paco.Failure{} = failure) ->
                               failure
                           end)

      case result do
        {%Paco.State{at: at, text: text}, to, results} ->
          notify(collector, {:matched, from, to, at})
          %Paco.Success{from: from, to: to, at: at, tail: text, result: Enum.reverse(results)}
        %Paco.Failure{} = failure ->
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, what: Paco.describe(this), because: failure}
      end
    end
  end

  parser_ one_of([]), do: (raise ArgumentError, message: "Must give at least one parser to one_of combinator")
  parser_ one_of([parser]), do: parser
  parser_ one_of(parsers) do
    fn %Paco.State{at: from, collector: collector} = state, this ->
      notify(collector, {:started, Paco.describe(this)})
      result = Enum.reduce(parsers, [],
                           fn
                             (_, %Paco.Success{} = success) ->
                               success
                             (%Paco.Parser{} = parser, failures) ->
                               case parser.parse.(state, parser) do
                                 %Paco.Success{} = success ->
                                   success
                                 %Paco.Failure{} = failure ->
                                   [failure | failures]
                               end
                           end)

      case result do
        %Paco.Success{from: from, to: to, at: at} = success ->
          notify(collector, {:matched, from, to, at})
          success
        _ ->
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, what: Paco.describe(this)}
      end
    end
  end

  parser_ regex(r, opts \\ []) do
    fn %Paco.State{at: from, text: text, collector: collector, stream: stream} = state, this ->
      description = Paco.describe(this)
      case Regex.run(anchor(r), text, return: :index) do
        [{_, len}] ->
          {s, tail, to, at} = seek(text, from, from, len)
          notify(collector, {:started, description})
          notify(collector, {:matched, from, to, at})
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: s}
        [{_, len}|captures] ->
          {s, tail, to, at} = seek(text, from, from, len)
          captures = case Regex.names(r) do
            [] -> captures |> Enum.map(fn({from, len}) -> String.slice(text, from, len) end)
            _ -> [Regex.named_captures(r, text)]
          end
          notify(collector, {:started, description})
          notify(collector, {:matched, from, to, at})
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: [s|captures]}
        nil when is_pid(stream) ->
          wait_for = Keyword.get(opts, :wait_for, 1_000)
          if String.length(text) >= wait_for do
            notify(collector, {:started, description})
            notify(collector, {:failed, from})
            %Paco.Failure{at: from, what: description}
          else
            send(stream, {self, :more})
            receive do
              {:load, more_text} ->
                this.parse.(%Paco.State{state|text: text <> more_text}, this)
              :halt ->
                notify(collector, {:started, description})
                notify(collector, {:failed, from})
                %Paco.Failure{at: from, what: description}
            end
          end
        nil ->
          notify(collector, {:started, description})
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, what: description}
      end
    end
  end

  parser_ literal(s) do
    fn %Paco.State{at: from, text: text, collector: collector, stream: stream} = state, this ->
      description = Paco.describe(this)
      case consume(s, text, from, from) do
        {to, at, tail} ->
          notify(collector, {:started, description})
          notify(collector, {:matched, from, to, at})
          %Paco.Success{from: from, to: to, at: at, tail: tail, result: s}
        :end_of_input when is_pid(stream) ->
          send(stream, {self, :more})
          receive do
            {:load, more_text} ->
              notify(collector, {:loaded, more_text})
              this.parse.(%Paco.State{state|text: text <> more_text}, this)
            :halt ->
              notify(collector, {:started, description})
              notify(collector, {:failed, from})
              %Paco.Failure{at: from, what: description}
          end
        _ ->
          notify(collector, {:started, description})
          notify(collector, {:failed, from})
          %Paco.Failure{at: from, what: description}
      end
    end
  end


  def label(parser, name) do
    %Paco.Parser{
      name: name,
      combine: [],
      parse: fn %Paco.State{} = state, _this ->
               case parser.parse.(state, parser) do
                 %Paco.Success{} = success ->
                   success
                 %Paco.Failure{} = failure ->
                   %Paco.Failure{failure | what: name}
               end
             end}
  end



  @nl ["\x{000A}",         # LF:    Line Feed, U+000A
       "\x{000B}",         # VT:    Vertical Tab, U+000B
       "\x{000C}",         # FF:    Form Feed, U+000C
       "\x{000D}",         # CR:    Carriage Return, U+000D
       "\x{000D}\x{000A}", # CR+LF: CR (U+000D) followed by LF (U+000A)
       "\x{0085}",         # NEL:   Next Line, U+0085
       "\x{2028}",         # LS:    Line Separator, U+2028
       "\x{2029}"          # PS:    Paragraph Separator, U+2029
      ]

  defp seek(tail, to, at, len), do: seek("", tail, to, at, len)
  defp seek(between, tail, to, at, 0), do: {between, tail, to, at}
  Enum.each @nl, fn nl ->
    defp seek(between, <<unquote(nl)::utf8, tail::binary>>, _, {n, l, _} = at, len) do
      seek(between <> unquote(nl), tail, at, {n+1, l+1, 1}, len-1)
    end
  end
  defp seek(between, <<h::utf8, tail::binary>>, _, {n, l, c} = at, len) do
    seek(between <> <<h>>, tail, at, {n+1, l, c+1}, len-1)
  end

  Enum.each @nl, fn nl ->
    defp consume(<<unquote(nl)::utf8, t1::binary>>,
                 <<unquote(nl)::utf8, t2::binary>>,
                 _to, {n, l, _} = at) do
      consume(t1, t2, at, {n + 1, l + 1, 1})
    end
  end
  defp consume(<<h::utf8, t1::binary>>,
               <<h::utf8, t2::binary>>,
               _to, {n, l, c} = at) do
    consume(t1, t2, at, {n + 1, l, c + 1})
  end
  defp consume("", tail, to, at), do: {to, at, tail}
  defp consume(_, "", _, _), do: :end_of_input
  defp consume(_, _, _, _), do: :failure

  defp anchor(r) do
    source = Regex.source(r)
    if String.starts_with?(source, "\\A") do
      r
    else
      {:ok, r} = Regex.compile("\\A#{source}")
      r
    end
  end
end

defimpl Inspect, for: Paco.Parser do
  import Inspect.Algebra
  alias Inspect.Opts

  def inspect(%Paco.Parser{id: nil, name: name, combine: []}, _opts), do: "#{name}"
  def inspect(%Paco.Parser{id: nil, name: name, combine: nil}, _opts), do: "#{name}"
  def inspect(%Paco.Parser{id: nil, name: name}, %Opts{width: 0}), do: "#{name}"
  def inspect(%Paco.Parser{id: nil, name: name, combine: args}, opts) do
    concat ["#{name}", surround_many("(", args, ")", %Opts{opts|width: 0}, &to_doc/2)]
  end
  def inspect(%Paco.Parser{id: id, name: name, combine: []}, _opts), do: "#{name}##{id}"
  def inspect(%Paco.Parser{id: id, name: name, combine: nil}, _opts), do: "#{name}##{id}"
  def inspect(%Paco.Parser{id: id, name: name}, %Opts{width: 0}), do: "#{name}##{id}"
  def inspect(%Paco.Parser{id: id, name: name, combine: args}, opts) do
    concat ["#{name}##{id}", surround_many("(", args, ")", %Opts{opts|width: 0}, &to_doc/2)]
  end
end
