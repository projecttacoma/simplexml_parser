module SimpleXml
  
  class Precondition
  
    include SimpleXml::Utilities
   
    FUNCTIONAL_OP = 'functionalOp'
    LOGICAL_OP = 'logicalOp'
    TEMPORAL_OP = 'relationalOp'
    DATA_CRITERIA_OP = 'elementRef'

    attr_reader :id, :preconditions, :reference, :conjunction_code, :negation

    def initialize(entry, doc)
      @doc = doc
      @entry = entry
      entry = nil
      @id = HQMF::Counter.instance.next
      @preconditions = []
      @negation = false
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
      @preconditions = @entry.children.reject {|e| e.name == 'text'}.collect do |precondition|
        Precondition.new(precondition, @doc)
      end
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
        @doc.data_criteria(precondition.reference.id).add_temporal(temporal)
      else
        precondition.preconditions.each {|p| push_down_temporal(p, temporal)}
      end
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
      @negation = other.negation
    end
    
    def to_model
      pcs = preconditions.collect {|p| p.to_model}
      mr = reference ? reference.to_model : nil
      HQMF::Precondition.new(id, pcs, mr, conjunction_code, negation)
    end
  end
    
end