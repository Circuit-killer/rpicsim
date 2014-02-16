module RPicSim
  # Instances of this class represent a particular instruction at a particular
  # address in program memory.  This class takes low-level information about a
  # disassembled instruction and produces high-level information about what that
  # instruction is and how it behaves.
  #
  # Instances of this class have links to the other instructions that the instruction
  # could lead to, so the instances form a graph.  This graph is traversed by
  # classes like {CallStackInfo} to get useful information about the firmware.
  class Instruction
    include Comparable
    
    # The flash address of the instruction.
    # For PIC18s this will be the byte address.
    # For other PIC architectures, it will be the word address.
    # @return (Integer)
    attr_reader :address
    
    # The opcode as a capitalized string (e.g. "MOVLW").
    # @return (String)
    attr_reader :opcode
    
    # The operands of the instruction as a hash like { "k" => 92 }.
    # @return (Hash)
    attr_reader :operands
    
    # The number of flash address units that this instruction takes.
    # The units of this are the same as the units of {#address}.
    # @return (Integer)
    attr_reader :size
    
    # A line of assembly language that would represent this instruction.
    # For example "GOTO 0x2".
    # @return (String)
    attr_reader :string

    # Creates a new instruction.
    # @param instruction_store some object such as {ProgramFile} that responds to #instruction and #address_description.
    def initialize(address, instruction_store, opcode, operands, size, address_increment, string, properties)
      @address = address
      @instruction_store = instruction_store
      @opcode = opcode
      @operands = operands
      @size = size
      @address_increment = address_increment
      @string = string
      
      modules = {
        conditional_skip: ConditionalSkip,
        conditional_relative_branch: ConditionalRelativeBranch,
        goto: Goto,
        return: Return,
        call: Call
      }
      
      properties.each do |p|
        mod = modules[p]
        if !mod
          raise ArgumentError, "Invalid property: #{p.inspect}."
        end
        extend mod
      end
    end
    
    # Compares this instruction to another using the addresses.  This means you can
    # call +.sort+ on an array of instructions to put them in order by address.
    def <=>(other)
      self.address <=> other.address
    end

    # Human-readable string representation of the instruction.
    def to_s
      "Instruction(#{@instruction_store.address_description(address)}, #{@string})"
    end
    
    def inspect
      "#<#{self.class}:#{@instruction_store.address_description(address)}, #{@string}>"
    end
    
    # Returns info about all the instructions that this instruction could directly lead to
    # (not counting interrupts, returns, and not accounting
    # at all for what happens after the last word in flash is executed).
    # For instructions that pop from the call stack like RETURN and RETFIE, this will be
    # the empty array.
    # @return [Array(Transition)]
    def transitions
      @transitions ||= generate_transitions
    end
    
    # Returns the transition from this instruction to the specified instruction
    # or nil if no such transition exists.
    # @return Transition
    def transition_to(instruction)
      @transitions.find { |t| t.next_instruction == instruction }
    end

    # Returns the addresses of all the instructions this instruction could directly lead to.
    # @return [Array(Integer)]
    def next_addresses
      transitions.collect(&:next_address)
    end

    private
    # For certain opcodes, this method gets over-written.
    def generate_transitions
      [ advance(1) ]
    end
    
    # Makes a transition representing the default behavior: the microcontroller
    # will increment the program counter and execute the next instruction in memory.
    def advance(num)
      transition(address + num * size)
    end
    
    def transition(addr, attrs={})
      Transition.new(self, addr, @instruction_store, attrs)
    end
    
    private
    # Returns the address indicated by the operand 'k'.
    # k is assumed to be a word address and it is assumed to be absolute
    # k=0 is word 0 of memory, k=1 is word one.
    # We need to multiply by the address increment because on PIC18
    # flash addresses are actually byte-based instead of word-based.
    def k_address
      operands[:k] * @address_increment
    end
    
    def n_address
      address + @address_increment * (operands[:n] + 1)
    end
    
    ### Modules that modify the behavior of the instruction. ###
    
    
    # This module is mixed into any {Instruction} that represents a goto or branch.
    module Goto
      def generate_transitions
        # Assumption: The GOTO instruction's k operand is absolute on all architectures
        [ transition(k_address, non_local: true) ]
      end
    end
    
    # This module is mixed into any {Instruction} that represents a conditional skip
    # A conditional skip is an instruction that might cause the next instruction to be
    # skipped depending on some condition.
    module ConditionalSkip
      def generate_transitions
        [ advance(1), advance(2) ]
      end
    end
    
    # This module is mixed into any {Instruction} that represents a return from a subroutine.
    module Return
      def generate_transitions
        []
      end
    end
    
    # This module is mixed into any {Instruction} that represents a subroutine call.
    module Call
      def generate_transitions
        [ transition(k_address, call_depth_change: 1), advance(1) ]
      end
    end
    
    module ConditionalRelativeBranch
      def generate_transitions
        [ transition(n_address, non_local: true), advance(1) ]
      end
    end
    
    class Transition
      attr_reader :previous_instruction
    
      def initialize(previous_instruction, next_address, instruction_store, attrs)
        @previous_instruction = previous_instruction
        @next_address = next_address
        @instruction_store = instruction_store
        @attrs = attrs
      end
      
      def next_address
        @next_address
      end
      
      def next_instruction
        @next_instruction ||= @instruction_store.instruction(next_address)
      end
      
      def non_local?
        @attrs.fetch(:non_local, false)
      end
      
      def call_depth_change
        @attrs.fetch(:call_depth_change, 0)
      end
    end
  end
end