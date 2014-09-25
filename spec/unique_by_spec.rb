require 'unique_by'

module BaseBill
  def self.included(base)
    super
    base.extend UniqueBy::Generator
    base.extend ClassMethods
  end

  module ClassMethods
    def primary_key
      :bill_id
    end

    def find_by_bill_id(bill_id)
    end

    def find_by_bill_id!(bill_id)
    end
  end
end

class TablesBase < Struct.new(:bill_id)
  include BaseBill
end

class ShardedTablesBase < Struct.new(:bill_id, :client_id, :x)
  include BaseBill
end

describe UniqueBy::Generator do
  shared_context "finder methods" do
    specify "find_by_bill_id" do
      expect(klass).to receive(:find_by_bill_id).with(id)
      klass.find_by_unique_bill_id(unique_id)
    end
    specify "find_by_bill_id!" do
      expect(klass).to receive(:find_by_bill_id!).with(id)
      klass.find_by_unique_bill_id!(unique_id)
    end
  end

  context "shards" do
    let(:klass) do
      Class.new(Struct.new(:bill_id, :client_id)) do
        include BaseBill
        unique_by(client_id: 10)
      end
    end

    let(:bill1) { klass.new(431, 2) }
    let(:bill2) { klass.new(431, 7) }
    let(:id) { 431 }

    context "bill1" do
      let(:unique_id) { (431 << 4) + (2 % 16) }
      subject { bill1 }

      describe "class methods" do
        specify { expect(klass.bill_id_group_value_from(client_id: 2)).to eq(2 % 16) }
        specify { expect(klass.unique_bill_id_from(431, client_id: 2)).to eq(unique_id) }
        specify { expect(klass.bill_id_from(unique_id)).to eq(431) }
        specify { expect(klass.bill_id_group_from(unique_id)).to eq(client_id: 2 % 16) }

        context "nil id" do
          specify { expect(klass.unique_bill_id_from(nil, client_id: 2)).to be_nil }
          specify { expect(klass.bill_id_from(nil)).to be_nil }
          specify { expect(klass.bill_id_group_from(nil)).to be_nil }
        end

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == { client_id: 2 } }
        its(:unique_bill_id) { should == unique_id }

        context "nil id" do
          before { bill1.bill_id = nil }
          its(:unique_bill_id) { should be_nil }
        end
      end
    end

    context "bill2" do
      let(:unique_id) { (431 << 4) + (7 % 16) }
      subject { bill2 }

      describe "class methods" do
        specify { expect(klass.bill_id_group_value_from(client_id: 7)).to eq(7 % 16) }
        specify { expect(klass.unique_bill_id_from(431, client_id: 7)).to eq(unique_id) }
        specify { expect(klass.bill_id_from(unique_id)).to eq(431) }
        specify { expect(klass.bill_id_group_from(unique_id)).to eq(client_id: 7 % 16) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == { client_id: 7 } }
        its(:unique_bill_id) { should == unique_id }
      end
    end
  end

  context "tables" do
    let(:medical_klass) do
      Class.new(TablesBase) do
        unique_by(type: 2) { { type: 10 } }
      end
    end
    let(:utility_klass) do
      Class.new(TablesBase) do
        unique_by(type: 2) { { type: 11 } }
      end
    end

    let(:medical_bill) { medical_klass.new(839) }
    let(:utility_bill) { utility_klass.new(839) }
    let(:id) { 839 }

    context "medical bill" do
      let(:klass) { medical_klass }
      let(:unique_id) { (839 << 1) + (10 % 2) }
      subject { medical_bill }

      describe "class methods" do
        specify { expect(medical_klass.bill_id_group_value_from(type: 10)).to eq(10 % 2) }
        specify { expect(medical_klass.unique_bill_id_from(839, type: 10)).to eq(unique_id) }
        specify { expect(medical_klass.bill_id_from(unique_id)).to eq(839) }
        specify { expect(medical_klass.bill_id_group_from(unique_id)).to eq(type: 10 % 2) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == { type: 10 } }
        its(:unique_bill_id) { should == unique_id }
      end
    end

    context "utility bill" do
      let(:klass) { utility_klass }
      let(:unique_id) { (839 << 1) + (11 % 2) }
      subject { utility_bill }

      describe "class methods" do
        specify { expect(utility_klass.bill_id_group_value_from(type: 11)).to eq(11 % 2) }
        specify { expect(utility_klass.unique_bill_id_from(839, type: 11)).to eq(unique_id) }
        specify { expect(utility_klass.bill_id_from(unique_id)).to eq(839) }
        specify { expect(utility_klass.bill_id_group_from(unique_id)).to eq(type: 11 % 2) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == { type: 11 } }
        its(:unique_bill_id) { should == unique_id }
      end
    end
  end

  context "sharded tables" do
    let(:medical_klass) do
      Class.new(ShardedTablesBase) do
        unique_by(client_id: 10, x: 200, type: 2, y: 20) { { type: 10, y: y } }
        def x
          53
        end
        def y
          20
        end
      end
    end

    let(:utility_klass) do
      Class.new(ShardedTablesBase) do
        unique_by(client_id: 2**4, x: 2**8, type: 2**1, y: 2**5) { { type: 11, y: y } }
        def x
          853
        end
        def y
          40
        end
      end
    end

    let(:medical_bill) { medical_klass.new(9428, 5, 128) }
    let(:utility_bill) { utility_klass.new(9428, 8, 255) }
    let(:id) { 9428 }

    context "medical bill" do
      let(:klass) { medical_klass }
      subject { medical_bill }

      let(:tempered_group) { { client_id: 5 % 16, x: 53 % 256, type: 10 % 2, y: 20 % 32 } }
      let(:group_value) { ((5 % 16) << 14) + ((53 % 256) << 6) + ((10 % 2) << 5) + (20 % 32) }
      let(:unique_id) { (9428 << 18) + group_value }

      describe "class methods" do
        specify { expect(medical_klass.bill_id_group_value_from(client_id: 5, x: 53, type: 10, y: 20)).to eq(group_value) }
        specify { expect(medical_klass.unique_bill_id_from(9428, client_id: 5, x: 53, type: 10, y: 20)).to eq(unique_id) }
        specify { expect(medical_klass.bill_id_from(unique_id)).to eq(9428) }
        specify { expect(medical_klass.bill_id_group_from(unique_id)).to eq(tempered_group) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == { client_id: 5, x: 53, type: 10, y: 20 } }
        its(:unique_bill_id) { should == unique_id }
      end
    end

    context "utility bill" do
      let(:klass) { utility_klass }
      subject { utility_bill }

      let(:tempered_group) { { client_id: 8 % 16, x: 853 % 256, type: 11 % 2, y: 40 % 32 } }
      let(:group_value) { ((8 % 16) << 14) + ((853 % 256) << 6) + ((11 % 2) << 5) + (40 % 32) }
      let(:unique_id) { (9428 << 18) + group_value }

      describe "class methods" do
        specify { expect(utility_klass.bill_id_group_value_from(client_id: 8, x: 853, type: 11, y: 40)).to eq(group_value) }
        specify { expect(utility_klass.unique_bill_id_from(9428, client_id: 8, x: 853, type: 11, y: 40)).to eq(unique_id) }
        specify { expect(utility_klass.bill_id_from(unique_id)).to eq(9428) }
        specify { expect(utility_klass.bill_id_group_from(unique_id)).to eq(tempered_group) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == { client_id: 8, x: 853, type: 11, y: 40 } }
        its(:unique_bill_id) { should == unique_id }
      end
    end
  end

  context "errors" do
    describe "#unique_by" do
      let(:klass) do
        Class.new do
          include BaseBill
        end
      end

      specify { expect { klass.unique_by }.to raise_error(ArgumentError, "must pass a group definition (Hash of name => total)") }
      specify { expect { klass.unique_by(x: :a) }.to raise_error(ArgumentError, "group definition must be a Hash of name => Fixnum, {:x=>:a} given") }
    end

    describe "class methods" do
      let(:klass) do
        Class.new(Struct.new(:bill_id, :client_id)) do
          include BaseBill
          unique_by client_id: 10
        end
      end

      specify { expect { klass.bill_id_group_value_from(x: 2) }.to raise_error(ArgumentError, "unknown bill_id group keys: [:x]") }
      specify { expect { klass.bill_id_group_value_from(client_id: 5, x: 2) }.to raise_error(ArgumentError, "unknown bill_id group keys: [:x]") }
      specify { expect { klass.bill_id_group_value_from() }.to raise_error(ArgumentError, "missing bill_id group keys: [:client_id]") }
      specify { expect { klass.bill_id_group_value_from(client_id: nil) }.to raise_error(TypeError, "bill_id group client_id must not be nil") }
      specify { expect { klass.bill_id_group_value_from(client_id: :a) }.to raise_error(TypeError, "bill_id group client_id must implement #to_i, :a given") }
      specify { expect { klass.unique_bill_id_from(431, client_id: nil) }.to raise_error(TypeError, "bill_id group client_id must not be nil") }
      specify { expect { klass.unique_bill_id_from(431, client_id: :a) }.to raise_error(TypeError, "bill_id group client_id must implement #to_i, :a given") }
      specify { expect { klass.unique_bill_id_from(:a, client_id: 5) }.to raise_error(TypeError, "bill_id must implement #to_i, :a given") }
      specify { expect { klass.bill_id_from(:a) }.to raise_error(TypeError, "unique_bill_id must implement #to_i, :a given") }
      specify { expect { klass.bill_id_group_from(:a) }.to raise_error(TypeError, "unique_bill_id must implement #to_i, :a given") }
    end

    describe "instance methods" do
      let(:klass) do
        Class.new(Struct.new(:bill_id, :client_id, :block)) do
          include BaseBill
          unique_by(client_id: 10, x: 5) { block }
        end
      end

      context "nil group" do
        let(:bill) { klass.new(431, nil, { x: 2 }) }
        specify { expect { bill.unique_bill_id }.to raise_error(TypeError, "bill_id group client_id must not be nil") }
      end

      context "invalid group" do
        let(:bill) { klass.new(431, :a, { x: 2 }) }
        specify { expect { bill.unique_bill_id }.to raise_error(TypeError, "bill_id group client_id must implement #to_i, :a given") }
      end

      context "nil block group" do
        let(:bill) { klass.new(431, 5, { x: nil }) }
        specify { expect { bill.unique_bill_id }.to raise_error(TypeError, "bill_id group x must not be nil") }
      end

      context "invalid block group" do
        let(:bill) { klass.new(431, 5, :a) }
        specify { expect { bill.unique_bill_id }.to raise_error(TypeError, "bill_id group block must return a Hash with any of the following keys: [:client_id, :x], :a given") }
      end

      context "invalid block group value" do
        let(:bill) { klass.new(431, 5, { x: :a }) }
        specify { expect { bill.unique_bill_id }.to raise_error(TypeError, "bill_id group x must implement #to_i, :a given") }
      end

      context "unknown block group keys" do
        context "too few" do
          let(:bill) { klass.new(431, 5, { }) }
          specify { expect { bill.unique_bill_id }.to raise_error(NameError, "undefined method `x' for #<struct bill_id=431, client_id=5, block={}>") }
        end

        context "too many" do
          let(:bill) { klass.new(431, 5, { x: 2, y: 12 }) }
          specify { expect { bill.unique_bill_id }.to raise_error(ArgumentError, "unknown bill_id group passed to block: [:y]") }
        end

        context "different" do
          let(:bill) { klass.new(431, 5, { y: 12 }) }
          specify { expect { bill.unique_bill_id }.to raise_error(ArgumentError, "unknown bill_id group passed to block: [:y]") }
        end
      end
    end
  end
end