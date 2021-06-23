module Hathor
  module NestedMacro

    # This macro will generate all methods needed to execute nested operations.
    # It uses CLASS_CONFIG[:context][:nested] to generate the methods according to passed io options 
    macro __nested_defs
      {% if nil != CLASS_CONFIG[:context] && CLASS_CONFIG[:context][:nested] %}
        {% for step_index in (0..(CLASS_CONFIG[:context][:nested][:step_count] - 1)) %}
          {%
            step_name = CLASS_CONFIG[:context][:nested][:steps][step_index][:name_with_index]
            options = CLASS_CONFIG[:context][:nested][:steps][step_index][:options]
            operation_class = CLASS_CONFIG[:context][:nested][:steps][step_index][:class]

            input = options[:input]
            output = options[:output]
            sync = options[:sync]
            arguments = nil
          %}

          # io preparation

          # bring everything into a hash literal
          {% if input.is_a?(TupleLiteral) || input.is_a?(ArrayLiteral) %}
            {% tmp = {} of Nil => Nil %}
            {% for key in input %}
               {% tmp[key] = key %}
            {% end %}
            {% input = tmp %}
          {% end %}

          {% if output.is_a?(TupleLiteral) || output.is_a?(ArrayLiteral) %}
            {% tmp = {} of Nil => Nil %}
            {% for key in output %}
               {% tmp[key] = key %}
            {% end %}
            {% output = tmp %}
          {% end %}

          {% if sync.is_a?(TupleLiteral) || sync.is_a?(ArrayLiteral) %}
            {% tmp = {} of Nil => Nil %}
            {% for key in sync %}
               {% tmp[key] = key %}
            {% end %}
            {% sync = tmp %}
          {% end %}

          # check inputs and outputs for correct type
          {% if !(input.is_a?(NamedTupleLiteral) || input.is_a?(HashLiteral) || input.is_a?(NilLiteral)) %}
            {{ puts "[HathorOperation] You're passing an unsupported option to 'input' that will be ignored in #{@type.id}. (#{input})" }}
            {{ input = nil }}
          {% end %}

          {% if !(output.is_a?(NamedTupleLiteral) || output.is_a?(HashLiteral) || output.is_a?(NilLiteral)) %}
            {{ puts "[HathorOperation] You're passing an unsupported option to 'output' that will be ignored in #{@type.id}. (#{output})" }}
            {{ output = nil }}
          {% end %}

          # merge sync option to inputs and outputs
          {% if sync.is_a?(NamedTupleLiteral) || sync.is_a?(HashLiteral) %}
            {%
              input ||= {} of Nil => Nil
              output ||= {} of Nil => Nil
            %}
            {% for key, value in sync %}
              {% input[key] = value %}
              {% output[key] = value %}
            {% end %}
          {% elsif !sync.is_a?(NilLiteral) %}
            {{ puts "[HathorOperation] You're passing an unsupported option to 'sync' that will be ignored in #{@type.id}. (#{sync})" }}
          {% end %}


          # generate the step's method

          def {{step_name}}_run!
            # if input is not nil use it to generate properties for the nested operation
            {% if nil != input %}
              {% if input.size > 0 %}
                attributes = {
                  {% for key, value in input %}
                    {{key.id}}: self.{{value.id}}.dup,
                  {% end %}
                }
                operation = {{operation_class}}.new(**attributes)
              {% else %}
                operation = {{operation_class}}.new()
              {% end %}
            # otherwise use the nested operation's initialize method to get information
            # about possible input values
            {% else %}
              {%
                nested_type = operation_class.resolve
                if nested_type.has_method?("initialize")
                  arguments = nested_type.methods.select { |method| method.name == "initialize" }.first.args.select { |method| @type.has_method?(method.name) }
                else
                  arguments = [] of Nil
                end
              %}

              {% if arguments.size > 0 %}
                attributes = {
                  {% for method in arguments %}
                    {{method.name}}: self.{{method.name}}.dup,
                  {% end %}
                }
                operation = {{operation_class}}.new(**attributes)
              {% else %}
                operation = {{operation_class}}.new()
              {% end %}
            {% end %}

            # run the nested operation
            operation.run

            # if output is not nil use it to generate properties for the nested operation
            {% if nil != output %}
              {% for key, value in output %}
                self.{{value.id}} = operation.{{key.id}}
              {% end %}
            # otherwise use the nested operation's initialize method to get information
            {% else %}
              {% if arguments == nil %}
                {%
                  nested_type = operation_class.resolve
                  if nested_type.has_method?("initialize")
                    arguments = nested_type.methods.select { |method| method.name == "initialize" }.first.args.select { |method| @type.has_method?(method.name + "=") }
                  else
                    arguments = [] of Nil
                  end
                %}
              {% end %}

              {% if arguments.size > 0 %}
                {% for method in arguments %}
                  self.{{method.name}} = operation.{{method.internal_name}}
                {% end %}
              {% end %}
            {% end %}

            # make the nested operation accessable in the base operation
            self.{{step_name}} = operation
            # add the nested operation log to the base operation
            self.log.add(operation)

            operation.success?
          end
        {% end %}
      {% end %}
    end

  end
end