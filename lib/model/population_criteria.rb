module SimpleXml
  # Represents an HQMF population criteria, also supports all the same methods as
  # SimpleXml::Precondition
  class PopulationCriteria
  
    include SimpleXml::Utilities
    
    IPP = 'initialPatientPopulation'
    DENOM = 'denominator'
    DENEX = 'denominatorExclusions'
    DENEXCEP = 'denominatorExceptions'
    NUMER = 'numerator'
    MSRPOPL = 'measurePopulation'
    OBSERV = 'measureObservation'
    STRAT = "stratum"
    NUMEX = "numeratorExclusions"
    MSRPOPLEX='measurePopulationExclusions'


    TITLES = {
      HQMF::PopulationCriteria::IPP => 'Initial Patient Population',
      HQMF::PopulationCriteria::DENOM => 'Denominator',
      HQMF::PopulationCriteria::NUMER => 'Numerator',
      HQMF::PopulationCriteria::DENEXCEP => 'Denominator Exception',
      HQMF::PopulationCriteria::DENEX => 'Denominator Exclusion',
      HQMF::PopulationCriteria::MSRPOPL => 'Measure Population',
      HQMF::PopulationCriteria::OBSERV => 'Measure Observation',
      HQMF::PopulationCriteria::MSRPOPLEX => 'Measure Population Exclusion'
    }

    attr_accessor :id, :hqmf_id, :aggregator
    attr_reader :preconditions, :title, :type, :entry
    
    # Create a new population criteria from the supplied HQMF entry
    # @param [Nokogiri::XML::Element] the HQMF entry
    def initialize(entry, doc, index)
      @doc = doc
      @entry = entry

      @hqmf_id = attr_val('@uuid')
      @type = translate_type(attr_val('@type'))
      @title = TITLES[@type]

      @id = @type
      @id += "_#{index}" if (index > 0)

      @preconditions = @entry.xpath("#{Precondition::LOGICAL_OP}|#{Precondition::SUB_TREE}").collect do |precondition_def|
        Precondition.new(precondition_def, @doc)
      end
      @preconditions.select! {|p| !p.preconditions.empty? || p.reference}

      handle_negations

    end

    def set_index(index)
      @id = @type
      @id += "_#{index}" if (index > 0)
    end

    def translate_type(type)
      case type
      when IPP, 'initialPopulation'
        HQMF::PopulationCriteria::IPP
      when DENOM
        HQMF::PopulationCriteria::DENOM
      when DENEX
        HQMF::PopulationCriteria::DENEX
      when DENEXCEP
        HQMF::PopulationCriteria::DENEXCEP
      when NUMER
        HQMF::PopulationCriteria::NUMER
      when MSRPOPL
        HQMF::PopulationCriteria::MSRPOPL
      when OBSERV
        HQMF::PopulationCriteria::OBSERV
      when STRAT
        HQMF::PopulationCriteria::STRAT
      when NUMEX
        NUMEX
      when MSRPOPLEX
        HQMF::PopulationCriteria::MSRPOPLEX
      else
        raise "Unknown population criteria type #{type}"
      end
    end

    def handle_negations
      @preconditions.each do |p|
        p.handle_negations(self)
      end
    end

    def get_logic_leaves(children=nil)
      children ||= @preconditions
      leaves = []
      children.each do |precondition|
        unless (precondition.preconditions.empty?)
          leaves.concat get_logic_leaves(precondition.preconditions)
        else
          leaves << precondition
        end
      end
      leaves
    end
    
    def to_model
      mps = preconditions.collect {|p| p.to_model}
      HQMF::PopulationCriteria.new(id, hqmf_id, type, mps, title, aggregator):
    end

  end
  
end