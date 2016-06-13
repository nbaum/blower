
class Object

  # Yield with temporary instance variable assignments.
  # @param [Hash] bindings A hash of instance variable names to their temporary values.
  # @return Whatever yielding returns
  # @example Time
  #  @foo = 1
  #  let :@foo => 2 do
  #    puts @foo        #=> outputs 2
  #  end
  #  puts @foo          #=> outputs 1
  def let (bindings)
    old_values = bindings.keys.map do |key|
      instance_variable_get(key)
    end
    bindings.each do |key, value|
      instance_variable_set(key, value)
    end
    yield
  ensure
    return unless old_values
    bindings.keys.each.with_index do |key, i|
      instance_variable_set(key, old_values[i])
    end
  end

end
