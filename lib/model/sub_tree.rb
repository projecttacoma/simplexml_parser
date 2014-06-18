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

  	end
  end
end
