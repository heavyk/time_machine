# temporarily this is here. will be pulled out to another project soon as it's working properly

defprotocol TimeMachine.Encoder do
  @fallback_to_any true
  def encode(value)
end

# defimpl TimeMachine.Encoder, for: BitString do
#   def encode(value), do: "'" <> TestCompiler.escape(value) <> "'"
# end

defimpl TimeMachine.Encoder, for: Any do
  def encode(value), do: value
end

defimpl TimeMachine.Encoder, for: Tuple do
  def encode({ :safe, value }) when is_binary(value) do
    value
  end
  def encode(value) do
    case Macro.validate(value) do
      :ok -> value
      _ ->
        raise Protocol.UndefinedError, protocol: TimeMachine.Encoder, value: value
    end
  end
end

defimpl TimeMachine.Encoder, for: List do
  def encode(list) do
    Enum.reduce(list, "", fn value, acc ->
      acc <> TimeMachine.Encoder.encode(value)
    end)
  end
end

defimpl TimeMachine.Encoder, for: Atom do
  def encode(nil),   do: ""
  # def encode(value),  do: TestCompiler.escape(Atom.to_string(value))
  def encode(value),  do: Atom.to_string(value)
end

# @improve
# defimpl TimeMachine.Encoder, for: Integer do
#   def encode(value), do: Integer.to_string(value)
# end
#
# defimpl TimeMachine.Encoder, for: Float do
#   def encode(value), do: Float.to_string(value)
# end

defimpl TimeMachine.Encoder, for: Date do
  def encode(value), do: Date.to_string(value)
end

defimpl TimeMachine.Encoder, for: Time do
  def encode(value), do: Time.to_string(value)
end

defimpl TimeMachine.Encoder, for: DateTime do
  def encode(value), do: DateTime.to_string(value)
end

defimpl TimeMachine.Encoder, for: NaiveDateTime do
  def encode(value), do: NaiveDateTime.to_string(value)
end
