defmodule PacoFormatTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  test "tagged format of success (default)" do
    assert {:ok, <<_::binary>>} = parse(lit("a"), "a", format: :tagged)
    assert {:ok, <<_::binary>>} = parse(lit("a"), "a")
  end

  test "tagged format of failure (default)" do
    assert {:error, <<_::binary>>} = parse(lit("a"), "b", format: :tagged)
    assert {:error, <<_::binary>>} = parse(lit("a"), "b")
  end

  test "flat format of success" do
    assert <<_::binary>> = parse(lit("a"), "a", format: :flat)
  end

  test "flat format of failure" do
    assert <<_::binary>> = parse(lit("a"), "b", format: :flat)
  end

  test "raw format of success" do
    assert %Paco.Success{} = parse(lit("a"), "a", format: :raw)
  end

  test "raw format of failure" do
    assert %Paco.Failure{} = parse(lit("a"), "b", format: :raw)
  end
end