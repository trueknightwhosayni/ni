#require 'colorize'

module Ni
  module Help
    extend ActiveSupport::Concern

    module ClassMethods
      def help(action=:perform, indent=0)
        disp = -> (str) { puts '' * indent + str }

        disp "#{'Interactor'.bold} #{('='*15).bold}> #{self.class.name.colorize(:blue)} <#{('='*15).bold} "
        disp "#{'Description'.bold}: #{self.class.description}"
        disp "#{'Pefrormed Action'.bold}: #{action.to_s.colorize(:green)} - #{self.class.defined_actions[:action].description.to_s.colorize(:green)}"

        disp ''

        if self.respond_to?(:select_contracts_for_action, true)
          disp 'Input parameters:'.bold
          select_contracts_for_action(self.class.pop_contracts, action).each do |name, contract|
            disp "#{name.to_s.bold.yellow} - #{contract[:description] || 'No description'}"
          end
          disp ''

          disp 'Mutated parameters:'.bold
          select_contracts_for_action(self.class.mutate_contracts, action).each do |name, contract|
            disp "#{name.to_s.bold.yellow} - #{contract[:description] || 'No description'}"
          end
          disp ''

          disp 'Output parameters:'.bold
          select_contracts_for_action(self.class.push_contracts, action).each do |name, contract|
            disp "#{name.to_s.bold.yellow} - #{contract[:description] || 'No description'}"
          end
          disp ''
        end

        defined_actions[name].units.each do |unit|
          if unit.is_a?(Proc)
            disp 'Proc body, can not read'
          elsif unit.is_a?(Array)
            disp 'Call another interator in chain'
            unit.first.help(unit.last, (indent + 1) * 2)
          elsif unit.is_a?(Symbol)
            disp "Call method #{unit}. Source can't be read"
          else
            disp 'Call another interator in chain'
            unit.help(:perform, (indent + 1) * 2)
          end
        end
      end

      def desc(description)
        @__ni_desription = description
      end

      def description
        @__ni_desription
      end

      def title(title=nil)
        @__ni_title ||= title
      end

      def title!
        @__ni_title || raise("The title is required for #{self.name}")
      end
    end
  end
end
