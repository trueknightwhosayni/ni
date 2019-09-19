module Ni::Flows::Utils
  module HandleWait
    def handle_current_wait?(context, name)
      interactor_klass.units_by_interface(:waited_for_name?).any? { |unit| unit.waited_for_name?(name) } ||
      check_all_subtree_for_wait(context, name, interactor_klass.units_by_interface(:handle_current_wait?))        
    end

    def call_for_wait_continue(context, params={})
      raise "Not implemented"
    end

    private

    def check_all_subtree_for_wait(context, name, units)
      units.any? do |unit| 
        next_level_units = unit.interactor_klass.units_by_interface(:handle_current_wait?)
        
        unit.handle_current_wait?(context, name) || (next_level_units.any? && check_all_subtree_for_wait(context, name, next_level_units) )
      end 
    end
  end
end