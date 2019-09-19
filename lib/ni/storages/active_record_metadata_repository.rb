module Ni
  module Storages
    if defined?(ActiveRecord)
      class ActiveRecordMetadataRepository < ActiveRecord::Base
         self.table_name = "ni_metadata"

         TIMER_KEY = 'timer'.freeze

         def self.store(uid, key, data)
           record = self.where(uid: uid, key: key).first_or_initialize
           record.update(data: data.to_json) 
         end

         def self.fetch(uid, key)
           record = self.where(uid: uid, key: key).first

           if record.present?
             JSON.parse(record.data, symbolize_names: true)
           else
             {}  
           end  
         end 

         def self.setup_timer!(timer_id, datetime, timer_klass_name, timer_action, system_uid)
           data = [timer_klass_name, timer_action, system_uid].to_json
           self.create!(uid: timer_id, key: TIMER_KEY, run_timer_at: datetime, data: data)
         end

         def self.clear_timer!(timer_id)
           self.where(uid: timer_id, key: TIMER_KEY).delete_all
         end

         def self.fetch_timers
           self.where(key: TIMER_KEY).where("run_timer_at < ?", Time.now).map do |record|
             [record.uid] + JSON.parse(record.data) 
           end 
         end
      end
    else
      class ActiveRecordMetadataRepository
        def self.store(uid, key, data)
          raise "ActiveRecord not found"
        end

        def self.fetch(uid, key)
          raise "ActiveRecord not found"
        end
      end
    end  
  end
end