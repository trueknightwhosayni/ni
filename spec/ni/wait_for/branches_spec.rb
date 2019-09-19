require 'rails_helper'

RSpec.describe 'Wait for Branches spec' do
  module Wfbs
    class Organizer1
      include Ni::Main

      storage Ni::Storages::Default
      metadata_repository Ni::Storages::ActiveRecordMetadataRepository

      mutate :user_1

      action :perform do
        context.user_1 = User.create! email: 'failure@test.com', password: '111111'
      end
        .branch(:not_used_branch_1, when: -> (context) { false }) do
          action :perform do            
          end
          .wait_for(:some_condition) # This is tha same name for wait key as used below, but should not be here because of condition
          .then do
            raise 'Should not be here'
          end
        end  
        .branch :first_level_valid_branch, when: -> (context) { true } do          
          action :perform do
          end
            .branch :second_level_valid_branch, when: -> (context) { true } do             
              mutate :user_1

              action :perform do            
              end
              .wait_for(:some_condition)
              .then do
                context.user_1.update!(email: 'success@test.com')
              end
            end
            .branch(:not_used_branch_2, when: -> (context) { false })  do
              action :perform do
                raise 'Should not be here'
              end
            end  
        end  
    end
  end

  it 'should go to second branch and then to first in subranch and wait for condition' do
    first_result = Wfbs::Organizer1.perform.context
    uid = first_result.system_uid

    expect(first_result.user_1.email).to eq('failure@test.com')

    second_result = Wfbs::Organizer1.perform(wait_completed_for: :some_condition, system_uid: uid).context
   
    expect(second_result.user_1.email).to eq('success@test.com')
  end  
end
