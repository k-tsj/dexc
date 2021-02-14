# dexc.rb
#
# Copyright (C) 2013 Kazuki Tsujimoto, All rights reserved.

raise LoadError, "TracePoint is undefined. Use Ruby 2.0.0 or later." unless defined? TracePoint

require 'dexc/version'
require 'irb/color'
require 'irb/color_printer'
require 'binding_of_caller'

module Dexc
  EXC_CALLERS_VAR = :@dexc_callers

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

  module IrbHelper
    def dexc_print_frame
      @dexc_callers.each_with_index do |i, idx|
        if @dexc_callers_idx == idx
          print ' => '
        else
          print '    '
        end
        print("[%#{@dexc_callers_width}d] " % idx)
        filename, lineno = i.source_location
        puts "#{filename}:#{lineno}:in `#{i.frame_description}'"
      end
    end

    def dexc_current_frame
      @dexc_callers[@dexc_callers_idx]
    end

    def dexc_up_frame
      if @dexc_callers_idx < @dexc_callers.length - 1
        @dexc_callers_idx += 1
      end
      dexc_current_frame
    end

    def dexc_down_frame
      if @dexc_callers_idx > 0
        @dexc_callers_idx -= 1
      end
      dexc_current_frame
    end

    def dexc_change_frame(idx)
      if (0...@dexc_callers.length) === idx
        @dexc_callers_idx = idx
      end
      dexc_current_frame
    end
  end

  def start
    events = RingBuffer.new(30)

    tp = TracePoint.new(:raise, :return, :c_return, :b_return) do |tp|
      if tp.event == :raise
        exc = tp.raised_exception
        exc.instance_variable_set(EXC_CALLERS_VAR, tp.binding.callers[1..-1])
        events.add(RaiseEvent.new(tp.event, exc))
      else
        events.add(ReturnEvent.new(tp.event, tp.lineno, tp.path, tp.defined_class, tp.method_id, tp.return_value))
      end
    end

    at_exit do
      exc = $!
      tp.disable
      callers = exc.instance_variable_get(EXC_CALLERS_VAR)
      if exc.kind_of?(StandardError) and callers
        raise_idx = events.to_a.find_index {|i| i.event == :raise and i.raised_exception == exc }
        latest_events = raise_idx ? events.to_a[0...raise_idx] : []
        return_events = latest_events.find_all {|i| i.event != :raise }
        return_values = return_events.map(&:return_value)

        show_trace(return_events)
        puts exc.full_message

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
          callers[0].pry
        rescue LoadError
          require 'irb'
          IRB::Context.include(IrbHelper)
          require 'dexc/irb/cmd/stack_explorer'
          b = callers[0]
          filename = b.source_location[0]
          IRB.setup(filename, argv: [])
          workspace = IRB::WorkSpace.new(b)
          STDOUT.print(workspace.code_around_binding)
          binding_irb = IRB::Irb.new(workspace)
          binding_irb.context.irb_path = File.expand_path(filename)
          binding_irb.context.instance_eval do
            @dexc_callers = callers
            @dexc_callers_width = Math.log10(callers.length).floor + 1
            @dexc_callers_idx = 0
          end
          binding_irb.run(IRB.conf)
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
end

Dexc.start
