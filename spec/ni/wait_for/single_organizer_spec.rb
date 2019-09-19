require 'rails_helper'

RSpec.describe 'Organizer wait for spec' do
  module Wf
    class Organizer
      include Ni::Main

      storage Ni::Storages::Default
      metadata_repository Ni::Storages::ActiveRecordMetadataRepository

      mutate :user_1
      mutate :user_2
      mutate :user_3
      mutate :admin_user
      mutate :done

      mutate :before_cheking
      mutate :after_cheking
      
      action :perform do
        context.user_1 = User.create! email: 'user1@test.com', password: '111111'
      end
      .then(:create_second_user)
      .wait_for(:outer_action_performed)
      .then(:create_third_user)
      .wait_for(multicondition: [:some_event_here])
      .wait_for(more_users_expected: 
        [
          :moderator_user_registered,
          [:user_registration, -> (context) { User.where.not(email: ['before@test.com', 'after@test.com']).count >= 6 }]
        ]
      )
      .then(:create_admin)
      .wait_for(:all_thigs_done)
      .then do 
        context.done = true
      end

      private

      def on_checking_continue_signal(unit)
        context.before_cheking = User.where(email: 'before@test.com').first_or_create! password: '111111'
      end

      def on_continue_signal_checked(unit, wait_cheking_result)
        context.after_cheking = User.where(email: 'after@test.com').first_or_create! password: '111111'
      end

      def create_second_user
        context.user_2 = User.create! email: 'user2@test.com', password: '111111'
      end

      def create_third_user
        context.user_3 = User.create! email: 'user3@test.com', password: '111111'
      end

      def create_admin
        context.admin_user = User.create! email: 'admin@test.com', password: '111111'
      end
    end
  end

  it 'should pass throgh all steps' do
    first_result = Wf::Organizer.perform.context
    uid = first_result.system_uid

    expect(first_result.user_1.email).to eq('user1@test.com')
    expect(first_result.user_2.email).to eq('user2@test.com')
    expect(first_result.user_3).to eq(nil)

    second_result = Wf::Organizer.perform(wait_completed_for: :outer_action_performed, system_uid: uid).context

    expect(second_result.user_1.email).to eq('user1@test.com')
    expect(second_result.user_2.email).to eq('user2@test.com')
    expect(second_result.user_3.email).to eq('user3@test.com')
    expect(second_result.admin_user).to   eq(nil)

    User.create! email: 'moderator@test.com', password: '111111'

    # this one will ensure that it's possible to use multiple multiconditions waits
    Wf::Organizer.perform(wait_completed_for: :some_event_here, system_uid: uid)

    # The third result will be the same because users count less then 6
    third_result = Wf::Organizer.perform(wait_completed_for: :moderator_user_registered, system_uid: uid).context
    expect(third_result.user_1.email).to eq('user1@test.com')
    expect(third_result.user_2.email).to eq('user2@test.com')
    expect(third_result.user_3.email).to eq('user3@test.com')
    expect(third_result.admin_user).to   eq(nil)

    User.create! email: 'user4@test.com', password: '111111'

    # The fourth result will be the same because need one more user
    fourth_result = Wf::Organizer.perform(wait_completed_for: :user_registration, system_uid: uid).context
    expect(fourth_result.user_1.email).to eq('user1@test.com')
    expect(fourth_result.user_2.email).to eq('user2@test.com')
    expect(fourth_result.user_3.email).to eq('user3@test.com')
    expect(fourth_result.admin_user).to   eq(nil)

    User.create! email: 'user5@test.com', password: '111111'

    # Now the admin creation is available
    result = Wf::Organizer.perform(wait_completed_for: :user_registration, system_uid: uid).context
    expect(result.user_1.email).to eq('user1@test.com')
    expect(result.user_2.email).to eq('user2@test.com')
    expect(result.user_3.email).to eq('user3@test.com')
    expect(result.admin_user.email).to eq('admin@test.com')
    expect(result.done).to eq(nil)

    # This last step checks that skip for multiple conditions work as well
    result = Wf::Organizer.perform(wait_completed_for: :all_thigs_done, system_uid: uid).context
    expect(result.done).to eq(true)

    expect(result.before_cheking.email).to eq('before@test.com')
    expect(result.after_cheking.email).to eq('after@test.com')
  end  
end
