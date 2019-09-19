module Ni
  module StoragesConfig
    extend ActiveSupport::Concern

    module ClassMethods
      cattr_accessor :context_storage_klass, :metadata_repository_klass

      def storage(klass)
        self.context_storage_klass = klass
      end
      
      def metadata_repository(klass)
        self.metadata_repository_klass = klass
      end

      def copy_storage_and_metadata_repository(interactor_klass)
        unless self.context_storage_klass.present?
          if interactor_klass.context_storage_klass.present?
            storage interactor_klass.context_storage_klass
          end
        end

        unless self.metadata_repository_klass.present?
          if interactor_klass.metadata_repository_klass.present?
            metadata_repository interactor_klass.metadata_repository_klass
          end
        end
      end
    end
  end
end
