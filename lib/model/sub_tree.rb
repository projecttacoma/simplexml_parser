module SimpleXml
  # Represents a data criteria specification
  class SubTree
    include SimpleXml::Utilities
   
    attr_accessor :id, :name, :precondition

    def initialize(entry, doc, negated=false)
      @doc = doc
      @entry = entry

      @id = attr_val('@uuid')
      @name = attr_val('@displayName')

      children = children_of(@entry)
      preconditions = []
      children.each do |child|
        preconditions << Precondition.new(child, doc)
      end
      raise "multiple children of subtree... not clear how to handle this" if preconditions.length > 1
      @precondition = preconditions.first
      convert_to_variable if attr_val('@qdmVariable') == 'true'
  	end

    def convert_to_variable
      # wrap a reference precondition with a parent
      @precondition = ParsedPrecondition.new(HQMF::Counter.instance.next, [@precondition], nil, HQMF::Precondition::ALL_TRUE, false) if @precondition.reference

      # create the grouping data criteria for the variable
      criteria = convert_to_data_criteria('variable')
      criteria.instance_variable_set('@variable', true)
      criteria.instance_variable_set('@description', @entry.attributes['displayName'].value || attr_val('@displayName'))
      criteria.derivation_operator = (@precondition.conjunction_code == HQMF::Precondition::ALL_TRUE) ? HQMF::DataCriteria::INTERSECT : HQMF::DataCriteria::UNION if criteria.children_criteria

      # put variable in source data criteria
      @doc.register_source_data_criteria(criteria)

      # update the reference to the variable data criteria
      @precondition.preconditions = []
      @precondition.reference = Reference.new(criteria.id)
    end

    def convert_to_data_criteria(operator='clause')
      DataCriteria.convert_precondition_to_criteria(@precondition, @doc, operator)
    end
  end
end
