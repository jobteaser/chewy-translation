module Chewy
  module Translation
    module Query
      # Called on an Index, will autocomplete on the fields regarding or not the locale
      # Usage :
      #   UserIndex::Global.autocomplete(fields: ['name'], query: 'Idefix', locale: 'fr')
      #     => Users with 'Idefix' in their name in french
      #   UserIndex.autocomplete(fields:['first_name', 'last_name'], query: 'Ordralfabetix', locale: 'fr')
      #     => Users with 'Ordralfabetix' in their first_name or in their last_name
      #
      # /!\ it will fail if you try to autocomplete a non translated field with a locale
      #
      # @param fields [array] fields autocompleted
      # @param query [string] query of the autocomplete
      # @param locale [string] context locale if the field is translated
      # @return [chewy::query]
      def autocomplete(fields:, query:, locale: nil)
        return search_by_fields(fields: fields, query: query) unless locale
        search_by_fields_with_locale(fields: fields, query: query, locale: locale)
      end

      # Principal search function that should be used as often as possible
      # Usage:
      #   UserIndex.search_by(name: 'Assurancetour')
      #     => users including Assurancetour in their name
      #   UserIndex.search_by(name: 'Assurancetour', harp_id: 1, house_in_tree_id: [1, 2, 3])
      #     => users including oran in their name, with harp_id 1 and house_in_tree_id 1, 2 or 3
      #
      # @param opts [Hash] fields and their associated query
      # @return [Chewy::Query]
      def search_by(opts = {})
        return self if opts.blank?
        results = self
        opts.delete_if { |_, v| v.blank? }.each do |k, v|
          results = results.unit_search_by(k, v)
        end
        results
      end

      # Another way to search the indexes
      # Usage:
      #   UserIndex.search_by_fields(fields: ['name', 'character_description'], query: 'Falbala')
      #     => all objects containing 'Falbala' in  name or in character_description
      #
      # @param fields [Array]
      # @param query [String]
      # @param query_mode [Symbol] :should or :must
      #   (:should by default,
      #   this is most of all for the use of this method from the inside of this module)
      # @return [Chewy::Query]
      def search_by_fields(fields:, query:, query_mode: :should)
        nested_fields = translated_fields & fields unless translated_fields.blank?
        fields -= translated_fields unless translated_fields.blank?
        result = []
        result << { multi_match: { fields: fields, query: query } } unless fields.blank?
        result << nested_search_by_fields(
          path: 'translations', fields: nested_fields, query: query
        ) unless nested_fields.blank?
        result = { bool: { query_mode => result } }
        query(result)
      end

      # Usage:
      # FortifiedCampIndex::Global.active_filter(['fr', 'en'])
      #   => FortifiedCamps active either in french OR in english OR both
      #
      # @param locales [Array] List of locales on the context
      # @return [Chewy::Query]
      def active_filter(locales:)
        activation_status_filter(active: true, locales: locales)
      end

      # Usage:
      # FortifiedCampsIndex::Global.active_filter(['fr', 'en'])
      #   => FortifiedCamps inactive in french AND in english
      #
      # @param locales [Array] List of locales on the context
      # @return [Chewy::Query]
      def inactive_filter(locales:)
        activation_status_filter(active: false, locales: locales)
      end

      # Usage:
      #   FortifiedCampsIndex.permitted(policy, :enter?)
      #   FortifiedCampsIndex.filter { !centurion? }.permitted(policy, :enter?).filter(active:true)
      #
      # To call query.permitted(policy, :enter?) is similar to call policy.elasticsearch_show?(enter)
      #
      # The permission are defined in each policy,
      # in the filter module and should be build as follow:
      #   def elasticsearch_action?(query)
      #     # returns a chewy query
      #   end
      # It needs to be prefixed with elasticsearch
      # and needs to take a query or an index and return a query
      #
      # @param policy [Policy] could be any type of policy linked to the Index.
      # ie: when the method is called on CompanyIndex,
      # it should be CompanyPolicy or Backend::CompanyPolicy
      # @param action [Symbol]
      # @return [ChewyIndex::Query]
      def permitted(policy, action)
        policy.send("elasticsearch_#{action}", self)
      end

      # Build the hash needed to perform search in nested fields
      # Usage:
      #   UserIndex.query(nested_search_by_fields(
      #     path: 'nested_path',
      #     fields: ['name'],
      #     query: 'Fulliautomatix')
      #   )
      #     => all objects containing 'Fulliautomatix' in nested_path.name
      #
      # CAUTION: this will fail if the field is not of nested type
      #
      # @param path [String]
      # @param fields [Array]
      # @param query [String]
      # @return [Hash]
      def nested_search_by_fields(path:, fields:, query:)
        { nested: {
          path: path, query:
            { multi_match: { fields: fields.map { |f| "#{path}.#{f}" }, query: query }
          }
        } }
      end

      # Atomic function for search by, should not be called from the outside of this module
      #
      # @param field [String]
      # @param value [String|Integer|Array]
      # @return [Chewy::Query]
      def unit_search_by(field, value)
        if value.is_a?(String)
          search_by_fields(fields: [field.to_s], query: value, query_mode: :must)
        elsif value.is_a?(Fixnum)
          query(match: { field => value }).query_mode(:must)
        elsif value.is_a?(DateTime)
          # TODO: handle dates
        elsif value.is_a?(Array)
          query(bool: { should: value.compact.map { |e| { match: { field => e } } } })
        end
      end

      # This should not be called from the outside of this module,
      # use active_filter or inactive_filter instead.
      #
      # @param locales [Array] list of locales on the context
      # @param active [Boolean] true to have the active records, false to have the inactive records
      # @return [ChewyIndex::Query]
      def activation_status_filter(locales:, active:)
        filter_mode = active ? :or : :and
        results = []
        locales.each do |locale|
          filter_hash = { term: { active_locales: locale } }
          filter_hash = { not: filter_hash } unless active
          results << filter_hash
        end
        filter(filter_mode => results)
      end

      # This should not be called from the outside of this module,
      # call autcomplete or search_by instead.
      #
      # @oaram fields [Array]
      # @param query [String]
      # @param locale [String]
      # @return [Chewy::Query]
      def search_by_fields_with_locale(fields:, query:, locale:)
        query(
          nested: { path: 'translations', query: { bool: {
            must: [
              { multi_match: { fields: fields.map { |f| "translations.#{f}" }, query: query } },
              { match: { 'translations.locale' => locale } }
            ]
          } } }
        )
      end

      # Generate the array of all the translated fields of the current index
      # @return [Array]
      def translated_fields
        @_translated_fields ||= current_index.mappings_hash[:mappings].
          values.first.values.first[:translations].
          try(:[], :properties).try(:keys).try(:map, &:to_s)
      end

      # Name of the current index
      # @return [Class]
      def current_index
        self.class.to_s.split(':').first.constantize
      end
    end
  end
end
