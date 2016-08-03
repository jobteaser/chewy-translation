module Chewy
  module Translation
    module Index
      extend ActiveSupport::Concern
      included do
        singleton_class.delegate :autocomplete, to: :all
        singleton_class.delegate :permitted, to: :all
        singleton_class.delegate :search_by, to: :all
        singleton_class.delegate :search_by_fields, to: :all
        singleton_class.delegate :nested_search_by, to: :all
        singleton_class.delegate :active_filter, to: :all
        singleton_class.delegate :inactive_filter, to: :all
      end
    end
  end
end
