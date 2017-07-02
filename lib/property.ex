defmodule Property do
  defmodule Failure do
    defstruct [:exception, :stacktrace, :generated_values]
  end

  defmodule Success do
    defstruct [:generated_values]
  end

  def compile(clauses, block) do
    quote do
      var!(generated_values) = []
      unquote(compile_clauses(clauses, block))
    end
  end

  # Compiles the list of clauses to code that will execute those clauses. Note
  # that in the returned code, the "state" variable is available in the bindings
  # (as var!(state)). This is also valid for updating the state, which can be
  # done by assigning var!(state) = to_something.
  defp compile_clauses(clauses, block)

  defp compile_clauses([], block) do
    quote do
      generated_values = Enum.reverse(var!(generated_values))

      try do
        unquote(block)
      rescue
        exception in [ExUnit.AssertionError, ExUnit.MultiError] ->
          stacktrace = System.stacktrace()
          Stream.Data.fixed(%Failure{exception: exception, stacktrace: stacktrace, generated_values: generated_values})
      else
        _result ->
          Stream.Data.fixed(%Success{generated_values: generated_values})
      end
    end
  end

  defp compile_clauses([{:<-, _meta, [pattern, generator]} = clause | rest], block) do
    quote do
      Stream.Data.bind(unquote(generator), fn unquote(pattern) = generated_value ->
        var!(generated_values) = [{unquote(Macro.to_string(clause)), generated_value} | var!(generated_values)]
        unquote(compile_clauses(rest, block))
      end)
    end
  end

  defp compile_clauses([{:=, _meta, [_left, _right]} = assignment | rest], block) do
    quote do
      unquote(assignment)
      unquote(compile_clauses(rest, block))
    end
  end
end
