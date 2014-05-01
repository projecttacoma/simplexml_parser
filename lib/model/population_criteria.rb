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


    TITLES = {
      HQMF::PopulationCriteria::IPP => 'Initial Patient Population',
      HQMF::PopulationCriteria::DENOM => 'Denominator',
      HQMF::PopulationCriteria::NUMER => 'Numerator',
      HQMF::PopulationCriteria::DENEXCEP => 'Denominator Exception',
      HQMF::PopulationCriteria::DENEX => 'Denominator Exclusion',
      HQMF::PopulationCriteria::MSRPOPL => 'Measure Population',
      HQMF::PopulationCriteria::OBSERV => 'Measure Observation'
    }

    attr_reader :preconditions, :id, :hqmf_id, :title, :type
    
    # Create a new population criteria from the supplied HQMF entry
    # @param [Nokogiri::XML::Element] the HQMF entry
    def initialize(entry, doc, index)
      @doc = doc
      @entry = entry

      @hqmf_id = attr_val('@uuid')
      @type = translate_type(attr_val('@type'))
      @title = TITLES[@type]

      @id = @type
      @id += "" if (index > 0)

      @preconditions = @entry.xpath('logicalOp').collect do |precondition_def|
        Precondition.new(precondition_def, @doc)
      end
      @preconditions.select! {|p| !p.preconditions.empty? || p.reference}

    end

    def translate_type(type)
      case type
      when IPP
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
      else
        raise "Unknown population criteria type #{type}"
      end
    end
    
    def to_model
      mps = preconditions.collect {|p| p.to_model}
      HQMF::PopulationCriteria.new(id, hqmf_id, type, mps, title)
    end

  end
  
end