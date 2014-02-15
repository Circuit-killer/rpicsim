require_relative '../spec_helper'

describe RPicSim::ProgramFile do
  subject(:program_file) do
    Firmware::FlashVariables.program_file
  end

  describe '#address_description' do
    specify { subject.address_description(0x0000).should == "0x0000 = setupNormalFlash" }
    specify { subject.address_description(0x0001).should == "0x0001 = setupNormalFlash+0x1" }
    specify { subject.address_description(0x0006).should == "0x0006 = setupUserId0+0x1" }
    specify { subject.address_description(-1).should == "-1" }
  end

end

describe 'RPicSim disassembly' do
  let(:opcode) { example.metadata[:opcode] }
  let(:address) { @program_file.label('ins_' + opcode.downcase).address }
  let(:address_increment) { example.metadata[:address_increment] }
  
  let(:instruction0) { @program_file.instruction(address) }
  let(:instruction1) { @program_file.instruction(address + address_increment) }
  
  shared_examples_for 'instruction' do |opts = {}|
    size = opts[:size] || metadata[:address_increment]
  
    it 'has the right address' do
      expect(instruction0.address).to eq address
    end
      
    it "has opcode #{metadata[:opcode]}" do
      expect(instruction0.opcode).to eq opcode
    end

    it "has size #{size}" do
      # the PIC18 stores flash addresses in terms of bytes, not words
      expect(instruction0.size).to eq size
    end

  end
  
  shared_examples_for 'conditional skip' do
    it 'leads to the next two instructions after it' do
      expect(instruction0.next_addresses).to eq [address + address_increment, address + address_increment * 2]
    end
  end
  
  shared_examples_for 'instruction with fields f and a' do
    string = metadata[:opcode] + ' 0x4, ACCESS'
    it "has string #{string}'" do
      expect(instruction0.string).to eq string
    end
  
    it 'can properly decode all fields' do
      expect(instruction0.operands).to eq(f: 4, a: 0)
      expect(instruction1.operands).to eq(f: 5, a: 1)
    end
  end
  
  shared_examples_for 'instruction with fields f, d, and a' do
    string = metadata[:opcode] + ' 0x4, F, ACCESS'
    it "has string #{string}'" do
      expect(instruction0.string).to eq string
    end
  
    it 'can properly decode all fields' do
      expect(instruction0.operands).to eq(f: 4, d: 1, a: 0)
      expect(instruction1.operands).to eq(f: 5, d: 0, a: 1)
    end
  end
  
  shared_examples_for 'instruction with field k' do
    string = metadata[:opcode] + ' 0x2'
    it "has string #{string}'" do
      expect(instruction0.string).to eq string
    end

    it 'k operand with a word address in it' do
      expected_k = 2 / example.metadata[:address_increment]
      expect(instruction0.operands).to eq(k: expected_k)
    end
  end
  
  context 'for PIC18 architecture', address_increment: 2 do
    before(:all) do
      @program_file = RPicSim::ProgramFile.new(Firmware::Test18F25K50.filename, Firmware::Test18F25K50.device)
    end
    
    context 'byte-oriented operations' do
    
      describe 'ADDWF', opcode: 'ADDWF' do
        it_behaves_like 'instruction'
        it_behaves_like 'instruction with fields f, d, and a'
      end
      
      describe 'ADDWFC', opcode: 'ADDWFC' do
        it_behaves_like 'instruction'
        it_behaves_like 'instruction with fields f, d, and a'    
      end

      describe 'CPFSEQ', opcode: 'CPFSEQ' do
        it_behaves_like 'instruction', string: 'CPFSEQ 0x4, ACCESS'
        it_behaves_like 'instruction with fields f and a'
        it_behaves_like 'conditional skip'
      end
      
      describe 'CPFSGT', opcode: 'CPFSGT' do
        it_behaves_like 'instruction', string: 'CPFSGT 0x4, ACCESS'
        it_behaves_like 'instruction with fields f and a'
        it_behaves_like 'conditional skip'
      end
      
      describe 'CPFSLT', opcode: 'CPFSLT' do
        it_behaves_like 'instruction', string: 'CPFSLT 0x4, ACCESS'
        it_behaves_like 'instruction with fields f and a'
        it_behaves_like 'conditional skip'
      end

    end
    
    context 'control oeprations' do
          
      describe 'GOTO', opcode: 'GOTO' do
        it_behaves_like 'instruction', size: 4
        it_behaves_like 'instruction with field k'
        
        it 'leads to the instruction specified by k' do
          expect(instruction0.next_addresses).to eq [2]
        end
      end

    end
    

  end

end
