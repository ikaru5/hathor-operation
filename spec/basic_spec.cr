require "./spec_helper"

describe TestOperationBasics do

  class TestOperation < Hathor::Operation

    property param : String | Nil
    property counter = 0

    def initialize(@param : String);end
    
    step some_step!
    step some_other_step
    step some_step!
    step some_step!
    step return_param!
    step some_step!

    def some_step!
      @counter += 1
      # puts "some_step: #{@counter}"
      true
    end

    def some_other_step
      @counter += 2
      # puts "some_other_step: #{@counter}"
      123
    end

    def return_param!
      @counter += 3
      # puts "return_param: #{@counter}"
      "test" == param
    end

  end

  test "it must run without data" do
    operation = TestOperation.run(param: "test")
    assert operation.success?
    assert operation.success?(:some_step!)
    assert operation.success?(:some_step!, :step)
    assert operation.failure?(:some_foo_step!, :step)
    assert operation.failure?(:some_foo_step!)
    assert !operation.failure?
    assert 9 == operation.counter
    assert 7 ==  operation.log.entries.size
    assert ({status: true, reason: "Start TestOperationBasicsTest::TestOperation", step: nil, step_type: nil, force: false, message: nil}) ==  operation.log.entries[0]
    assert ({status: true, reason: "step: some_step!", step: :some_step!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[1]
    assert ({status: true, reason: "step: some_other_step", step: :some_other_step, step_type: :step, force: false, message: nil}) ==  operation.log.entries[2]
    assert ({status: true, reason: "step: some_step!", step: :some_step!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[3]
    assert ({status: true, reason: "step: some_step!", step: :some_step!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[4]
    assert ({status: true, reason: "step: return_param!", step: :return_param!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[5]
    assert ({status: true, reason: "step: some_step!", step: :some_step!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[6]
    assert operation.log.to_s == operation.log.to_s(steps_only: true)
    assert operation.log.to_s.gsub("\n", " ") == operation.log.to_s(steps_only: true, one_line: true)

    # now let it fail on return_params!
    operation = TestOperation.run(param: "huihiu")
    assert !operation.success?
    assert operation.failure?
    assert 8 == operation.counter
    assert 6 ==  operation.log.entries.size
    assert ({status: true, reason: "Start TestOperationBasicsTest::TestOperation", step: nil, step_type: nil, force: false, message: nil}) ==  operation.log.entries[0]
    assert ({status: true, reason: "step: some_step!", step: :some_step!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[1]
    assert ({status: true, reason: "step: some_other_step", step: :some_other_step, step_type: :step, force: false, message: nil}) ==  operation.log.entries[2]
    assert ({status: true, reason: "step: some_step!", step: :some_step!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[3]
    assert ({status: true, reason: "step: some_step!", step: :some_step!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[4]
    assert ({status: false, reason: "step: return_param!", step: :return_param!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[5]
    assert operation.log.to_s == operation.log.to_s(steps_only: true)
    assert operation.log.to_s.gsub("\n", " ") == operation.log.to_s(steps_only: true, one_line: true)
  end

  class TestOperationWithPolicy < Hathor::Operation

    property param : Bool | Nil
    property other_param : Bool | Nil
    property counter = 0

    def initialize(@param : Bool, @other_param : Bool = true);end
    
    policy return_param!
    policy! return_other_param!
    step some_step!
    step return_param!
    failure some_step!
    success return_param!

    def some_step!
      @counter += 1
      # puts "some_step: #{@counter}"
      true
    end

    def some_other_step
      @counter += 2
      # puts "some_other_step: #{@counter}"
      123
    end

    def return_param!
      @counter += 3
      # puts "return_param: #{@counter}"
      param
    end

    def return_other_param!
      @log.add("Custom Message")
      @counter += 4
      # puts "return_other_param: #{@counter}"
      other_param
    end

  end

  test "policy and failure should act accordingly" do
    operation = TestOperationWithPolicy.run(param: true)
    assert operation.success?
    assert operation.success?(:return_param!, :policy)
    assert operation.success?(:return_param!)
    assert 14 == operation.counter
    assert 7 ==  operation.log.entries.size
    assert ({status: true, reason: "Start TestOperationBasicsTest::TestOperationWithPolicy", step: nil, step_type: nil, force: false, message: nil}) ==  operation.log.entries[0]
    assert ({status: true, reason: "policy: return_param!", step: :return_param!, step_type: :policy, force: false, message: nil}) ==  operation.log.entries[1]
    assert ({status: nil, reason: nil, force: nil, message: "Custom Message", step: nil, step_type: nil}) ==  operation.log.entries[2]
    assert ({status: true, reason: "strict_policy: return_other_param!", step: :return_other_param!, step_type: :strict_policy, force: false, message: nil}) ==  operation.log.entries[3]
    assert ({status: true, reason: "step: some_step!", step: :some_step!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[4]
    assert ({status: true, reason: "step: return_param!", step: :return_param!, step_type: :step, force: false, message: nil}) ==  operation.log.entries[5]
    assert ({status: true, reason: "success step: return_param! - finished with 'true'", step: :return_param!, step_type: :success, force: false, message: nil}) ==  operation.log.entries[6]
    assert operation.log.to_s != operation.log.to_s(steps_only: true)
    assert operation.log.to_s.gsub("\n", " ") == operation.log.to_s(one_line: true)

    # now let normal policy fail
    operation = TestOperationWithPolicy.run(param: false)
    assert operation.failure?
    assert operation.failure?(:return_param!)
    assert operation.failure?(:return_param!, :policy)
    assert 4 == operation.counter
    assert 3 ==  operation.log.entries.size
    assert ({status: true, reason: "Start TestOperationBasicsTest::TestOperationWithPolicy", step: nil, step_type: nil, force: false, message: nil}) ==  operation.log.entries[0]
    assert ({status: false, reason: "policy: return_param!", step: :return_param!, step_type: :policy, force: false, message: nil}) ==  operation.log.entries[1]
    assert ({status: false, reason: "failure step: some_step! - finished with 'true'", step: :some_step!, step_type: :failure, force: false, message: nil}) ==  operation.log.entries[2]
    assert operation.log.to_s == operation.log.to_s(steps_only: true)
    assert operation.log.to_s.gsub("\n", " ") == operation.log.to_s(one_line: true)

    # now let strict policy fail
    operation = TestOperationWithPolicy.run(param: true, other_param: false)
    assert operation.failure?
    assert 7 == operation.counter
    assert 4 ==  operation.log.entries.size
    assert ({status: true, reason: "Start TestOperationBasicsTest::TestOperationWithPolicy", step: nil, step_type: nil, force: false, message: nil}) ==  operation.log.entries[0]
    assert ({status: true, reason: "policy: return_param!", step: :return_param!, step_type: :policy, force: false, message: nil}) ==  operation.log.entries[1]
    assert ({status: nil, reason: nil, force: nil, message: "Custom Message", step: nil, step_type: nil}) ==  operation.log.entries[2]
    assert ({status: false, reason: "strict_policy: return_other_param!", step: :return_other_param!, step_type: :strict_policy, force: false, message: nil}) ==  operation.log.entries[3]
    assert operation.log.to_s != operation.log.to_s(steps_only: true)
    assert operation.log.to_s.gsub("\n", " ") == operation.log.to_s(one_line: true)
  end

  class TestInheritingMethodsParent < Hathor::Operation
    property counter = 0
    
    def some_step!
      @counter += 1
    end

    def some_other_step!
      @counter -= 10
    end
  end

  class TestInheritingMethods < TestInheritingMethodsParent
    step some_step!
    step some_other_step!

    def some_other_step!
      @counter += 5
    end
  end

  test "inherit methods of ancestor" do
    operation = TestInheritingMethods.run
    assert operation.success?
    assert 6 == operation.counter
    assert 3 == operation.log.entries.size
  end

end
