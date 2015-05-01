defmodule Paco.Test do
  use ExUnit.Case

  import Paco.Parser

  defmodule UsePacoLastParserIsTheRoot do
    use Paco

    parser aaa, do: string("aaa")
    parser bbb, do: string("bbb")
  end

  test "use paco, last parser is the root" do
    assert UsePacoLastParserIsTheRoot.parse("bbb") == {:ok, "bbb"}
  end


  defmodule UsePacoMarkRootWithRootMacro do
    use Paco

    root aaa
    parser aaa, do: string("aaa")
    parser bbb, do: string("bbb")
  end

  test "use paco, mark root with root macro" do
    assert UsePacoMarkRootWithRootMacro.parse("aaa") == {:ok, "aaa"}
  end


  defmodule UsePacoMarkRootWithRootMacroInline do
    use Paco

    root parser aaa, do: string("aaa")
    parser bbb, do: string("bbb")
  end

  test "use paco, mark root with root macro inline" do
    assert UsePacoMarkRootWithRootMacroInline.parse("aaa") == {:ok, "aaa"}
  end


  defmodule UsePacoReferenceOtherParsers do
    use Paco

    root parser all, do: seq([aaa, bbb])
    parser aaa, do: string("aaa")
    parser bbb, do: string("bbb")
  end

  test "use paco, reference other parsers" do
    assert UsePacoReferenceOtherParsers.parse("aaabbb") == {:ok, ["aaa", "bbb"]}
  end

  test "failures keeps the parsers name" do
    {:error, failure} = UsePacoReferenceOtherParsers.parse("aaaccc")
    assert Paco.Failure.format(failure) ==
      """
      Failed to match all at line: 1, column: 1, because it
      Failed to match bbb at line: 1, column: 4
      """
  end

end
