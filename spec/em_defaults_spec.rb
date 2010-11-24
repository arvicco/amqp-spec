require 'spec_helper'

describe AMQP::SpecHelper, " .default_options" do
  include AMQP::SpecHelper
  root_default_options = {:root_key => 1}
  default_options root_default_options

  it 'subsequent and nested groups should not change root default options' do
    root_default_options.should == {:root_key => 1}
  end

  it 'example has access to default options' do
    default_options.should == root_default_options
  end

  it 'defaults can be changed inside example, diverging from example group defaults' do
    default_options[:example_key] = :example_value
    default_options.should have_key :example_key
    default_options.should_not == root_default_options
  end

  it 'changing example defaults has no effect on subsequent examples' do
    default_options.should_not have_key :example_key
    default_options.should == root_default_options
  end

  context 'inside nested example group 1' do
    nested_default_options = default_options

    it 'nested group defaults start as a copy of enclosing group default_options' do
      nested_default_options.should == root_default_options
    end

    it 'example has access to default options' do
      default_options.should == nested_default_options
    end

    it 'can be changed, thus diverging from example group default_options' do
      default_options[:example_key] = :example_value
      default_options.should have_key :example_key
      default_options.should_not == root_default_options
    end

    it 'changing example default_options has no effect on subsequent examples' do
      default_options.should_not have_key :example_key
      default_options.should == root_default_options
    end

    context 'inside deeply nested example group 1' do
      nested_default_options = default_options

      it 'nested group defaults start as a copy of enclosing group default_options' do
        nested_default_options.should == root_default_options
      end

      it 'example has access to default options' do
        default_options.should == nested_default_options
      end

      it 'can be changed in example, thus diverging from example group default_options' do
        default_options[:example_key] = :example_value
        default_options.should have_key :example_key
        default_options.should_not == nested_default_options
      end

      it 'changing example default_options has no effect on subsequent examples' do
        default_options.should_not have_key :example_key
        default_options.should == nested_default_options
      end
    end # inside deeply nested example group 1
  end # inside nested example group 1

  context 'inside nested example group 2' do
    default_options[:nested_key] = :nested_value
    nested_default_options = default_options

    it 'changing default options inside nested group works' do
      nested_default_options.should have_key :nested_key
    end

    it 'changing default_options in nested group affects example default_options' do
      default_options.should == nested_default_options
      default_options.should_not == root_default_options
    end

    it 'can be changed in example, thus diverging from example group default_options' do
      default_options[:example_key] = :example_value
      default_options.should have_key :example_key
      default_options.should have_key :nested_key
      default_options.should_not == nested_default_options
      default_options.should_not == root_default_options
    end

    it 'changing example default_options has no effect on subsequent examples' do
      default_options.should == nested_default_options
    end

    context 'inside deeply nested example group 2' do
      default_options[:deeply_nested_key] = :deeply_nested_value
      deeply_nested_default_options = default_options

      it 'inherits default options from enclosing group' do
        deeply_nested_default_options.should have_key :nested_key
      end

      it 'changing default options inside deeply nested group works' do
        deeply_nested_default_options.should have_key :deeply_nested_key
      end

      it 'changing default_options in nested group affects example group default_options' do
        default_options.should == deeply_nested_default_options
        default_options.should have_key :nested_key
        default_options.should have_key :deeply_nested_key
        default_options.should_not == nested_default_options
        default_options.should_not == root_default_options
      end

      it 'can be changed in example, thus diverging from example group default_options' do
        default_options[:example_key] = :example_value
        default_options.should have_key :example_key
        default_options.should have_key :nested_key
        default_options.should have_key :deeply_nested_key
        default_options.should_not == nested_default_options
        default_options.should_not == root_default_options
      end

      it 'changing example default_options has no effect on subsequent examples' do
        default_options.should == deeply_nested_default_options
      end
    end # inside deeply nested example group 2
  end # inside nested example group 2
end # describe AMQP, "default_options"
