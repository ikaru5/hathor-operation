# Changelog

### Unreleased

- add nested operation support by @richardboehme

### 0.2.1

- add inheritance of methods by @richardboehme

### 0.2.0

- add :step and :step_type to entries of logger
- add `success?(step_name : Symbol, step_type : Symbol | Nil)` and `failure?(step_name : Symbol, step_type : Symbol | Nil)`
methods to Logger and shortcuts to operation
- bump up crystal version to 0.35.1

### 0.1.0

- Extract to shard: contracts where developed within an active project, now its time to separate them