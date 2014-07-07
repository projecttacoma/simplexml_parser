module SimpleXml
  
  class Precondition
  
    include SimpleXml::Utilities
   
    FUNCTIONAL_OP = 'functionalOp'
    LOGICAL_OP = 'logicalOp'
    SET_OP = 'setOp'
    TEMPORAL_OP = 'relationalOp'
    DATA_CRITERIA_OP = 'elementRef'
    SUB_TREE = 'subTreeRef'
    SATISFIES_ALL = 'SATISFIES ALL'
    SATISFIES_ANY = 'SATISFIES ANY'
    AGE_AT = 'AGE AT'

    attr_reader :id, :conjunction_code, :negation
    attr_accessor :preconditions, :reference

    def initialize(entry, doc, negated=false)
      @doc = doc
      @entry = entry
      entry = nil
      @id = HQMF::Counter.instance.next
      @preconditions = []
      @negation = negated
      @subset = nil

      if @entry.name == FUNCTIONAL_OP
        handle_functional
      end

      # if we have a subset then we want this to be a grouping data criteria
      if (@entry.name == LOGICAL_OP || @entry.name == SET_OP) && @subset.nil?
        handle_logical
      elsif @entry.name == TEMPORAL_OP && @subset.nil?
        handle_temporal
      elsif attr_val('@type') == SATISFIES_ALL || attr_val('@type') == SATISFIES_ANY
        handle_satisfies
      elsif @entry.name == DATA_CRITERIA_OP || @subset
        handle_data_criteria
      elsif @entry.name == SUB_TREE
        handle_sub_tree
      else
        raise "unknown precondition type: #{@entry.name}"
      end
    end

    def handle_functional
      type = attr_val('@type')
      case type
      when 'NOT'
        @negation = true
      when SATISFIES_ALL, SATISFIES_ANY
        ''
      when AGE_AT
        handle_age_at
      else
        comparison = attr_val('@operatorType')
        quantity = attr_val('@quantity')
        unit = attr_val('@unit')
        @subset = SubsetOperator.new(type, Utilities.build_value(comparison, quantity, unit))
      end

      children = children_of(@entry)
      if children.count == 1
        @entry = children.first
      end

    end

    def handle_age_at
      # find the birthdate QDM element, if it exists
      birthdate_hqmf_id = nil
      @doc.source_data_criteria.each do |sdc|
        birthdate_hqmf_id = sdc.hqmf_id if sdc.definition == 'patient_characteristic_birthdate'
      end

      # if it doesn't, create one and add it to the document
      if birthdate_hqmf_id.nil?
        default_birthdate = '<qdm datatype="Patient Characteristic Birthdate" id="14574250-746e-4898-8429-2e20255de395" name="birthdate" oid="2.16.840.1.113883.3.117.1.7.1.70" suppDataElement="false" taxonomy="User Defined QDM" uuid="14574250-746e-4898-8429-2e20255de395" version="1.0"/>'
        birthdate_hqmf_id = '14574250-746e-4898-8429-2e20255de395'
        criteria = DataCriteria.new(Document.parse(default_birthdate).child)
        @doc.source_data_criteria << criteria
        @doc.criteria_map[criteria.hqmf_id] = criteria
      end

      # pull out the timing reference and add the birthdate reference
      mpElement = @entry.at_css('elementRef')
      bdElement = @entry.add_child("<elementRef displayName=\"birthdate : Patient Characteristic Birthdate\" id=\"#{birthdate_hqmf_id}\" type=\"qdm\"/>")

      # swap the order of the elements
      bdElement[0].add_next_sibling(mpElement)

      # convert this entry to a temporal precondition with SBS type
      @entry.set_attribute('type','SBS')
      @entry.name = TEMPORAL_OP
    end

    def handle_satisfies

      children = children_of(@entry)

      # remove start and redundant LHS elementRef from entry
      @entry.children[0].remove()
      @entry.children[0].remove()

      @preconditions = []
      children_of(@entry).collect do |precondition|
        # if we have a negated child with multiple logical children, then we want to make sure we don't infer an extra AND
        if negation_with_logical_children?(precondition)
          children_of(precondition).each do |child|
            @preconditions << Precondition.new(child, @doc, true)
          end
        else
          @preconditions << Precondition.new(precondition, @doc)
        end
      end

      push_down_comments(self, comments_on(@entry))

      @preconditions.select! {|p| !p.preconditions.empty? || p.reference }

      if attr_val('@type') == SATISFIES_ALL
        criteria = DataCriteria.convert_precondition_to_criteria(self, @doc, 'satisfiesAll')
        criteria.derivation_operator = HQMF::DataCriteria::INTERSECT
        criteria.instance_variable_set('@definition','satisfies_all')
      elsif attr_val('@type') == SATISFIES_ANY
        criteria = DataCriteria.convert_precondition_to_criteria(self, @doc, 'satisfiesAny')
        criteria.derivation_operator = HQMF::DataCriteria::UNION
        criteria.instance_variable_set('@definition','satisfies_any')
      end
      criteria.instance_variable_set('@description', children[0]['displayName'] || attr_val('@displayName'))

      @preconditions = []
      @reference = Reference.new(criteria.id)
    end

    def handle_logical
      @conjunction_code = translate_type(attr_val('@type'))
      @preconditions = []
      children_of(@entry).collect do |precondition|
        # if we have a negated child with multiple logical children, then we want to make sure we don't infer an extra AND
        if negation_with_logical_children?(precondition)
          children_of(precondition).each do |child|
            @preconditions << Precondition.new(child, @doc, true)
          end
        else
          @preconditions << Precondition.new(precondition, @doc)
        end
      end

      push_down_comments(self, comments_on(@entry))
      
      @preconditions.select! {|p| !p.preconditions.empty? || p.reference }
    end

    def handle_temporal
      type = attr_val('@type')
      comparison = attr_val('@operatorType')
      quantity = attr_val('@quantity')
      unit = attr_val('@unit')
      children = children_of(@entry)

      left_child = children[0]
      right_child = children[1]

      right = DataCriteria.get_criteria(right_child, @id, @doc, @subset, type, false)

      temporal = TemporalReference.new(type, comparison, quantity, unit, right)

      # check to see if we are referening MP start or end and make sure that the timing is appropriate
      update_temporal_mp_reference(temporal, right)

      if (left_child.name == LOGICAL_OP)
        # make this the left and then push down the right... we have no current node to construct
        copy(Precondition.new(left_child, @doc))
        push_down_temporal(self, temporal)
      else
        left = DataCriteria.get_criteria(left_child, @id, @doc, @subset, nil, true)
        left.add_temporal(temporal)
        @reference = Reference.new(left.id)
      end
    end

    def handle_data_criteria
      criteria = DataCriteria.get_criteria(@entry, @id, @doc, @subset, nil, true)
      @reference = Reference.new(criteria.id)
    end

    def handle_sub_tree
      sub_tree = @doc.sub_tree_map[attr_val('@id')]
      copy(sub_tree.precondition)
    end

    def push_down_temporal(precondition, temporal)
      if precondition.preconditions.empty?
        @doc.data_criteria(precondition.reference.id).push_down_temporal(temporal, @doc)
      else
        precondition.preconditions.each {|p| push_down_temporal(p, temporal)}
      end
    end

    def push_down_comments(precondition, comments)
      return if comments.empty?
      if precondition.preconditions.empty?
        @doc.data_criteria(precondition.reference.id).comments = comments
      else
        precondition.preconditions.each {|p| push_down_comments(p, comments)}
      end
    end

    def negation_with_logical_children?(precondition)
      if precondition.name == FUNCTIONAL_OP && precondition.at_xpath('@type').value == 'NOT'
        children = children_of(precondition)
        return children.length > 1
      end
      false
    end

    def translate_type(type)
      case type
      when 'and'
        HQMF::Precondition::ALL_TRUE
      when 'intersection'
        HQMF::Precondition::ALL_TRUE
      when 'or'
        HQMF::Precondition::AT_LEAST_ONE_TRUE
      when 'union'
        HQMF::Precondition::AT_LEAST_ONE_TRUE
      else
        raise "Unknown population criteria type #{type}"
      end
    end

    def copy(other)
      @id = other.id
      @preconditions = other.preconditions
      @reference = other.reference
      @conjunction_code = other.conjunction_code
      # do not copy negation... we want the negation from the parent to remain
      #@negation = other.negation
    end
    
    def to_model
      pcs = preconditions.collect {|p| p.to_model}
      mr = reference ? reference.to_model : nil
      HQMF::Precondition.new(id, pcs, mr, conjunction_code, negation)
    end

    def handle_negations(parent)
      negations = []
      @preconditions.delete_if {|p| negations << p if p.negation}
      unless (negations.empty?)
        negations.each {|p| p.instance_variable_set(:@negation, false) }
        inverted_conjunction_code = HQMF::Precondition::INVERSIONS[conjunction_code]
        
        # if we only have negations, then do not create an extra element
        if @preconditions.empty?
          @negation = true
          @conjunction_code = inverted_conjunction_code
          @preconditions.concat negations
        else
          # create a new inverted element for the subset of the children that are negated
          @preconditions << ParsedPrecondition.new(HQMF::Counter.instance.next, negations, nil, inverted_conjunction_code, true)
        end
      end
      @preconditions.each do |p|
        p.handle_negations(self)
      end
    end

    def update_temporal_mp_reference(temporal, right)

      if (right.id== HQMF::Document::MEASURE_PERIOD_ID)
        references_start = {'SBS'=>'SBE','SAS'=>'SAE','EBS'=>'EBE','EAS'=>'EAE','SCW'=>'SCWE'}
        references_end = {'EBE'=>'EBS','EAE'=>'EAS','SBE'=>'SBS','SAE'=>'SAS','ECW'=>'ECWS'}

        if @doc.measure_period_map[right.hqmf_id] == :measure_period_start && references_end[temporal.type]
          # before or after the END of the measurement period START.  Convert to before or after the START of the measurement period.
          # SAE of MPS => SAS of MP
          # ends concurrent with measurement period START. Convert to concurrent with START of measurement period.
          # ECW of MPS => ECWS
          temporal.type = references_end[temporal.type]
        elsif @doc.measure_period_map[right.hqmf_id] == :measure_period_end && references_start[temporal.type]
          # before or after the START of the measurement period END.  Convert to before or after the END of the measurement period.
          # SBS of MPE => SBE of MP
          # starts concurrent with measurement period END. Convert to concurrent with END of measurement period.
          # SCW of MPE => SCWE
          temporal.type = references_start[temporal.type]
        end


      end
    end

  end

  class ParsedPrecondition
    attr_accessor :id, :preconditions, :reference, :conjunction_code, :negation
    def initialize(id, preconditions, reference, conjunction_code, negation)
      @id = id
      @preconditions = preconditions
      @reference = reference
      @conjunction_code = conjunction_code
      @negation = negation
    end
    # negations already handled since parsed prconditions came from handling the parent's negations... just continue
    def handle_negations(parent)
      @preconditions.each do |p|
        p.handle_negations(self)
      end
    end
    def to_model
      pcs = preconditions.collect {|p| p.to_model}
      mr = reference ? reference.to_model : nil
      HQMF::Precondition.new(id, pcs, mr, conjunction_code, negation)
    end
  end
    
end