# Introduction
This document explain how to use the `rb-cmdline` library.

# Usage
## Minimal
```ruby
require("rb-cmdline")

cmd = Cmdline.new
cmd.parse(Cmdline.argv)
```
## Options
```ruby
require("rb-cmdline")

cmd = Cmdline.new
cmd.add_option("a", "option-a", "value", "a simple option")
cmd.set_option_default("a", "42")
cmd.add_option("b", "", "value", "an short option")
cmd.add_option("", "option-c", "value", "a long option")
cmd.add_flag("d", "flag-d", "a simple flag")
cmd.parse(Cmdline.argv)

printf("a: %s\n", cmd.option_value("a"))

if cmd.is_option_set("b")
  printf("b: %s\n", cmd.option_value("b"))
end

if cmd.is_option_set("option-c")
  printf("option-c: %s\n", cmd.option_value("option-c"))
end

printf("d: %s\n", cmd.is_option_set("d"))
```

## Arguments
```ruby
#!/usr/bin/env ruby

require("rb-cmdline")

cmd = Cmdline.new
cmd.add_argument("foo", "the first argument")
cmd.add_argument("bar", "the second argument")
cmd.add_trailing_arguments("name", "a trailing argument")

cmd.parse(Cmdline.argv)

printf("foo: %s\n", cmd.argument_value("foo"))
printf("bar: %s\n", cmd.argument_value("bar"))
printf("names: %s\n", cmd.trailing_arguments_values("name"))
```

## Commands
```ruby
#!/usr/bin/env ruby

require("rb-cmdline")

cmd = Cmdline.new

cmd.add_command("foo", "subcommand 1")
cmd.add_command("bar", "subcommand 2")

cmd.parse(Cmdline.argv)

commands = {
  "foo" => -> (args) {
    printf("running command \"foo\" with arguments %s\n", args[1..])
  },
  "bar" => -> (args) {
    cmd = CLI.new
    cmd.add_option("n", "", "value", "an example value")
    cmd.parse(args)

    printf("running command \"bar\" with arguments %s\n", args[1..])

    if cmd.is_option_set("n")
      printf("n: %s\n", cmd.option_value("n"))
    end
  }
}

commands[cmd.command_name].call(cmd.command_name_and_arguments)
```
