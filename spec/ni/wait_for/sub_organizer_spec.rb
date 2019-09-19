require 'rails_helper'

RSpec.describe 'Sub organizer wait for spec' do
  module Sowf
    class ExternalThirdUser
      include Ni::Main

      unique_id :external_third_user

      action :perform do
      end  
    end

    class OrganizerLevel3
      include Ni::Main

      storage Ni::Storages::Default
      metadata_repository Ni::Storages::ActiveRecordMetadataRepository

      mutate :user_3

      action :perform do
        # empty initializer
      end
      .wait_for(Sowf::ExternalThirdUser)
      .then do
        context.user_3 = User.create! email: 'user3@test.com', password: '111111'
      end
    end

    class OrganizerUniqueUser
      include Ni::Main

      storage Ni::Storages::Default
      metadata_repository Ni::Storages::ActiveRecordMetadataRepository

      action :perform do
        User.create! email: 'unique@test.com', password: '11111111'
      end
      .wait_for(:ready_create_uniq_user)
    end

    class OrganizerLevel2
      include Ni::Main

      storage Ni::Storages::Default
      metadata_repository Ni::Storages::ActiveRecordMetadataRepository

      mutate :user_2

      action :perform do
        # do nothing
      end
      .wait_for(:ready_create_second_user)
      .then do
        context.user_2 = User.create! email: 'user2@test.com', password: '111111'
      end
      .then(OrganizerLevel3)
    end

    class Organizer
      include Ni::Main

      storage Ni::Storages::Default
      metadata_repository Ni::Storages::ActiveRecordMetadataRepository

      mutate :user_1
      mutate :user_2
      mutate :user_3
      mutate :admin_user
      mutate :after_organizer_2_user
      mutate :done
      
      action :perform do
        context.user_1 = User.create! email: 'user1@test.com', password: '111111'
      end
      .then(OrganizerUniqueUser)
      .then(OrganizerLevel2)
      .then do
        context.after_organizer_2_user = User.create! email: 'after_organizer_2_user@test.com', password: '111111' 
      end
      .wait_for(:ready_create_admin)
      .then(:create_admin)
      .wait_for(:final_step)
      .then do 
        context.done = true
      end

      private

      def create_admin
        context.admin_user = User.create! email: 'admin@test.com', password: '111111'
      end
    end
  end

  it 'should pass throgh all steps' do
    first_result = Sowf::Organizer.perform.context
    uid = first_result.system_uid

    expect(first_result.user_1.email).to eq('user1@test.com')
    expect(first_result.user_2).to eq(nil)
    expect(first_result.user_3).to eq(nil)
    expect(first_result.after_organizer_2_user).to eq(nil)

    Sowf::Organizer.perform(wait_completed_for: :ready_create_uniq_user, system_uid: uid)

    second_result = Sowf::Organizer.perform(wait_completed_for: :ready_create_second_user, system_uid: uid).context

    expect(second_result.user_1.email).to eq('user1@test.com')
    expect(second_result.user_2.email).to eq('user2@test.com')
    expect(second_result.user_3).to eq(nil)
    expect(second_result.admin_user).to   eq(nil)

    second_result = Sowf::Organizer.perform(wait_completed_for: Sowf::ExternalThirdUser, system_uid: uid).context

    expect(second_result.user_1.email).to eq('user1@test.com')
    expect(second_result.user_2.email).to eq('user2@test.com')
    expect(second_result.user_3.email).to eq('user3@test.com')
    expect(second_result.admin_user).to   eq(nil)

    # Now the admin creation is available
    result = Sowf::Organizer.perform(wait_completed_for: :ready_create_admin, system_uid: uid).context
    expect(result.user_1.email).to eq('user1@test.com')
    expect(result.user_2.email).to eq('user2@test.com')
    expect(result.user_3.email).to eq('user3@test.com')
    expect(result.admin_user.email).to eq('admin@test.com')
    expect(result.done).to eq(nil)

    # This last step checks that skip for multiple conditions work as well
    result = Sowf::Organizer.perform(wait_completed_for: :final_step, system_uid: uid).context
    expect(result.done).to eq(true)
  end  
end
