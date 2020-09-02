# Copyright (c) 2020 Bryan Frimin <bryan@frimin.fr>.
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

module Cmdline
  Option = Struct.new(
    :short_name,
    :long_name,
    :value_string,
    :description,
    :default,
    :set,
    :value,
    keyword_init: true
  )

  class Option
    def initialize(*)
      super
      self.short_name ||= ""
      self.long_name ||= ""
      self.value_string ||= ""
      self.description ||= ""
      self.default ||= ""
      self.set ||= false
      self.value ||= ""
    end

    def sort_key
      return short_name unless short_name.empty?
      return long_name unless long_name.empty?
      ""
    end
  end

  Argument = Struct.new(
    :name,
    :description,
    :trailing,
    :value,
    :trailing_values,
    keyword_init: true
  )

  class Argument
    def initialize(*)
      super
      self.name ||= ""
      self.description ||= ""
      self.trailing ||= false
      self.value ||= ""
      self.trailing_values ||= []
    end
  end

  Command = Struct.new(
    :name,
    :description,
    keyword_init: true
  )

  class Command
    def initialize(*)
      super
      self.name ||= ""
      self.description ||= ""
    end
  end

  CmdLine = Struct.new(
    :options,
    :arguments,
    :commands,
    :command,
    :command_arguments,
    :program_name,
    keyword_init: true
  )

  class CmdLine
    def initialize(*)
      super
      self.options ||= {}
      self.commands ||= {}
      self.command ||= ""
      self.arguments ||= []
      self.command_arguments ||= []
      self.program_name ||= ""
    end

    def add_flag(short, long, description)
      option = Option.new(
        short_name: short.to_s,
        long_name: long.to_s,
        value_string: "",
        description: description.to_s
      )

      addopt(option)
    end

    def add_option(short, long, value, description)
      option = Option.new(
        short_name: short.to_s,
        long_name: long.to_s,
        value_string: value.to_s,
        description: description.to_s
      )

      addopt(option)
    end

    def set_option_default(name, value)
      option = self.options[name]
      raise(ArgumentError, "unknown option") if option.nil?
      raise(ArgumentError, "flags cannot have a default value") if option.value_string.empty?

      option.default = value
    end

    def add_argument(name, description)
      argument = Argument.new(
        name: name.to_s,
        description: description.to_s
      )

      addarg(argument)
    end

    def add_trailing_arguments(name, description)
      argument = Argument.new(
        name: name.to_s,
        description: description.to_s,
        trailing: true
      )

      addarg(argument)
    end

    def add_command(name, description)
      if self.arguments.size.zero?
        add_argument("command", "the command to execute")
      elsif self.arguments.first.name != "command"
        raise(ArgumentError, "cannot have both arguments and commands")
      end

      cmd = Command.new(
        name: name.to_s,
        description: description.to_s
      )

      self.commands[cmd.name] = cmd
    end

    def die(format, *args)
      msg = sprintf(format, *args)
      STDERR.puts("error: #{msg}")
      exit(1)
    end

    def parse(args)
      die("empty argument array") if args.size == 0

      self.program_name = args.shift

      while args.size > 0
        arg = args.first

        if arg == "--"
          args.shift
          break
        end

        is_short = arg.size == 2 && arg[0] == "-" && arg[1] != "-"
        is_long = arg.size > 2 && arg[0,2] == "--"

        if is_short || is_long
          key = if is_short
                  arg[1,2]
                else
                  arg[2..]
                end

          opt = self.options[key]
          die("unknown option \"%s\"", key) if opt.nil?

          opt.set = true

          if opt.value_string.empty?
            args = args[1..]
          else
            die("missing value for option \"%s\"", key) if args.size < 2
            opt.value = args[1]
            args = args[2..]
          end
        else
          break
        end
      end

      if self.arguments.size > 0 && !is_option_set("help")
        last = self.arguments.last

        min = self.arguments.size
        min -= 1 if last.trailing

        die("missing argument(s)") if args.size < min

        min.times do |i|
          self.arguments[i].value = args[i]
        end
        args = args[min..]

        if last.trailing
          last.trailing_values = args
          args = args[args.size..]
        end
      end

      if self.commands.size > 0
        self.command = self.arguments.first.value
        self.command_arguments = args
      end

      if !is_option_set("help")
        if self.commands.size > 0
          cmd = self.commands[self.command]
          if cmd.nil?
            die("unknown command \"%s\"", self.command)
          end
        elsif args.size > 0
          die("invalid extra argument(s)")
        end
      end

      if is_option_set("help")
        print_usage
        exit(0)
      end
    end

    def print_usage
      usage = sprintf("Usage: %s OPTIONS", self.program_name)
      if self.arguments.size > 0
        self.arguments.each do |arg|
          if arg.trailing
            usage << sprintf(" [<%s> ...]", arg.name)
          else
            usage << sprintf(" <%s>", arg.name)
          end
        end
      end

      usage << "\n\n"

      opt_strs = {}
      max_width = 0

      self.options.each do |_, opt|
        next if opt_strs[opt]

        buf = ""

        if opt.short_name != ""
          buf << sprintf("-%s", opt.short_name)
        end

        if opt.long_name != ""
          if opt.short_name != ""
            buf << ", "
          end

          buf << sprintf("--%s", opt.long_name)
        end

        if opt.value_string != ""
          buf << sprintf(" <%s>", opt.value_string)
        end

        opt_strs[opt] = buf

        if buf.size > max_width
          max_width = buf.size
        end
      end

      if self.commands.size > 0
        self.commands.each do |name, _|
          max_width = name.size if name.size > max_width
        end
      elsif self.arguments.size > 0
        self.arguments.each do |arg|
          max_width = arg.name.size if arg.name.size > max_width
        end
      end

      # Print options
      usage << "OPTIONS\n\n"

      opts = []
      opt_strs.each do |opt, _|
        opts << opt
      end

      # TODO: sort options

      opts.each do |opt|
        usage << sprintf("%-*s  %s", max_width, opt_strs[opt], opt.description)
        usage << sprintf(" (default: %s)", opt.default) unless opt.default.empty?
        usage << "\n"
      end

      if self.commands.size > 0
        usage << "\nCOMMANDS\n\n"
        names = []
        self.commands.each do |name, _|
          names << name
        end
        names.sort!

        names.each do |name|
          cmd = self.commands[name]
          usage << sprintf("%-*s  %s\n", max_width, cmd.name, cmd.description)
        end
      elsif self.arguments.size > 0
        usage << "\nARGUMENTS\n\n"

        self.arguments.each do |arg|
          usage << sprintf("%-*s  %s\n", max_width, arg.name, arg.description)
        end
      end

      printf(usage)
    end

    def is_option_set(name)
      opt = self.options[name]
      raise(ArgumentError, "unknown option") if opt.nil?
      opt.set
    end

    def option_value(name)
      opt = self.options[name]
      raise(ArgumentError, "unknown option") if opt.nil?

      return opt.value if opt.set
      opt.default
    end

    def argument_value(name)
      self.arguments.each do |arg|
        if arg.name == name
          return arg.value
        end
      end
      raise(ArgumentError, "unknown argument")
    end

    def trailing_arguments_values(name)
      raise(ArgumentError, "empty argument array") if self.arguments.empty?
      last = self.arguments.last
      raise(ArgumentError, "no trailing arguments") unless last.trailing
      last.trailing_values
    end

    def command_name
      raise(RuntimeError, "no command defined") if self.commands.empty?
      self.command
    end

    def command_arguments_values
      raise(RuntimeError, "no command defined") if self.commands.empty?
      self.command_arguments
    end

    def command_name_and_arguments
      raise(RuntimeError, "no command defined") if self.commands.empty?
      [self.command, *self.command_arguments]
    end

    private

    def addopt(opt)
      if !opt.short_name.empty?
        if opt.short_name.size != 1
          raise(ArgumentError, "option short names must be one character long")
        end

        self.options[opt.short_name] = opt
      end

      if !opt.long_name.empty?
        if opt.long_name.size < 2
          raise(ArgumentError, "option long names must be at least two characters long")
        end

        self.options[opt.long_name] = opt
      end
    end

    def addarg(arg)
      raise(ArgumentError, "cannot have both arguments and commands") if self.commands.size > 0
      if self.arguments.size > 0
        last = self.arguments.last
        if last.trailing
          raise(ArgumentError, "cannot add argument after trailing argument")
        end
      end

      self.arguments << arg
    end
  end

  def self.new
    cmd = CmdLine.new
    cmd.add_flag("h", "help", "print help and exit")
    cmd
  end

  def self.argv
    ARGV.dup.unshift($0)
  end
end
