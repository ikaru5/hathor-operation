require "./spec_helper"

describe NestedOperations do

  class Base < Hathor::Operation
    property a, b, c, d, e, f, g, success

    def initialize(@a = "a", @b = "b", @c = "c", @d = "d", @e = "e", @f = "f", @g = "g", @success = true); end

    step pass?

    def pass?
      self.success
    end
  end


  class DifferentSteps < Hathor::Operation
    property success = false
    # we need to pass empty input and output because otherwise the automagic would happen
    step Base, input: [] of Nil, output: [] of Nil
    success Base, input: { success: success }
    policy Base, input: { success: success }
    failure Base, input: [] of Nil
  end

  test "use different step types for nested operations" do
    result = DifferentSteps.run
    assert result.failure?
    assert result.base_2.failure?
    assert result.base.success?
    assert result.base_3.failure?
    assert result.base_4.success?
  end

  class NamedTuple < Hathor::Operation
    property x = "x"
    property y = "y"

    step Base, input: { a: x, c: y }, output: { c: x, b: y }
  end

  test "allow inputs and outputs as named tuples" do
    result = NamedTuple.run
    assert result.success?
    assert "y" == result.x
    assert "b" == result.y

    assert result.base.success?
    assert "x", result.base.a
    assert "y", result.base.c
  end

  class Hash < Hathor::Operation
    property x = "x"
    property y = "y"

    step Base, input: { "a" => x, "c" => y }, output: { :c => x, b => y }
  end

  test "allow inputs and outputs as hash" do
    result = Hash.run
    assert result.success?
    assert "y" == result.x
    assert "b" == result.y

    assert result.base.success?
    assert "x", result.base.a
    assert "y", result.base.c
  end

  class Tuple < Hathor::Operation
    property a = "x"
    property b = "y"
    property c = ""

    step Base, input: { a, b }, output: { c }
  end

  test "allow inputs and outputs as tuples" do
    result = Tuple.run
    assert result.success?
    assert "c" == result.c

    assert result.base.success?
    assert "x", result.base.a
    assert "y", result.base.b
  end

  class Array < Hathor::Operation
    property a = "x"
    property b = "y"
    property c = ""

    step Base, input: { "a", :b }, output: { c }
  end

  test "allow inputs and outputs as array" do
    result = Array.run
    assert result.success?
    assert "c" == result.c

    assert result.base.success?
    assert "x", result.base.a
    assert "y", result.base.b
  end

  class FromInitializer < Hathor::Operation
    property a = "z"
    property b = ""
    property success = true
    property g = "h"

    step Base, output: [] of Nil
    success flip_success!
    success Base
    success flip_success!
    step Base, input: [:a, :g, :success]

    def flip_success!
      self.success = !self.success
    end
  end

  test "read inputs and outputs from initializer" do
    result = FromInitializer.run
    assert result.success?
    assert result.base.success?
    assert "z" == result.base.a
    assert "" == result.base.b
    assert "h" == result.base.g

    assert result.base_2.failure?
    assert "z" == result.base_2.a
    assert "" == result.base_2.b
    assert "h" == result.base_2.g

    assert result.base_3.success?
    assert "z" == result.base_3.a
    assert "b" == result.base_3.b
    assert "h" == result.base_3.g
    assert "b" == result.b
  end

  class AddOne < Hathor::Operation
    property! x : Int32

    def initialize(@x); end

    step increment!

    def increment!
      self.x += 1
    end
  end

  class SyncTuple < Hathor::Operation
    property x = 1
    step AddOne, sync: {x}, input: [] of Nil, output: [] of Nil
  end

  test "using sync with tuple" do
    result = SyncTuple.run
    assert result.success?
    assert 2 == result.add_one.x
    assert 2 == result.x
  end

  class SyncArray < Hathor::Operation
    property x = 1
    step AddOne, sync: [x], input: [] of Nil, output: [] of Nil
  end

  test "using sync with array" do
    result = SyncArray.run
    assert result.success?
    assert 2 == result.add_one.x
    assert 2 == result.x
  end

  class SyncNamedTuple < Hathor::Operation
    property y = 1
    step AddOne, sync: { x: y }, input: [] of Nil, output: [] of Nil
  end

  test "using sync with named tuple" do
    result = SyncNamedTuple.run
    assert result.success?
    assert 2 == result.add_one.x
    assert 2 == result.y
  end

  class SyncHash < Hathor::Operation
    property y = 1
    step AddOne, sync: { :x => y }, input: [] of Nil, output: [] of Nil
  end

  test "using sync with hash" do
    result = SyncHash.run
    assert result.success?
    assert 2 == result.add_one.x
    assert 2 == result.y
  end

  class SyncWithOthers < Hathor::Operation
    property a = "f", x = "x"
    property! c : String

    step Base, sync: { b: a }, input: { a: x }, output: { c }
  end

  test "using sync in combination with other ios" do
    result = SyncWithOthers.run
    assert result.success?
    assert result.base.success?

    assert "f" == result.a
    assert "f" == result.base.b

    assert "x" == result.x
    assert "x" == result.base.a

    assert "c" == result.c
  end

  class Logger < Hathor::Operation
    step Base
  end

  test "build logger recursively" do
    result = Logger.run
    assert result.success?
    log = result.log
    assert 3 == log.entries.size
    assert({status: nil, reason: nil, step: nil, step_type: nil, force: nil, message: nil, logger: result.base.log} == log.entries[1])
    messages = log.to_s.split("\n")
    result.base.log.to_s.split("\n").each do |message|
      assert(messages.includes?("\t" + message))
    end
  end

end