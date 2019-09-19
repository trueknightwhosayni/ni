module Ni::Tools
  class Timers
    def self.fetch_and_run(metadata_repository_klass, exceptions_logger=nil)
      current_timers = metadata_repository_klass.fetch_timers
      exceptions = []

      current_timers.each do |data|
        id, klass_name, action, system_uid = data

        begin
          klass_name.constantize.public_send(action, system_uid: system_uid)
        rescue Exception => e
          exceptions << e
        ensure
          metadata_repository_klass.clear_timer!(id)
        end  
      end

      if exceptions_logger.present? && exceptions.present?
        exceptions.each { |e| exceptions_logger.log(e) }
      end  
    end
  end
end