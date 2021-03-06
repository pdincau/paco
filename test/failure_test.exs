defmodule Paco.FailureTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, %{failure: %Paco.Failure{at: {0, 1, 1}, rank: 1}}}
  end

  test "format failure at the end of input", %{failure: failure} do
    failure = %Paco.Failure{failure|tail: "", expected: "a"}
    assert Paco.Failure.format(failure, :flat) ==
      ~s|expected "a" at 1:1 but got the end of input|
  end








  test "compose expectations" do
    {at, tail, rank} = {{1, 1, 2}, [{{1, 1, 2}, "c"}], 2}

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b"}])

    assert composed_failure.at == at
    assert composed_failure.tail == tail
    assert composed_failure.rank == rank
    assert composed_failure.expected == {:composed, ["a", "b"]}
  end

  test "compose can compose composed failures" do
    {at, tail, rank} = {{1, 1, 2}, [{{1, 1, 2}, "z"}], 2}

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b"}])
    composed_failure = Paco.Failure.compose([
      composed_failure,
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "c"}])
    assert composed_failure.expected == {:composed, ["a", "b", "c"]}

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "d"},
      composed_failure])
    assert composed_failure.expected == {:composed, ["d", "a", "b", "c"]}
  end

  test "format composed expectations" do
    {at, tail, rank} = {{1, 1, 2}, "c", 2}

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b"}])
    assert Paco.Failure.format(composed_failure, :flat) ==
           ~s|expected one of ["a", "b"] at 1:2 but got "c"|

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: {:re, ~r/a+/}}])
    assert Paco.Failure.format(composed_failure, :flat) ==
           ~s|expected one of ["a", ~r/a+/] at 1:2 but got "c"|

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: {:until, ["p"]}}])
    assert Paco.Failure.format(composed_failure, :flat) ==
           ~s|expected one of ["a", something ended by "p"] at 1:2 but got "c"|
  end

  test "compose keep the common stack" do
    {at, tail, rank} = {{1, 1, 2}, [{{1, 1, 2}, "c"}], 2}

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a", stack: ["A", "COMMON"]},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b", stack: ["B", "COMMON"]}])
    assert composed_failure.stack == ["COMMON"]

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a", stack: ["COMMON"]},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b", stack: ["B", "COMMON"]}])
    assert composed_failure.stack == ["COMMON"]

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a", stack: ["A", "COMMON"]},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b", stack: ["COMMON"]}])
    assert composed_failure.stack == ["COMMON"]
  end

  test "compose failures with same expectation" do
    {at, tail, rank} = {{1, 1, 2}, [{{1, 1, 2}, "z"}], 2}

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"}])
    assert composed_failure.expected == "a"

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b"}])
    composed_failure = Paco.Failure.compose([
      composed_failure,
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"}])
    assert composed_failure.expected == {:composed, ["a", "b"]}

    composed_failure = Paco.Failure.compose([
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "b"},
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"}])
    composed_failure = Paco.Failure.compose([
      composed_failure,
      %Paco.Failure{at: at, tail: tail, rank: rank, expected: "a"}])
    assert composed_failure.expected == {:composed, ["b", "a"]}
  end

  test "stack description", %{failure: failure} do
    failure = Paco.Failure.stack(failure, "a")
    assert failure.stack == ["a"]

    failure = Paco.Failure.stack(failure, "b")
    assert failure.stack == ["b", "a"]
  end

  test "do not stack same description twice in a row", %{failure: failure} do
    failure = failure
              |> Paco.Failure.stack("a")
              |> Paco.Failure.stack("a")

    assert failure.stack == ["a"]
  end

  test "stack same description when interleaved", %{failure: failure} do
    failure = failure
              |> Paco.Failure.stack("a")
              |> Paco.Failure.stack("b")
              |> Paco.Failure.stack("a")

    assert failure.stack == ["a", "b", "a"]
  end
end
