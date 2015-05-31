ExUnit.start()

defmodule Paco.Test.Helper do
  def streams_of(text) when is_binary(text), do: split(text) |> streams_of
  def streams_of([h]), do: [[h]]
  def streams_of([h|t]) do
    append = for p <- streams_of(t), do: [h|p]
    glue = for [ph|pt] <- streams_of(t), do: [h<>ph|pt]
    Enum.concat(append, glue)
  end

  defp split(text) when is_binary(text) do
    Stream.unfold(text, &String.next_grapheme/1)
    |> Enum.intersperse("")
    |> (&["", &1, ""]).()
    |> List.flatten
  end

  def assert_events_notified(parser, text, expected) do
    alias Paco.Test.EventRecorder
    {:ok, collector} = EventRecorder.start_link
    try do
      Paco.parse(parser, text, collector: collector)
      notified = EventRecorder.events_recorded(collector)
      do_assert_events_notified(notified, expected)
    after
      EventRecorder.stop(collector)
    end
  end

  defp do_assert_events_notified([], []), do: true
  defp do_assert_events_notified([], [_|_]=r) do
    ExUnit.Assertions.flunk "Some events were not notified:\n#{inspect(r)}"
  end
  defp do_assert_events_notified([hl|tl], [hl|tr]), do: do_assert_events_notified(tl, tr)
  defp do_assert_events_notified([_|tl], r), do: do_assert_events_notified(tl, r)
end

defmodule Paco.Test.EventRecorder do
  use GenEvent

  def start_link do
    {:ok, pid} = GenEvent.start_link()
    GenEvent.add_handler(pid, __MODULE__, [])
    {:ok, pid}
  end

  def events_recorded(pid) do
    GenEvent.call(pid, __MODULE__, :events)
  end

  def stop(pid) do
    GenEvent.stop(pid)
  end

  def handle_event(event, events) do
    {:ok, [event|events]}
  end

  def handle_call(:events, events) do
    {:ok, Enum.reverse(events), events}
  end
end
