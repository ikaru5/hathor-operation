# Hathor Operation

Structuring complex procedures within an instance. Push up readability and maintainability!

Inspired by Ruby [Trailblazer](http://trailblazer.to) Operations.

- [About](#about)
- [Hathor Contracts](#hathor-contracts)
- [Installation](#installation)
- [Usage](#usage)
- [Goals](#goals)
- [result, params and other args](#result-params-and-other-args)
- [Inheritance](#inheritance)
- [Class API](#class-api)
- [Instance API](#instance-api)
    - [success?](#success-method)
    - [success?(:step, :step_type)](#success-step-method)
    - [failure?](#failure-method)
    - [failure?(:step, :step_type)](#failure-step-method)
    - [log](#log)
    - [update_operation_state](#update_operation_state)
    - [run](#run)
- [Macros](#macros)
    - [step](#step)
    - [failure](#failure)
    - [success](#success)
    - [policy](#policy)
    - [policy!](#strict-policy)
- [Operation Logger](#operation-logger)
    - [Access the logs!](#access-the-logs)
        - [entries](#entries)
        - [success?(:step, :step_type)](#logger-success-step-method)
        - [failure?(:step, :step_type)](#logger-failure-step-method)
        - [to_s](#to_s)
    - [Custom Messages](#custom-messages)
- [Development](#development)
- [Contributing](#contributing)
- [Contributors and Contact](#contributors-and-contact)
- [Thanks](#thanks)
- [Copyright](#copyright)

## About

If you are coming from the Ruby and Rails world, you probably heard of or used Trailblazer.
It adds an additional abstraction level to encapsulate your business code from the framework and adds nice
syntactic sugar.

On MVC you often may run into the question: "Does this complex procedure go into the controller or the model?"
Operations are the answer to this!
Keep your business code out of framework dependency and write it in a beautiful and readable way.

## Hathor Contracts

If you are looking for Trailblazer-like Contracts or Representers, you may also have a look at [Hathor Contracts](https://github.com/ikaru5/hathor-contract).
The shards are decoupled and have no dependencies to each other.

## Installation

Add this to your application's `shard.yml`:

```yaml
  hathor-operation:
    github: ikaru5/hathor-operation
    version: ~> 0.2.1
```

## Usage

```crystal
require "hathor-operation" # to avoid this every time, create a base class and inherit from it

class World::Create < Hathor::Operation
  property model : World | Nil
  property size_x : Int32
  property size_y : Int32

  def initialize(@size_x : Int32, @size_y : Int32); end

  policy! enough_ressources? # strict policy -> if it fails operation will stop there
  policy permitted? # simple policy -> considered as a simple step, but other name
  step model! # step -> if fails, other steps won't run
  step validate!
  step persist!
  success send_email! # success -> runs only if all previous steps successful, doesn't change state itself
  failure log! # failure -> runs only if a step or simple policy failed, doesn't change state itself

  # define all methods
  def enough_ressources?; true; end
  def permitted?; true; end
  def model!; true; end
  def validate!; true; end
  def persist!; true; end
  def send_email!; true; end

  def log
    puts @log.to_s # use the Operation Logger to get steps
  end
end


# ...
operation = World::Create.run(size_x: 10, size_y: 10)
# or
operation = World::Create.new(size_x: 10, size_y: 10).run

operation.success? # => true
```

## Goals

- **Performance**: Since you are using Crystal you are probably looking for something faster than Ruby.
So the main goal is not compromising performance in favor of syntactic sugar.
- **Maintainability**: Crystal is changing pretty fast, so a lot of things may seem redundant and
the code may take a few more lines than needed.
- **Clarity and Comprehensibility**: Hathor does **not** aim to be Crystal's *high-level architecture*.
Its a tiny lib for syntactic sugar in big and small projects.

## result, params and other args

If you know Trailblazer Operation you may expect a result class and options/ctx with params in your methods.
But right now, there is no way to do this without compromising performance.
Pass parameters like you would usually do for classes and make them instance variables.

For example:
Define them with `property` macro:

```crystal
property model : User | Nil
```

Define the `initialize` method like shown in [Usage](#usage) to pass params.
Hathor Operations return their instance and not a result.
If you need something from the inside, than just access it through a getter. (`property` macro will create one)

If you want to avoid private variables for nil checks you can use the [`property!`](https://crystal-lang.org/api/0.35.1/Object.html#property!(*names)-macro) macro:

```crystal
property! model : World

def model!
  self.model = World.find(1)
end

def do_something!
  # when using normal property macro this would not compile
  model.size_x * model.size_y
end
```

I think this is a clean way for doing things like this in Crystal.
If you have other ideas, share them with me! Or contribute!

## Inheritance

You can inherit methods like you normally do it with Crystal.
Macros will not be inherited.

## Class API

```crystal
# run
# run is shortcut to instantiate and run the operation, returns instance of operation
operation = World::Create.run(size_x: 10, size_y: 10)

# simply create a new empty operation instance without running it
# you may want to populate some properties before running it or something
operation = World::Create.new
operation.size_x = 10
operation.size_y = 10
operation.run
```

## Instance API

### <a name="success-method"></a> success?

Get the current state of operation. Can be used within internal methods.

```crystal
operation.success? # => Bool
# or within a step
success? # => Bool
```

### <a name="success-step-method"></a> success?(:step, :step_type)

Get the output state of a step. Can be used within internal methods.

Is a shortcut to `@log.success?(step_name, step_type = nil)`.
[Learn more](#logger-success-step-method)

```crystal
operation.success?(:data_valid?, :policy) # => Bool
# or within a step or an method
success?(:model!) # => Bool
```

### <a name="failure-method"></a> failure?

Get the current state of operation. Can be used within internal methods.


```crystal
operation.failure? # => Bool
# or within a step
failure? # => Bool
```

### <a name="failure-step-method"></a> failure?(:step, :step_type)

Get the output state of a step. Can be used within internal methods.

Is a shortcut to `@log.failure?(step_name, step_type = nil)`.
[Learn more](#logger-failure-step-method)

```crystal
operation.failure?(:data_valid?, :policy) # => Bool
# or within a step or an method
failure?(:model!) # => Bool
```

### log

Getter to OperationLogger instance. Learn more: [Logger](#operation-logger)

```crystal
operation.log.to_s # returns a formatted String with a list of all steps run and custom messages
# or within a step
@log.add "Custom Message" # will add a custom message to Logger
```

### update_operation_state

Used internally for flow control and logging. but can also be used to force a new state.

```crystal
# update_operation_state(new_status : Bool, log_reason = "updated without submitting reason", force = false)

operation.update_operation_state(true, "I SAID IT DID NOT FAIL!", true)
```

### run

Will call the steps and control the flow, by checking operation state and updating it using `update_operation_state`.

```crystal
operation.run # returns self
```

## Macros

All macros are written to be straight forward and most importantly *fast* during resulting execution.
The current macros build the instance method `run` during compilation, not execution! Thats great for performance.  

### step

Will call the method provided. Method must return something, that is not `Nil` and not `false` to be passed!
If it fails, operation state will change to failing.
If a step fails, following steps won't be executed.

```crystal
# macro step(method, **options)
step some_method_name
```

### failure

A failure step will only run if operation changed it's state to failing.
The failure step itself, always passes.

Internally it will call step macro with `step method, step_type: :failure`.

```crystal
# macro failure(method, **options)
failure some_method_name
```

### success

A success step will only run if operation is in success state.
The success step itself, always passes.

Internally it will call step macro with `step method, step_type: :success`.

```crystal
# macro success(method, **options)
success some_method_name
```

### policy

A policy step is the same as a normal step, but will produce an according log message.
It may get more features in future releases.

Internally it will call step macro with `step method, step_type: :policy`.

```crystal
# macro policy(method, **options)
policy some_method_name
```

### policy!

A `policy!` is a strict policy. This means, if it fails, the whole execution will be stopped and even failure steps won't be called.

Internally it will call step macro with `step method, step_type: :strict_policy`.

```crystal
# macro policy!(method, **options)
policy! some_method_name
```

## Operation Logger

The Operation Logger is a class, witch is initialized with the operation and
can be accessed through the `log` property.
The first entry is created on initialize and shows that the operation has started.

It is used for logging the internal flow, but can also be used to log some custom messages.

### Access the logs

#### entries

The logs can be accessed through `entries`:
```crystal
# entries(steps_only = false)
operation.log.entries
#  => Array({
#    status: Bool | Nil,
#    reason: String | Nil,
#    step: Symbol | Nil,
#    step_type: Symbol | Nil,
#    force: Bool | Nil,
#    message: String | Nil
#  })
# example:
# [
#   {status: true, reason: "Start TestOperationBasicsTest::TestOperationWithPolicy", step: nil, step_type: nil, force: false, message: nil},
#   {status: true, reason: "policy: return_param!", step: :return_param!, step_type: :policy, force: false, message: nil},
#   {status: nil, reason: nil, step: nil, step_type: nil, force: nil, message: "Custom Message"},
#   {status: false, reason: "strict_policy: return_other_param!", step: :return_other_param!, step_type: :strict_policy, force: false, message: nil}
# ]
operation.log.entries(true) # => will filter all custom messages
```

### <a name="logger-success-step-method"></a> success?(:step, :step_type)

Gets the output state of a step by iterating through log entries.

**NOTE:** `success` steps for example do not change the state, so checking them with this is most likely useless.

**NOTE:** Testing an undefined step, will return that it failed.

**NOTE:** It will return the state of the first found occurrence. Pay attention if you call same step twice!

There is a shortcut at the operation itself.
[Learn more](#success-step-method)

```crystal
# def success?(step_name : Symbol, step_type : Symbol | Nil = nil)
operation.log.success?(:data_valid?, :policy) # => Bool
# or within a step or an method
@log.success?(:model!) # => Bool
```

### <a name="logger-failure-step-method"></a> failure?(:step, :step_type)

Gets the output state of a step by iterating through log entries. Calls `!success(:step, :step_type)` internally.

There is a shortcut at the operation itself.
[Learn more](#failure-step-method)

#### to_s

You can also get a formatted output with `to_s`. Great for logging and debug.

```crystal
# to_s(one_line = false, steps_only = false)
# one_line = true => output won't have linebreaks
# steps_only = true => output won't have custom messages
operation.log.to_s # =>
# >> Start TestOperationBasicsTest::TestOperationWithPolicy -> 'true'
# >> policy: return_param! -> 'true'
# log message: Custom Message
# >> strict_policy: return_other_param! -> 'false'
# >> Operation End

# or within the operation
@log.to_s
```

### Custom Messages

Simply add custom messages by using `add` method.

```crystal
# add(message : String)
@log.add "my custom message"
```

## Development

- [ ] better logging and output to console and logs
- [ ] maybe some more macros
- [ ] a beautiful way to pass parameters - maybe there is none
- [ ] ... even more possibilities

## Contributing

1. Fork it (<https://github.com/your-github-user/schemas/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors and Contact

If you have ideas on how to develop hathor more or what features it is missing, I would love to hear about it.
You can always contact me on [gitter](https://gitter.im/amberframework/amber) @ikaru5 or E-Mail.

- [@richardboehme](https://github.com/richardboehme) Richard Böhme - maintainer
- [@ikaru5](https://github.com/ikaru5) Kirill Kulikov - creator, maintainer

## Thanks

I want to say a big Thank You to George Dietrich [gitter](https://gitter.im/amberframework/amber) @Blacksmoke16!
He helped me to start with Crystal and macros. Answers questions professionally in no time! Jon Skeet of Crystal world for me. :)

## Copyright

Copyright (c) 2021 Kirill Kulikov <k.kulikov94@gmail.com>

`hathor-operation` is released under the [MIT License](http://www.opensource.org/licenses/MIT).
