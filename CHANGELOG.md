# Changelog

### Unreleased

- fix `OperationLogger#to_s` to have an overload for `OperationLogger#to_s(io : IO)` (by @richardboehme)

### 0.3.0

- add nested operation support by @richardboehme

### 0.2.1

- add inheritance of methods by @richardboehme

### 0.2.0

- add :step and :step_type to entries of logger
- add `success?(step_name : Symbol, step_type : Symbol | Nil)` and `failure?(step_name : Symbol, step_type : Symbol | Nil)`
methods to Logger and shortcuts to operation
- bump up crystal version to 0.35.1

### 0.1.0

- Extract to shard: operations where developed within an active project, now its time to separate them