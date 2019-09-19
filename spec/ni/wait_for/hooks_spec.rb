require 'rails_helper'

RSpec.describe 'Wait for hooks spec' do
  module Wfhs
    class RaiseOrganizer
      include Ni::Main

      action :perform do
        raise "Should not be here"
      end  
    end

    class OrganizerLevel2
      include Ni::Main

      action :perform do
        # empty initializer
      end
      .wait_for(:level2)
      .then(RaiseOrganizer)
      
      def on_checking_continue_signal(_)
        self.context.success!
      end
    end

    class Organizer
      include Ni::Main
    
      action :perform do        
      end
      .then(OrganizerLevel2)
      .then(RaiseOrganizer)
    end
  end

  it 'should pass throgh all steps' do
    uid = Wfhs::Organizer.perform.context.system_uid

    Wfhs::Organizer.perform(wait_completed_for: :level2, system_uid: uid)
  end  
end
