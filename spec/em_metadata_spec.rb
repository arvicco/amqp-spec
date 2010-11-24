require 'spec_helper'

describe AMQP::SpecHelper, " .metadata" do
  include AMQP::SpecHelper
  root_metadata = metadata

  it 'example metadata starts as a copy of example group metadata' do
    metadata.should == root_metadata
  end

  it 'can be changed, thus diverging from example group metadata' do
    metadata[:example_key] = :example_value
    metadata.should have_key :example_key
    metadata.should_not == root_metadata
  end

  it 'changing example metadata has no effect on subsequent examples' do
    metadata.should_not have_key :example_key
    metadata.should == root_metadata
  end

  context 'inside nested example group 1' do
    nested_metadata = metadata

    it 'nested group metadata CONTAINS root enclosing group metadata' do
      nested_metadata.should_not == root_metadata
      nested_metadata[:example_group][:example_group].should ==
          root_metadata[:example_group]
    end

    it 'except for :example_group key, nested and root group metadata is the same' do
      @root = root_metadata.dup
      @root.delete(:example_group)
      @nested = nested_metadata.dup
      @nested.delete(:example_group)
      @nested.should == @root
    end

    it 'example metadata starts as a copy of nested group metadata' do
      metadata.should == nested_metadata
    end

    it 'can be changed, thus diverging from example group metadata' do
      metadata[:example_key] = :example_value
      metadata.should have_key :example_key
      metadata.should_not == nested_metadata
    end

    it 'changing example metadata has no effect on subsequent examples' do
      metadata.should_not have_key :example_key
      metadata.should == nested_metadata
    end

    context 'inside deeply nested example group 1' do
      deeply_nested_metadata = metadata

      it 'deeply_nested group metadata CONTAINS enclosing group metadata' do
        deeply_nested_metadata.should_not == root_metadata
        deeply_nested_metadata[:example_group][:example_group].should ==
            nested_metadata[:example_group]
      end

      it 'except for :example_group key, deeply_nested and root group metadata is the same' do
        @root = root_metadata.dup
        @root.delete(:example_group)
        @nested = nested_metadata.dup
        @nested.delete(:example_group)
        @deeply_nested = deeply_nested_metadata.dup
        @deeply_nested.delete(:example_group)
        @deeply_nested.should == @nested
        @deeply_nested.should == @root
      end

      it 'example metadata starts as a copy of deeply_nested group metadata' do
        metadata.should == deeply_nested_metadata
      end

      it 'can be changed, thus diverging from example group metadata' do
        metadata[:example_key] = :example_value
        metadata.should have_key :example_key
        metadata.should_not == deeply_nested_metadata
      end

      it 'changing example metadata has no effect on subsequent examples' do
        metadata.should_not have_key :example_key
        metadata.should == deeply_nested_metadata
      end
    end # inside deeply nested example group 1
  end # inside nested example group 1

  context 'inside nested example group 2' do
    metadata[:nested_key] = :nested_value
    nested_metadata = metadata

    it 'nested group metadata CONTAINS root enclosing group metadata' do
      nested_metadata.should_not == root_metadata
      nested_metadata[:example_group][:example_group].should ==
          root_metadata[:example_group]
    end

    it "except for :example_group and modified keys," +
           "nested and root group metadata is the same" do
      @root = root_metadata.dup
      @root.delete(:example_group)
      @nested = nested_metadata.dup
      @nested.delete(:example_group)
      @nested.delete(:nested_key)
      @nested.should == @root
    end

    it 'example metadata starts as a copy of nested group metadata' do
      metadata.should == nested_metadata
    end

    it 'can be changed, thus diverging from example group metadata' do
      metadata[:example_key] = :example_value
      metadata.should have_key :example_key
      metadata.should_not == nested_metadata
    end

    it 'changing example metadata has no effect on subsequent examples' do
      metadata.should_not have_key :example_key
      metadata.should == nested_metadata
    end

    context 'inside deeply nested example group 2' do
      metadata[:deeply_nested_key] = :deeply_nested_value
      deeply_nested_metadata = metadata

      it 'deeply_nested group metadata CONTAINS enclosing group metadata' do
        deeply_nested_metadata[:example_group][:example_group].should ==
            nested_metadata[:example_group]
      end

      it "except for :example_group and modified keys," +
             "deeply nested and root group metadata is the same" do
        @root = root_metadata.dup
        @root.delete(:example_group)
        @nested = nested_metadata.dup
        @nested.delete(:example_group)
        @deeply_nested = deeply_nested_metadata.dup
        @deeply_nested.delete(:example_group)
        @deeply_nested.delete(:deeply_nested_key)
        @deeply_nested.should == @nested
        @deeply_nested.delete(:nested_key)
        @deeply_nested.should == @root
      end

      it 'example metadata starts as a copy of deeply_nested group metadata' do
        metadata.should == deeply_nested_metadata
      end

      it 'can be changed, thus diverging from example group metadata' do
        metadata[:example_key] = :example_value
        metadata.should have_key :example_key
        metadata.should_not == deeply_nested_metadata
      end

      it 'changing example metadata has no effect on subsequent examples' do
        metadata.should_not have_key :example_key
        metadata.should == deeply_nested_metadata
      end
    end # inside deeply nested example group 2
  end # inside nested example group 2
end # describe AMQP, "metadata"
