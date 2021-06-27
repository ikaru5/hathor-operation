module Hathor
  class OperationLogger

    def initialize(operation_name = "")
      @entries = Array(
        {
          status: Bool | Nil,
          reason: String | Nil,
          step: Symbol | Nil,
          step_type: Symbol | Nil,
          force: Bool | Nil,
          message: String | Nil,
          logger: OperationLogger | Nil
        }
      ).new
      @entries << { status: true, reason: "Start #{operation_name}", force: false, message: nil, step: nil, step_type: nil, logger: nil }
    end

    def add(status : Bool, reason : String, force : Bool)
      @entries << { status: status, reason: reason, force: force, step: nil, step_type: nil, message: nil, logger: nil }
    end

    def add(status : Bool, reason : String, step : Symbol, step_type : Symbol, force : Bool)
      @entries << { status: status, reason: reason, step: step, step_type: step_type, force: force, message: nil, logger: nil }
    end

    def add(message : String)
      @entries << { status: nil, reason: nil, force: nil, step: nil, step_type: nil, message: message, logger: nil }
    end

    def add(operation : Operation)
      @entries << { status: nil, reason: nil, force: nil, step: nil, step_type: nil, message: nil, logger: operation.log }
    end

    def entries(steps_only = false)
      if steps_only
        @entries.select { |entry| entry[:message].nil? }
      else
        @entries
      end
    end

    def success?(step_name : Symbol, step_type : Symbol | Nil = nil)
      @entries.each do |entry|
        if (nil == step_type || entry[:step_type] == step_type) && entry[:step] == step_name
          return entry[:status] || false
        end
      end
      return false
    end

    def failure?(step_name : Symbol, step_type : Symbol | Nil = nil)
      !success?(step_name, step_type)
    end

    def to_s(one_line = false, steps_only = false)
      out = String.new
      entries(steps_only).each do |entry|
        if entry[:message]
          out += "log message: #{entry[:message]}\n"
        elsif logger = entry[:logger]
          out += "\t"
          out += logger.to_s.gsub("\n", "\n\t")
          out += "\n"
        else
          if entry[:force]
            out += ">> #{entry[:reason]} => '#{entry[:status]}'\n"
          else
            out += ">> #{entry[:reason]} -> '#{entry[:status]}'\n"
          end
        end
      end
      out += ">> Operation End"

      if one_line
        out.gsub("\n", " ")
      else
        out
      end
    end
    
    def to_s(io : IO)
      io << to_s
    end

  end
end