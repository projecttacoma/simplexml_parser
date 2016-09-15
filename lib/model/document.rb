module SimpleXml
  # Class representing an HQMF document
  class Document
    include SimpleXml::Utilities
    attr_reader :measure_period, :id, :nqf_id, :hqmf_set_id, :hqmf_version_number, :cms_id, :title, :description, :populations, :attributes, :source_data_criteria, :derived_data_criteria, :criteria_map, :attribute_map, :measure_period_map, :sub_tree_map

    MEASURE_PERIOD_TITLES = {'Measurement Period'=>:measure_period, 'Measurement Start Date'=>:measure_period_start, 'Measurement End Date'=>:measure_period_end}

    UNDEFINED_OID = '1.1.1.1'
      
    # Create a new SimpleXml::Document instance by parsing at file at the supplied path
    # @param [String] path the path to the HQMF document
    def initialize(xml_contents)
      @doc = @entry = Document.parse(xml_contents)
      details = @doc.at_xpath('measure/measureDetails')
      @id = details.at_xpath('uuid').text.upcase
      @hqmf_set_id = details.at_xpath('guid').text.upcase
      @hqmf_version_number = details.at_xpath('version').text.to_i
      @title = details.at_xpath('title').text
      @description = details.at_xpath('description').try(:text)
      @cms_id = "CMS#{details.at_xpath('emeasureid').try(:text)}v#{@hqmf_version_number}"
      @nqf_id = details.at_xpath('nqfid/@extension').try(:value)

      @attributes = []
      children_of(details).each do |attribute|
        attribute_data = Utilities::MEASURE_ATTRIBUTES_MAP[attribute.name.to_sym]
        if (attribute_data)
          attribute_data['value'] = attribute.at_xpath('@extension').try(:value) || attribute.text
          @attributes << HQMF::Attribute.from_json(attribute_data)
        end
      end

      @criteria_map = {}
      mps = details.at_xpath('period/startDate/@uuid').value rescue nil
      mpe = details.at_xpath('period/stopDate/@uuid').value rescue nil

      @measure_period_map = {
        details.at_xpath('period/@uuid').value => :measure_period,
        mps => :measure_period_start,
        mpe => :measure_period_end
      }
      @measure_period_map.keys.each do |key|
        @criteria_map[key] = OpenStruct.new(id: HQMF::Document::MEASURE_PERIOD_ID, hqmf_id: key)
      end
      
      # Extract the data criteria
      extract_data_criteria

      # Extract race, ethnicity, etc
      extract_supplemental_data

      # extract all the logic and set up populations
      handle_populations

    end
    
    # Get all the population criteria defined by the measure
    # @return [Array] an array of SimpleXml::PopulationCriteria
    def all_population_criteria
      @population_criteria
    end
    
    # Get a specific population criteria by id.
    # @param [String] id the population identifier
    # @return [SimpleXml::PopulationCriteria] the matching criteria, raises an Exception if not found
    def population_criteria(id)
      find(@population_criteria, :id, id)
    end
    
    # Get all the data criteria defined by the measure
    # @return [Array] an array of SimpleXml::DataCriteria describing the data elements used by the measure
    def all_data_criteria
      @derived_data_criteria
    end
    
    # Get a specific data criteria by id.
    # @param [String] id the data criteria identifier
    # @return [SimpleXml::DataCriteria] the matching data criteria, raises an Exception if not found
    def data_criteria(id)
      find(all_data_criteria, :id, id)
    end
    
    # Parse an XML document at the supplied path
    # @return [Nokogiri::XML::Document]
    def self.parse(xml_contents)
      xml_contents.kind_of?(Nokogiri::XML::Document) ? xml_contents : Nokogiri::XML(xml_contents)
    end

    def to_model
      dcs = all_data_criteria.collect {|dc| dc.to_model}
      pcs = all_population_criteria.collect {|pc| pc.to_model}
      sdc = source_data_criteria.collect{|dc| dc.to_model}
      HQMF::Document.new(nqf_id, id, hqmf_set_id, hqmf_version_number, cms_id, title, description, pcs, dcs, sdc, attributes, measure_period, populations)
    end

    def measure_period
      r = HQMF::Range.from_json({
        'type' => "IVL_TS",
        'low' => { 'type' => "TS", 'value' => "201201010000", 'inclusive?' => true, 'derived?' => false },
        'high' => { 'type' => "TS", 'value' => "201212312359", 'inclusive?' => true, 'derived?' => false },
        'width' => { 'type' => "PQ", 'unit' => "a", 'value' => "1", 'inclusive?' => true, 'derived?' => false }
      });
    end

    def rewrite_observ(observ)
      # we want to use the first leaf to calcualculate the value for the observation
      first_leaf = observ.get_logic_leaves.first

      unless first_leaf
        puts "\t NO DATA IN MEASURE OBSERVATION"
        return observ
      end

      # we want to pull the aggregation function off of the top level comparison
      first_criteria = data_criteria(first_leaf.reference.id)

      # pop the last subset operator which should be the closest to the root of the logic tree.  Add that aggregation function to the observation as the aggregator
      observ.aggregator = first_criteria.subset_operators.pop.type
      first_criteria.subset_operators = nil if first_criteria.subset_operators.empty?

      # # we want to get rid of any AND statements at the top level.  This is calculating a numeric value, not evaluating boolean logic
      observ.preconditions.clear
      observ.preconditions << first_leaf
      observ
    end

    def register_source_data_criteria(criteria)
      sdc = criteria.dup
      sdc.subset_operators = nil if sdc.subset_operators
      sdc.temporal_references = nil if sdc.temporal_references
      @source_data_criteria << sdc
      @criteria_map[criteria.hqmf_id] = criteria
    end

    private
    
    def find(collection, attribute, value)
      collection.find {|e| e.send(attribute)==value}
    end

    def extract_data_criteria
      @source_data_criteria = []
      @derived_data_criteria = []
      @attribute_map = {}
      detect_missing_oids
      filter_bad_oids
      @doc.xpath('measure/elementLookUp/qdm').each do |entry|
        data_type = entry.at_xpath('@datatype').value
        if !['Timing Element', 'attribute'].include? data_type
          criteria = DataCriteria.new(entry)
          @source_data_criteria << criteria
          @criteria_map[criteria.hqmf_id] = criteria
        elsif data_type == 'attribute'
          attribute = Attribute.new(entry.at_xpath('@id').value, entry.at_xpath('@oid').value, entry.at_xpath('@name').value)
          @attribute_map[attribute.id] = attribute
        elsif data_type == 'Timing Element'
          name = entry.at_xpath('@name').value
          if MEASURE_PERIOD_TITLES[name]
            hqmf_id = entry.at_xpath('@uuid').value
            @criteria_map[hqmf_id] = OpenStruct.new(id: HQMF::Document::MEASURE_PERIOD_ID, hqmf_id: hqmf_id)
            @measure_period_map[hqmf_id] = MEASURE_PERIOD_TITLES[name]
          end
        end
      end
    end

    def detect_missing_oids
      invalid_oid_entries = []
      @doc.xpath('measure/elementLookUp/qdm').each do |entry|
        oid = entry.at_xpath('@oid').value
        data_type = entry.at_xpath('@datatype').value
        name = entry.at_xpath('@name').value
        if oid == UNDEFINED_OID
          invalid_oid_entries << "#{data_type}: #{name}"
        end
      end
      raise "All QDM elements require VSAC value sets to load into Bonnie. This measure contains #{invalid_oid_entries.length} QDM elements without VSAC value sets: \n[ #{invalid_oid_entries.join(', ')} ]." unless invalid_oid_entries.empty?
    end

    def filter_bad_oids
      # The internal MAT representation (SimpleXML) contains these oids for
      # certain data criteria, whereas the HQMF does not.
      bad_oid_codes = [
        '21112-8', # Used for Patient Characteristic Birthdate
        '419099009' # Used for Patient Characteristic Expired
      ]

      # Filter out bad oids as defined above
      @doc.xpath('measure/elementLookUp/qdm').each do |entry|
        oid = entry.at_xpath('@oid').value
        if bad_oid_codes.include? oid
          # If this data criteria contains a bad oid, remove its oid entry
          entry.at_xpath('@oid').remove
        end
      end
    end

    def extract_supplemental_data
      # add supplemental data elements
      @doc.xpath('measure/supplementalDataElements/elementRef').each do |supplemental|
        @derived_data_criteria << @criteria_map[supplemental.at_xpath('@id').value]
      end
    end

    def handle_populations

      extract_subtrees

      # Extract any stratifications, 
      # stratifications must be extracted before population criteria for titles to be generated properly
      extract_stratifications

      # Extract the population criteria and population collections
      extract_population_criteria

      @population_criteria.concat(@stratifications)

      if (@stratifications.length > 0)
        handle_stratifications
      end

      detect_unstratified

      if @populations.length > 1
        @populations.each_with_index do |population, index|
          population['id'] = "Population#{index+1}"
          population['title'] = "Population #{index+1}"
        end
      end

      # Remove exclusion and exception populations that are empty. The simple
      # contains these empty populations, while the HQMF does not.
      #
      # Note: @populations in this context is an array of hashes, each describing
      # the mappings for each measure population criteria (e.g. a measure might
      # have two population criteria that have different IPPs, so we would have
      # a 'IPP' => 'IPP' and a 'IPP' => 'IPP2' mapping). @population_criteria
      # is an array of the actual population criteria objects (so, in the
      # previous example, @population_criteria would contain a IPP and a IPP2
      # SimpleXml::PopulationCriteria object instance).
      @populations.collect! { |population|
        population.reject { |key, value|
          if ['DENEX', 'DENEXCEP', 'NUMEX', 'MSRPOPLEX'].include?(key)
            criteria = @population_criteria.find { |pop_crit| pop_crit.id == value }
            if criteria.nil? || criteria.preconditions.empty?
              @population_criteria -= [criteria]
              next true
            end
          end
        }
      }

    end

    def extract_population_criteria
      @populations = []
      @population_criteria = []
      
      duplicate_offset = 0
      population_criteria_keys = []
      population_defs = @doc.xpath('measure/measureGrouping/group').to_a.sort! {|l,r| l.at_xpath('@sequence').value <=> r.at_xpath('@sequence').value}
      population_defs.each_with_index do |population_def, population_index|
        group_criteria = []
        population_def.xpath('clause').each do |criteria_def|
          criteria = PopulationCriteria.new(criteria_def, self, population_index + duplicate_offset)
          codes = (population_criteria_keys | group_criteria.map{|gc| gc.id}).select{|pc| pc.split('_')[0] == criteria.type}
          criteria.set_index(duplicate_offset + codes.length)

          # pull the aggregator out if we have an observation
          criteria = rewrite_observ(criteria) if criteria.type == HQMF::PopulationCriteria::OBSERV
          group_criteria << criteria if (criteria.type != HQMF::PopulationCriteria::STRAT && criteria.type != SimpleXml::PopulationCriteria::NUMEX) || !criteria.preconditions.empty?
        end

        # observations used to come from the measureObservations section... in the latest simpleXml they are listed with the rest of the population criteria
        children_of(@doc.xpath('measure/measureObservations')).each_with_index do |observ_def, observ_index|
          criteria = rewrite_observ(PopulationCriteria.new(observ_def, self, observ_index))
          group_criteria << criteria if !criteria.preconditions.empty?
        end

        population = {}
        duplicate_pop_criteria = []
        group_criteria.each do |criteria|
          if (population[criteria.type].nil?)
            population[criteria.type] = criteria.id
          else
            # we have more than one of a given population criteria type... this is typically more than one numerator
            duplicate_pop_criteria << criteria
          end
        end
        @populations << population

        # if we have duplicates of a criteria, we want to clone the population for those
        unless duplicate_pop_criteria.empty?
          handle_duplicate_pop_criteria(duplicate_pop_criteria, population, population_index, duplicate_offset)
        end

        @population_criteria.concat group_criteria
        population_criteria_keys = @population_criteria.map{|pc| pc.id}
      end
    end

    def extract_subtrees
      @sub_tree_map = {}
      @doc.xpath('measure/subTreeLookUp/subTree').each_with_index do |sub_tree_def|
        tree = SubTree.new(sub_tree_def, self)
        @sub_tree_map[tree.id] = tree
      end
      sub_tree_map.values.each do |tree|
        tree.process
      end
    end

    def extract_stratifications
      @stratifications = []
      index = 0
      @doc.xpath('measure/strata/clause').each do |strata_def|
        strat = PopulationCriteria.new(strata_def, self, index)
        unless strat.preconditions.empty?
          @stratifications << strat
          index += 1
        end
      end
    end

    def handle_stratifications
      stratified_populations = []
      @populations.each do |population|
        @stratifications.each do |stratification|
          new_population = population.dup
          new_population[HQMF::PopulationCriteria::STRAT] = stratification.id
          new_population['stratification'] = stratification.hqmf_id.upcase
          stratified_populations << new_population
        end
      end
      @populations.concat stratified_populations
    end

    # Detects missing unstratified populations from the generated @populations array
    def detect_unstratified
      missing_populations = []
      # populations are keyed off of values rather than the codes
      existing_populations = @populations.map{|p| p.values.join('-')}.uniq
      @populations.each do |population|
        keys = population.keys - ['STRAT','stratification']
        missing_populations |= [population.values_at(*keys).compact.join('-')]
      end

      missing_populations -= existing_populations

      # reverse the order and prepend them to @populations
      missing_populations.reverse.each do |population|
        p = {}
        population.split('-').each do |code|
          p[code.split('_').first] = code
        end
        @populations.unshift p
      end
    end

    def handle_duplicate_pop_criteria(duplicate_pop_criteria, population, population_index, duplicate_offset)
      duplicate_pop_criteria.each do |criteria|
        duplicate_offset += 1
        population = population.dup
        # TODO: Verify that we no longer need to set the criteria.id for duplicate population criteria
        # criteria.id = "#{criteria.type}_#{population_index+duplicate_offset}"
        population[criteria.type] = criteria.id
        @populations << population
      end
    end
  end
end
