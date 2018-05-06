# defmodule TimeMachine.InternalBadnessError do
#   defexception []
#   def exception() do
#
#   end
# end

# defmodule TimeMachine.IncompatibleAwesomenessError do
#   defexception []
#   def exception() do
#
#   end
# end

defmodule TemplateCompileError do
  defexception [:message, :file, :line]
  @errors [
    unspcified: {"unable to compile template", "..."},
    cannot_define: {"cannot define things in a template",
                    "use a panel to create a new 'environment', which things can be defined"}
  ]

  def exception(meta) do
    meta = cond do
      is_tuple(meta) -> [err: meta]
      is_binary(meta) -> [err: {meta, ""}]
      is_list(meta) -> meta
      true -> raise "cannot raise invalid param to #{__MODULE__}"
    end
    line = Keyword.get(meta, :line)
    file = case Keyword.get(meta, :file) do
      nil ->
        pinfo = Process.info(self())
        Keyword.get(pinfo[:dictionary], :elixir_compiler_file)
      v -> v
    end
    err = Keyword.get(meta, :err)
    {message, suggestion} =
      cond do
        is_tuple(err) -> err
        true -> Keyword.get(@errors, err, :unspcified)
      end
    msg = case file do
      nil -> "#{message}\n    #{suggestion}\n\n"
      _ -> """
        #{message}
            #{suggestion}

        ---  #{file}:#{line}
        #{ErrorHelpers.print_relevant_lines(file, line)}
        ---
        """
    end
    %TemplateCompileError{file: file, line: line, message: msg}
  end
end

defmodule ErrorHelpers do
  def print_relevant_lines(file, the_line, lines_of_ctx \\ 2) do
    start_line = the_line - lines_of_ctx
    end_line = the_line + lines_of_ctx
    File.stream!(file)
    |> Stream.map(&String.trim_trailing/1)
    |> Stream.with_index
    |> Stream.filter(fn {_, index} ->
      idx = index + 1
      idx <= end_line and idx >= start_line
    end)
    |> Stream.map(fn {line, index} ->
      idx = index + 1
      cond do
        idx == the_line ->
          "#{idx}:* #{line}" |> Colors.bold |> Colors.red
        idx <= end_line and idx >= start_line ->
          "#{idx}:  #{line}"
        true -> ""
      end
    end)
    |> Enum.to_list
    |> Enum.join("\n")
  end

  # this doesn't really work in its current incarnation, because the ast has already been transformed significantly
  # so, blk has nothing to do now with block
  def reveal_block(block, blk, color \\ &Colors.red/1) do
    b = Macro.to_string(blk)
    bb = b |> Colors.bold() |> color.()
    Macro.to_string(block)
    |> String.replace(b, bb)
  end
end
