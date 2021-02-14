require "irb"
require "irb/cmd/nop"
require "irb/cmd/chws"

module IRB
  module ExtendCommand

    class DexcFrame < Nop
      def execute(idx = nil)
        if idx
          irb_context.dexc_change_frame(idx)
          STDOUT.print(irb_context.workspace.code_around_binding)
        end
        irb_context.dexc_print_frame
        irb_context.main
      end
    end

    class DexcUp < Nop
      def execute(*)
        irb_context.change_workspace(irb_context.dexc_up_frame)
        STDOUT.print(irb_context.workspace.code_around_binding)
        irb_context.dexc_print_frame
        irb_context.main
      end
    end

    class DexcDown < Nop
      def execute(*)
        irb_context.change_workspace(irb_context.dexc_down_frame)
        STDOUT.print(irb_context.workspace.code_around_binding)
        irb_context.dexc_print_frame
        irb_context.main
      end
    end
  end
end

IRB::ExtendCommandBundle.def_extend_command(:irb_frame, :DexcFrame, "dexc/irb/cmd/stack_explorer", [:frame, IRB::ExtendCommandBundle::OVERRIDE_ALL])
IRB::ExtendCommandBundle.def_extend_command(:irb_up, :DexcUp, "dexc/irb/cmd/stack_explorer", [:up, IRB::ExtendCommandBundle::OVERRIDE_ALL])
IRB::ExtendCommandBundle.def_extend_command(:irb_down, :DexcDown, "dexc/irb/cmd/stack_explorer", [:down, IRB::ExtendCommandBundle::OVERRIDE_ALL])
