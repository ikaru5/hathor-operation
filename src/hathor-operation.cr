require "./operation_logger"
require "./nested_macro"

module Hathor
  class Operation

    # inherited hook will run on AST entry (the very first thing of macros)
    macro inherited
      # The following hash CLASS_CONFIG saves all information about the steps and given options.
      # So its the "operation class config".
      # This variable is available during AST node parsing.
      # Thanks to inherited hook it is @type.id class related and not super class.
      CLASS_CONFIG = {} of Nil => Nil

      # The following hash STEPS_TO_GENERATES saves all information about steps that should be added
      # in result to using a nested operation.
      # It's used to generate step methods in the __process macro. (see Hathor::NestedMacro)
      STEPS_TO_GENERATE = {} of Nil => Nil

      # Finished hook is the last thing of AST node parsing.
      # By putting it inside inherited macro, we ensure that it will be run after simple macros are over and
      # only for the @type.id class. So this is THE REALLY LAST THING OF AST.
      macro finished
        __process
      end
    end

    macro step(method, **options)
      {% if method.is_a?(Path) %}
        {%
          step_name = method.id.underscore.gsub(/:/, "_")

          if nil == STEPS_TO_GENERATE[:context]
            STEPS_TO_GENERATE[:context] = {} of Nil => Nil
            STEPS_TO_GENERATE[:context][:step_count] = 0
            STEPS_TO_GENERATE[:context][:generated_methods] = [] of Nil
            STEPS_TO_GENERATE[:context][:steps] = [] of Nil
          end

          current_idx = STEPS_TO_GENERATE[:context][:steps].select { |step| step == step_name }.size
          STEPS_TO_GENERATE[:context][:steps] << step_name
          if current_idx != 0
            step_name = "#{step_name}_#{(current_idx + 1)}".id
          end

          STEPS_TO_GENERATE[:context][:step_count] = STEPS_TO_GENERATE[:context][:step_count] + 1
          step_count = STEPS_TO_GENERATE[:context][:step_count]
          STEPS_TO_GENERATE[step_count] = {} of Nil => Nil

          STEPS_TO_GENERATE[step_count][:step_name] = step_name
          STEPS_TO_GENERATE[step_count][:class] = method
          STEPS_TO_GENERATE[step_count][:options] = options
        %}

        property! {{step_name}} : {{method}}

        {%
          method = step_name + "_run!"
          STEPS_TO_GENERATE[:context][:generated_methods] << method
        %}
      {% end %}

      {%
        if nil == CLASS_CONFIG[:context]
          CLASS_CONFIG[:context] = {} of Nil => Nil
          CLASS_CONFIG[:context][:step_count] = 0
        end
      %}
      {%
        step_type = options[:step_type] || :step
        CLASS_CONFIG[:context][:step_count] = CLASS_CONFIG[:context][:step_count] + 1
        step_count = CLASS_CONFIG[:context][:step_count]

        CLASS_CONFIG[step_count] = {} of Nil => Nil
        CLASS_CONFIG[step_count][:method] = method.id
        CLASS_CONFIG[step_count][:step_type] = step_type
      %}
    end

    macro failure(method, **options)
      step({{method}}, step_type: :failure, {{**options}})
    end

    macro success(method, **options)
      step({{method}}, step_type: :success, {{**options}})
    end

    macro policy(method, **options)
      step({{method}}, step_type: :policy, {{**options}})
    end

    macro policy!(method, **options)
      step({{method}}, step_type: :strict_policy, {{**options}})
    end

    # things that have to be done at the end of AST, after field macro populated PROPERTIES-Hash
    macro __process
      # include Hathor::OperationLogger
      include Hathor::NestedMacro

      property status = true
      property log = Hathor::OperationLogger.new({{@type.id}})

      def success?
        @status
      end

      def success?(step_name : Symbol, step_type : Symbol | Nil = nil)
        @log.success?(step_name, step_type)
      end

      def failure?
        !success?
      end

      def failure?(step_name : Symbol, step_type : Symbol | Nil = nil)
        @log.failure?(step_name, step_type)
      end

      def self.run(*args, **options)
        instance = self.new(*args, **options)
        instance.run()
      end

      def update_operation_state(new_status : Bool, log_reason = "updated without submitting reason", force = false)
        if force
          @status = new_status
        else
          @status = @status && new_status
        end

        @log.add(@status, log_reason, force)
      end

      def update_operation_state(new_status : Bool, step : Symbol, step_type : Symbol, log_reason = "updated without submitting reason",
          force : Bool = false)
        if force
          @status = new_status
        else
          @status = @status && new_status
        end

        @log.add(@status, log_reason, step, step_type, force)
      end

      private def log(message : String)
        @log.add(message)
      end

      # define nested steps (see Hathor::NestedMacro)
      __nested_defs

      def run
        {% if nil != CLASS_CONFIG[:context] %}
          {% for step_index in (1..CLASS_CONFIG[:context][:step_count]) %}
            # raise if step calling an undefined method
            {% if !@type.has_method?(CLASS_CONFIG[step_index][:method]) &&
                !STEPS_TO_GENERATE[:context][:generated_methods].includes?(CLASS_CONFIG[step_index][:method]) %}
              {% raise "#{@type.id}: calling undefined method '#{CLASS_CONFIG[step_index][:method]}' in a #{CLASS_CONFIG[step_index][:step_type]} macro" %}
            {% end %}

            {% if [:policy, :step].includes? CLASS_CONFIG[step_index][:step_type] %}
              if success?
                ret_val = {{CLASS_CONFIG[step_index][:method]}}
                new_status = !(ret_val.nil? || false == ret_val)
                update_operation_state(
                  new_status,
                  :{{CLASS_CONFIG[step_index][:method].id}},
                  :{{CLASS_CONFIG[step_index][:step_type].id}},
                  "{{CLASS_CONFIG[step_index][:step_type].id}}: {{CLASS_CONFIG[step_index][:method]}}"
                )
              end
            {% end %}
            {% if :strict_policy == CLASS_CONFIG[step_index][:step_type] %}
              if success?
                ret_val = {{CLASS_CONFIG[step_index][:method]}}
                new_status = !(ret_val.nil? || false == ret_val)
                update_operation_state(
                  new_status,
                  :{{CLASS_CONFIG[step_index][:method].id}},
                  :{{CLASS_CONFIG[step_index][:step_type].id}},
                  "{{CLASS_CONFIG[step_index][:step_type].id}}: {{CLASS_CONFIG[step_index][:method]}}"
                )
                return self if ret_val.nil? || ret_val == false
              end
            {% end %}
            {% if :success == CLASS_CONFIG[step_index][:step_type] %}
              if success?
                ret_val = {{CLASS_CONFIG[step_index][:method]}}
                update_operation_state(
                  true,
                  :{{CLASS_CONFIG[step_index][:method].id}},
                  :{{CLASS_CONFIG[step_index][:step_type].id}},
                  "success step: {{CLASS_CONFIG[step_index][:method]}} - finished with '#{ret_val}'"
                )
              end
            {% end %}
            {% if :failure == CLASS_CONFIG[step_index][:step_type] %}
              if failure?
                ret_val = {{CLASS_CONFIG[step_index][:method]}}
                update_operation_state(
                  true,
                  :{{CLASS_CONFIG[step_index][:method].id}},
                  :{{CLASS_CONFIG[step_index][:step_type].id}},
                  "failure step: {{CLASS_CONFIG[step_index][:method]}} - finished with '#{ret_val}'"
                )
              end
            {% end %}
          {% end %}
        {% end %}
        return self
      end

    end

  end
end