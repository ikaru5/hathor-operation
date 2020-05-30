module Hathor
  class OperationLogger

    def initialize(operation_name = "")
      @entries = Array({ status: Bool | Nil, reason: String | Nil, force: Bool | Nil, message: String | Nil }).new
      @entries << { status: true, reason: "Start #{operation_name}", force: false, message: nil }
    end

    def add(status : Bool, reason : String, force : Bool)
      @entries << { status: status, reason: reason, force: force, message: nil }
    end

    def add(message : String)
      @entries << { status: nil, reason: nil, force: nil, message: message }
    end

    def entries(steps_only = false)
      if steps_only
        @entries.select { |entry| entry[:message].nil? }
      else
        @entries
      end
    end

    def to_s(one_line = false, steps_only = false)
      out = String.new
      entries(steps_only).each do |entry|
        if entry[:message].nil?
          if entry[:force]
            out += ">> #{entry[:reason]} => '#{entry[:status]}'\n"
          else
            out += ">> #{entry[:reason]} -> '#{entry[:status]}'\n"
          end
        else
          out += "log message: #{entry[:message]}\n"
        end
      end
      out += ">> Operation End"

      if one_line
        out.gsub("\n", " ")
      else
        out
      end
    end

  end
end