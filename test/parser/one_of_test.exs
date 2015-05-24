defmodule Paco.Parser.OneOfTest do
  use ExUnit.Case, async: true

  import Paco
  import Paco.Parser

  alias Paco.Test.Helper

  test "parse one of the parsers" do
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "a") == {:ok, "a"}
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "b") == {:ok, "b"}
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "c") == {:ok, "c"}
    assert parse(one_of([lit("a")]), "a") == {:ok, "a"}
  end

  test "doesn't need to consume all the text" do
    assert parse(one_of([lit("a"), lit("b"), lit("c")]), "abc") == {:ok, "a"}
  end

  test "always fails with no parsers" do
    assert parse(one_of([]), "a") == {:error,
      """
      Failed to match one_of() at 1:1
      """
    }
  end

  test "describe" do
    assert describe(one_of([lit("a")])) == ~s|one_of([lit("a")])|
    assert describe(one_of([lit("a"), lit("b")])) == ~s|one_of([lit("a"), lit("b")])|
  end

  test "skipped parsers should be removed from result" do
    assert parse(one_of([lit("a"), skip(lit("b"))]), "a") == {:ok, "a"}
    assert parse(one_of([lit("a"), skip(lit("b"))]), "b") == {:ok, []}
  end

  test "fail to parse" do
    assert parse(one_of([lit("a"), lit("b")]), "c") == {:error,
      """
      Failed to match one_of([lit("a"), lit("b")]) at 1:1
      """
    }
  end

  test "notify events on success because first succeeded" do
    Helper.assert_events_notified(one_of([lit("a"), lit("b")]), "a", [
      {:started, ~s|one_of([lit("a"), lit("b")])|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
    ])
  end

  test "notify events on success because last succeeded" do
    Helper.assert_events_notified(one_of([lit("a"), lit("b")]), "b", [
      {:started, ~s|one_of([lit("a"), lit("b")])|},
      {:matched, {0, 1, 1}, {0, 1, 1}, {1, 1, 2}},
    ])
  end

  test "notify events on failure" do
    Helper.assert_events_notified(one_of([lit("a"), lit("b")]), "c", [
      {:started, ~s|one_of([lit("a"), lit("b")])|},
      {:failed, {0, 1, 1}},
    ])
  end

  test "do not consume input with a failure" do
    parser = one_of([lit("a"), lit("b")])
    failure = parser.parse.(Paco.State.from("c"), parser)
    assert failure.at == {0, 1, 1}
    assert failure.tail == "c"
  end
end
