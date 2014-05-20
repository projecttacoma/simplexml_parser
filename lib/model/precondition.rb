module SimpleXml
  
  class Precondition
  
    include SimpleXml::Utilities
   
    FUNCTIONAL_OP = 'functionalOp'
    LOGICAL_OP = 'logicalOp'
    TEMPORAL_OP = 'relationalOp'
    DATA_CRITERIA_OP = 'elementRef'

    attr_reader :id, :preconditions, :reference, :conjunction_code, :negation

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
      # we can also have an inferred_and if we have a not with multiple children
      if (@entry.name == LOGICAL_OP || @inferred_and) && @subset.nil?
        handle_logical
      elsif @entry.name == TEMPORAL_OP && @subset.nil?
        handle_temporal
      elsif @entry.name == DATA_CRITERIA_OP || @subset
        handle_data_criteria
      else
        raise "unknown precondition type: #{@entry.name}"
      end
    end

    def handle_functional
      type = attr_val('@type')
      case type
      when 'NOT'
        @negation = true
      else
        comparison = attr_val('@operatorType')
        quantity = attr_val('@quantity')
        unit = attr_val('@unit')
        @subset = SubsetOperator.new(type, Utilities.build_value(comparison, quantity, unit))
      end

      children = @entry.children.reject {|e| e.name == 'text'}
      if children.count == 1
        @entry = children.first
      else
        # we have negations that do not have an AND under them... the AND is inferred
        @inferred_and = true
      end

    end

    def handle_logical
      @conjunction_code = translate_type(attr_val('@type'))
      @preconditions = []
      @entry.children.reject {|e| e.name == 'text'}.collect do |precondition|
        # if we have a negated child with multiple logical children, then we want to make sure we don't infer an extra AND
        if negation_with_logical_children?(precondition)
          precondition.children.reject {|e| e.name == 'text'}.each do |child|
            @preconditions << Precondition.new(child, @doc, true)
          end
        else
          @preconditions << Precondition.new(precondition, @doc)
        end

      end
     
      @preconditions.select! {|p| !p.preconditions.empty? || p.reference}

    end

    def handle_temporal
      type = attr_val('@type')
      comparison = attr_val('@operatorType')
      quantity = attr_val('@quantity')
      unit = attr_val('@unit')
      children = @entry.children.reject {|e| e.name == 'text'}

      left_child = children[0]
      right_child = children[1]

      right = DataCriteria.get_criteria(right_child, @id, @doc, @subset, type, false)
      temporal = TemporalReference.new(type, comparison, quantity, unit, right)

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

    def push_down_temporal(precondition, temporal)
      if precondition.preconditions.empty?
        @doc.data_criteria(precondition.reference.id).push_down_temporal(temporal, @doc)
      else
        precondition.preconditions.each {|p| push_down_temporal(p, temporal)}
      end
    end

    def negation_with_logical_children?(precondition)
      if precondition.name == FUNCTIONAL_OP && precondition.at_xpath('@type').value == 'NOT'
        children = precondition.children.reject {|e| e.name == 'text'}
        if (children.length > 1)
          return children.count == children.select {|c| c.name == LOGICAL_OP}.count
        end
      end
      false
    end

    def translate_type(type)
      case type
      when 'and'
        HQMF::Precondition::ALL_TRUE
      when 'or'
        HQMF::Precondition::AT_LEAST_ONE_TRUE
      else
        if @inferred_and
          HQMF::Precondition::ALL_TRUE
        else
          raise "Unknown population criteria type #{type}"
        end
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
          @preconditions << ParsedPrecondition.new(nil, negations, nil, inverted_conjunction_code, true)
        end
      end
      @preconditions.each do |p|
        p.handle_negations(self)
      end
    end

  end

  class ParsedPrecondition
    attr_reader :id, :preconditions, :reference, :conjunction_code, :negation
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