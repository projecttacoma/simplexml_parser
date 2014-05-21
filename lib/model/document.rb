module SimpleXml
  # Class representing an HQMF document
  class Document
    include SimpleXml::Utilities
    attr_reader :measure_period, :id, :nqf_id, :hqmf_set_id, :hqmf_version_number, :cms_id, :title, :description, :populations, :attributes, :source_data_criteria, :derived_data_criteria, :criteria_map, :attribute_map, :measure_period_map

    MEASURE_PERIOD_TITLES = {'Measurement Period'=>:measure_period, 'Measurement Start Date'=>:measure_period_start, 'Measurement End Date'=>:measure_period_end}
      
    # Create a new SimpleXml::Document instance by parsing at file at the supplied path
    # @param [String] path the path to the HQMF document
    def initialize(xml_contents)
      @doc = @entry = Document.parse(xml_contents)
      details = @doc.at_xpath('measure/measureDetails')
      @id = details.at_xpath('uuid').text.upcase
      @hqmf_set_id = details.at_xpath('guid').text.upcase
      @hqmf_version_number = details.at_xpath('version').text.to_i
      @title = details.at_xpath('title').text
      @description = details.at_xpath('description').text
      @cms_id = "CMS#{details.at_xpath('emeasureid').text}v#{@hqmf_version_number}"
      @nqf_id = details.at_xpath('nqfid/@extension').value

      @attributes = []
      details.children.reject {|e| e.name == 'text'}.each do |attribute|
        attribute_data = Utilities::MEASURE_ATTRIBUTES_MAP[attribute.name.to_sym]
        if (attribute_data)
          attribute_data['value'] = attribute.at_xpath('@extension').try(:value) || attribute.text
          @attributes << HQMF::Attribute.from_json(attribute_data)
        end
      end

      @criteria_map = {}
      @measure_period_map = {
        details.at_xpath('period/@uuid').value => :measure_period,
        details.at_xpath('period/startDate/@uuid').value => :measure_period_start,
        details.at_xpath('period/stopDate/@uuid').value => :measure_period_end
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
    def self.parse(hqmf_contents)
      doc = Nokogiri::XML(hqmf_contents)
      doc
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

    def handle_stratifications
      ipp_keys = populations.map {|p| p[HQMF::PopulationCriteria::IPP]}.uniq
  
      stratified_populations = []
      populations.each do |population|
        @stratifications.each_with_index do |stratification, strat_index|

          ipp = population_criteria(population[HQMF::PopulationCriteria::IPP])
          new_ipp = PopulationCriteria.new(ipp.entry, self, ipp_keys.length + strat_index)
          new_ipp.hqmf_id = stratification.hqmf_id.upcase
          
          # we want to join together the ANDs for the IPP and the strat... unless the strat is negated, then just add it as a child
          if (stratification.preconditions.first.negation)
            strat_children = stratification.preconditions
            negated = true
          else
            strat_children = stratification.preconditions.first.preconditions
          end
          new_ipp_children = new_ipp.preconditions.first.preconditions

          new_ipp_children.concat(strat_children)
          new_ipp_children.rotate!(-1*strat_children.length) unless negated

          @population_criteria << new_ipp
          new_population = population.dup
          new_population[HQMF::PopulationCriteria::IPP] = new_ipp.id
          new_population['stratification'] = stratification.hqmf_id.upcase
          new_population['title'] = "Population #{populations.length + strat_index+1}"
          new_population['id'] = "Population#{populations.length + strat_index+1}"

          stratified_populations << new_population

        #   ids = stratification.preconditions.map(&:id)
        #   new_population.preconditions.delete_if {|precondition| ids.include? precondition.id}

        end
      end
      populations.concat stratified_populations
    end
    
    private
    
    def find(collection, attribute, value)
      collection.find {|e| e.send(attribute)==value}
    end

    def extract_data_criteria
      @source_data_criteria = []
      @derived_data_criteria = []
      @attribute_map = {}
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

    def extract_supplemental_data
      # add supplemental data elements
      @doc.xpath('measure/supplementalDataElements/elementRef').each do |supplemental|
        @derived_data_criteria << @criteria_map[supplemental.at_xpath('@id').value]
      end
    end

    def handle_populations
      # Extract any stratifications, 
      # stratifications must be extracted before population criteria for titles to be generated properly
      extract_stratifications

      # Extract the population criteria and population collections
      extract_population_criteria

      if (@stratifications.length > 0)
        handle_stratifications
      end
    end

    def extract_population_criteria
      @populations = []
      @population_criteria = []
      
      duplicate_offset = 0
      population_defs = @doc.xpath('measure/measureGrouping/group').to_a.sort! {|l,r| l.at_xpath('@sequence').value <=> r.at_xpath('@sequence').value}
      population_defs.each_with_index do |population_def, population_index|
        group_criteria = []
        population_def.xpath('clause').each do |criteria_def|
          group_criteria << PopulationCriteria.new(criteria_def, self, population_index+duplicate_offset)
        end

        @doc.xpath('measure/measureObservations').children.reject {|e| e.name == 'text'}.each_with_index do |observ_def, observ_index|
          group_criteria << rewrite_observ(PopulationCriteria.new(observ_def, self, observ_index))
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
        population['id'] = "Population#{population_index+1+duplicate_offset}"
        population['title'] = "Population #{population_index+1+duplicate_offset}" if population_defs.length > 1 || !duplicate_pop_criteria.empty? || !@stratifications.empty?
        @populations << population

        # if we have duplicates of a criteria, we want to clone the population for those
        unless duplicate_pop_criteria.empty?
          handle_duplicate_pop_criteria(duplicate_pop_criteria, population, population_index, duplicate_offset)
        end

        @population_criteria.concat group_criteria

      end
    end

    def extract_stratifications
      @stratifications = []
      @doc.xpath('measure/strata/clause').each_with_index do |strata_def, index|
        @stratifications << PopulationCriteria.new(strata_def, self, index)
      end
      @stratifications.reject! {|s| s.preconditions.empty? }
    end

    def handle_duplicate_pop_criteria(duplicate_pop_criteria, population, population_index, duplicate_offset)
      duplicate_pop_criteria.each do |criteria|
        duplicate_offset += 1
        population = population.dup
        criteria.id = "#{criteria.type}_#{population_index+duplicate_offset}"
        population[criteria.type] = criteria.id
        population['id'] = "Population#{population_index+1+duplicate_offset}"
        population['title'] = "Population #{population_index+1+duplicate_offset}"
        @populations << population
      end
    end
  end
end
