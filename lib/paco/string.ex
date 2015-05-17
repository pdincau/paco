defmodule Paco.String do
  import String

  @nl ["\x{000A}",         # LF:    Line Feed, U+000A
       "\x{000B}",         # VT:    Vertical Tab, U+000B
       "\x{000C}",         # FF:    Form Feed, U+000C
       "\x{000D}",         # CR:    Carriage Return, U+000D
       "\x{000D}\x{000A}", # CR+LF: CR (U+000D) followed by LF (U+000A)
       "\x{0085}",         # NEL:   Next Line, U+0085
       "\x{2028}",         # LS:    Line Separator, U+2028
       "\x{2029}"          # PS:    Paragraph Separator, U+2029
      ]

  Enum.each @nl, fn nl ->
    def newline?(<<unquote(nl)>>), do: true
  end
  def newline?(_), do: false

  def consume("", tail, to, at), do: {to, at, tail}
  def consume(_, "", _, _), do: :end_of_input
  def consume(expected, given, _to, at) do
    {h1, t1} = next_grapheme(expected)
    {h2, t2} = next_grapheme(given)
    case {h1, h2} do
      {h, h} -> consume(t1, t2, at, position_after(at, h))
      _ -> :error
    end
  end

  def seek(tail, to, at, len), do: seek("", tail, to, at, len)
  def seek(between, tail, to, at, 0), do: {between, tail, to, at}
  def seek(between, "", to, at, _), do: {between, "", to, at}
  def seek(between, tail, _, at, len) do
    {h, tail} = next_grapheme(tail)
    seek(between <> h, tail, at, position_after(at, h), len-1)
  end

  def line_at(text, at) do
    case String.at(text, at) do
      nil -> ""
      grapheme ->
        if (newline?(grapheme)) do
          collect_line_at(text, at - 1, &(&1 - 1))
          |> Enum.reverse
          |> Enum.join
        else
          collect_line_at(text, at - 1, &(&1 - 1))
          |> Enum.reverse
          |> Enum.concat([grapheme])
          |> Enum.concat(collect_line_at(text, at + 1, &(&1 + 1)))
          |> Enum.join
        end
    end
  end

  defp collect_line_at(text, at, next) do
    Stream.unfold(at, &collect_line_at_(text, &1, next)) |> Enum.to_list
  end

  defp collect_line_at_(_text, at, _next) when at < 0, do: nil
  defp collect_line_at_(text, at, next) do
    case String.at(text, at) do
      nil ->
        nil
      in_line ->
        if newline?(in_line) do
          nil
        else
          {in_line, next.(at)}
        end
    end
  end

  defp position_after({n, l, c}, grapheme) do
    if newline?(grapheme) do
      {n + 1, l + 1, 1}
    else
      {n + 1, l, c + 1}
    end
  end
end
