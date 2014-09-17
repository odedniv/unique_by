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
        unique_by(:client_id, total: 10)
      end
    end

    let(:bill1) { klass.new(431, 2) }
    let(:bill2) { klass.new(431, 7) }
    let(:id) { 431 }

    context "bill1" do
      let(:unique_id) { (431 << 4) + (2 % 16) }
      subject { bill1 }

      describe "class methods" do
        specify { expect(klass.bill_id_group_value_from(2)).to eq(2 % 16) }
        specify { expect(klass.unique_bill_id_from(431, 2)).to eq(unique_id) }
        specify { expect(klass.bill_id_from(unique_id)).to eq(431) }
        specify { expect(klass.bill_id_group_from(unique_id)).to eq(2 % 16) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == 2 }
        its(:unique_bill_id) { should == unique_id }
      end
    end

    context "bill2" do
      let(:unique_id) { (431 << 4) + (7 % 16) }
      subject { bill2 }

      describe "class methods" do
        specify { expect(klass.bill_id_group_value_from(7)).to eq(7 % 16) }
        specify { expect(klass.unique_bill_id_from(431, 7)).to eq(unique_id) }
        specify { expect(klass.bill_id_from(unique_id)).to eq(431) }
        specify { expect(klass.bill_id_group_from(unique_id)).to eq(7 % 16) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == 7 }
        its(:unique_bill_id) { should == unique_id }
      end
    end
  end

  context "tables" do
    let(:medical_klass) do
      Class.new(TablesBase) do
        unique_by(total: 2) { 10 }
      end
    end
    let(:utility_klass) do
      Class.new(TablesBase) do
        unique_by(total: 2) { 11 }
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
        specify { expect(medical_klass.bill_id_group_value_from(10)).to eq(10 % 2) }
        specify { expect(medical_klass.unique_bill_id_from(839, 10)).to eq(unique_id) }
        specify { expect(medical_klass.bill_id_from(unique_id)).to eq(839) }
        specify { expect(medical_klass.bill_id_group_from(unique_id)).to eq(10 % 2) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == 10 }
        its(:unique_bill_id) { should == unique_id }
      end
    end

    context "utility bill" do
      let(:klass) { utility_klass }
      let(:unique_id) { (839 << 1) + (11 % 2) }
      subject { utility_bill }

      describe "class methods" do
        specify { expect(utility_klass.bill_id_group_value_from(11)).to eq(11 % 2) }
        specify { expect(utility_klass.unique_bill_id_from(839, 11)).to eq(unique_id) }
        specify { expect(utility_klass.bill_id_from(unique_id)).to eq(839) }
        specify { expect(utility_klass.bill_id_group_from(unique_id)).to eq(11 % 2) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == 11 }
        its(:unique_bill_id) { should == unique_id }
      end
    end
  end

  context "sharded tables" do
    let(:medical_klass) do

      Class.new(ShardedTablesBase) do
        unique_by(:client_id, :x, total: [10, 200, 2, 20]) { [10, y] }
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
        unique_by(:client_id, :x, bits: [4, 8, 1, 5]) { [11, y] }
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

    context "with total" do
      let(:klass) { medical_klass }
      subject { medical_bill }

      let(:tempered_group) { [5 % 16, 53 % 256, 10 % 2, 20 % 32] }
      let(:group_value) { ((5 % 16) << 14) + ((53 % 256) << 6) + ((10 % 2) << 5) + (20 % 32) }
      let(:unique_id) { (9428 << 18) + group_value }

      describe "class methods" do
        specify { expect(medical_klass.bill_id_group_value_from([5, 53, 10, 20])).to eq(group_value) }
        specify { expect(medical_klass.unique_bill_id_from(9428, [5, 53, 10, 20])).to eq(unique_id) }
        specify { expect(medical_klass.bill_id_from(unique_id)).to eq(9428) }
        specify { expect(medical_klass.bill_id_group_from(unique_id)).to eq(tempered_group) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == [5, 53, 10, 20] }
        its(:unique_bill_id) { should == unique_id }
      end
    end

    context "with bits" do
      let(:klass) { utility_klass }
      subject { utility_bill }

      let(:tempered_group) { [8 % 16, 853 % 256, 11 % 2, 40 % 32] }
      let(:group_value) { ((8 % 16) << 14) + ((853 % 256) << 6) + ((11 % 2) << 5) + (40 % 32) }
      let(:unique_id) { (9428 << 18) + group_value }

      describe "class methods" do
        specify { expect(utility_klass.bill_id_group_value_from([8, 853, 11, 40])).to eq(group_value) }
        specify { expect(utility_klass.unique_bill_id_from(9428, [8, 853, 11, 40])).to eq(unique_id) }
        specify { expect(utility_klass.bill_id_from(unique_id)).to eq(9428) }
        specify { expect(utility_klass.bill_id_group_from(unique_id)).to eq(tempered_group) }

        include_context "finder methods"
      end

      describe "instance methods" do
        its(:bill_id_group) { should == [8, 853, 11, 40] }
        its(:unique_bill_id) { should == unique_id }
      end
    end
  end

  context "errors" do
    let(:klass) do
      Class.new do
        include BaseBill
      end
    end

    describe "#unique_by" do
      specify { expect { klass.unique_by(:x) }.to raise_error(ArgumentError, "must pass either total or bits to #unique_by") }
      specify { expect { klass.unique_by(:x, total: [5, 4], bits: [2, 7]) }.to raise_error(ArgumentError, "both total ([5, 4]) and bits ([2, 7]) passed to #unique_by") }
      specify { expect { klass.unique_by(total: 5) }.to raise_error(ArgumentError, "must pass a group generator block") }
      specify { expect { klass.unique_by(:x, :y, total: 5) }.to raise_error(ArgumentError, "amount of group names (2) doesn't match total/bits (1)") }
      specify { expect { klass.unique_by(:x, :y, total: [3, 2, 5]) }.to raise_error(ArgumentError, "amount of group names (2) doesn't match total/bits (3)") }
      specify { expect { klass.unique_by(:x, :y, total: [3, 2, 5]) { } }.not_to raise_error }
      specify { expect { klass.unique_by(:x, :y, :z, bits: [3, 2]) { } }.to raise_error(ArgumentError, "amount of group names (3) doesn't match total/bits (2)") }
    end

    describe "class methods" do
      pending
    end

    describe "instance methods" do
      pending
    end
  end
end