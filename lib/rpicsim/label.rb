# @api public
module RPicSim
  # A very simple class that represents a label in firmware.
  # @api public
  class Label
    # The name of the label from the firmware.
    # @return (Symbol)
    attr_reader :name

    # The address/value of the label from the firmware.
    # @return (Integer)
    attr_reader :address

    # Makes a new label with the specified name and address.
    # @api private
    def initialize(name, address)
      @name = name
      @address = address
    end

    # Returns the address of the label.
    #
    # @return [Integer]
    def to_i
      address
    end

    # Returns a nice string representation of the label.
    #
    # @return [String]
    def to_s
      '<Label %s address=0x%x>' % [name, address]
    end
  end
end
