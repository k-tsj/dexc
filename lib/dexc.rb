# dexc.rb
#
# Copyright (C) 2013-2016 Kazuki Tsujimoto, All rights reserved.

raise LoadError, "TracePoint is undefined. Use Ruby 2.0.0 or later." unless defined? TracePoint

require 'dexc/version'
require 'irb/color'
require 'irb/color_printer'

module Dexc
  EXC_BINDING_VAR = :@dexc_binding

  class RingBuffer
    def initialize(n)
      @n = n
      @buf = []
      @idx = 0
    end

    def add(val)
      @buf[@idx] = val
      @idx = (@idx + 1) % @n
    end

    def to_a
      @buf[@idx..-1] + @buf[0...@idx]
    end
  end

  RaiseEvent  = Struct.new(:event, :raised_exception)
  ReturnEvent = Struct.new(:event, :lineno, :path, :defined_class, :method_id, :return_value)

  # See MiniTest::Unit::TestCase::PASSTHROUGH_EXCEPTIONS,
  # Test::Unit::ErrorHandler::PASS_THROUGH_EXCEPTIONS
  # to know why Interrupt is used
  class ExceptionWrapper < NoMemoryError
    attr_reader :wrapped_exception

    def initialize(wrapped_exception)
      super(nil)
      @wrapped_exception = wrapped_exception
    end
  end

  module TestPassThroughException
    def run_test(*)
      super
    rescue => e
      raise ExceptionWrapper, e
    end
  end

  class ::Object
    prepend Module.new {
      def require(path)
        super.tap do
          if path == 'minitest/unit'
            MiniTest::Unit::TestCase.class_eval do
              prepend TestPassThroughException
            end
          elsif path == 'test/unit'
            Test::Unit::TestCase.class_eval do
              prepend TestPassThroughException
            end
          end
        end
      end
    }
  end

  def start
    events = RingBuffer.new(30)

    tp = TracePoint.new(:raise, :return, :c_return, :b_return) do |tp|
      if tp.event == :raise
        exc = tp.raised_exception
        exc.instance_variable_set(EXC_BINDING_VAR, tp.binding)
        events.add(RaiseEvent.new(tp.event, exc))
      else
        events.add(ReturnEvent.new(tp.event, tp.lineno, tp.path, tp.defined_class, tp.method_id, tp.return_value))
      end
    end

    at_exit do
      exc = $!
      if exc.kind_of?(ExceptionWrapper)
        exc = exc.wrapped_exception
      end
      tp.disable
      b = exc.instance_variable_get(EXC_BINDING_VAR)
      if exc.kind_of?(StandardError) and b
        raise_idx = events.to_a.find_index {|i| i.event == :raise and i.raised_exception == exc }
        latest_events = raise_idx ? events.to_a[0...raise_idx] : []
        return_events = latest_events.find_all {|i| i.event != :raise }
        return_values = return_events.map(&:return_value)

        show_trace(return_events)
        error_print(exc)

        Kernel.module_eval do
          define_method(:dexc_hist) do
            return_values
          end
          alias_method :hist, :dexc_hist
        end

        begin
          require 'pry'
          Pry.config.hooks.add_hook(:when_started, :dexc_init_ex) do |_, _, pry|
            pry.last_exception = exc
            pry.backtrace = (exc.backtrace || [])
          end
          b.pry
        rescue LoadError
          b.irb
        end
        exit!
      end
    end

    tp.enable
  end
  module_function :start

  def show_trace(events)
    idx_width = (events.length - 1).to_s.length
    file_cache = {}
    events.each_with_index do |i, idx|
      show_line(i.path, i.lineno, idx, idx_width, file_cache)
      puts " " * (idx_width + 1) + "#{i.defined_class}##{i.method_id}#{i.event == :b_return ? '(block)' : ''}: #{IRB::ColorPrinter.pp(i.return_value.inspect, '')}"
    end
    puts
  end
  module_function :show_trace

  def show_line(path, lineno, index, index_width, cache)
    print "#{"%#{index_width}d" % index}:#{path}:#{lineno}"
    begin
      cache[path] ||= open(path).each_line.map(&:chomp)
      print "> #{lineno > 0 ? ::IRB::Color.colorize_code(cache[path][lineno - 1], complete: false, ignore_error: true) : ''}"
    rescue Errno::ENOENT
      cache[path] = []
    end
    puts
  end
  module_function :show_line

  # from Irb#eval_input(lib/irb.rb)
  def error_print(exc)
    print exc.class, ": ", exc, "\n"
    messages = []
    lasts = []
    levels = 0
    back_trace_limit = 30
    for m in exc.backtrace
      if m
        if messages.size < back_trace_limit
          messages.push "\tfrom "+m
        else
          lasts.push "\tfrom "+m
          if lasts.size > back_trace_limit
            lasts.shift
            levels += 1
          end
        end
      end
    end
    print messages.join("\n"), "\n"
    unless lasts.empty?
      printf "... %d levels...\n", levels if levels > 0
      print lasts.join("\n")
    end
  end
  module_function :error_print
end

Dexc.start
