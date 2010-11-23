require 'spec_helper'

describe AMQP::SpecHelper, " .default_options" do
  include AMQP::SpecHelper
  root_default_options = {:one => 1}
  default_options root_default_options

  it 'example has access to default options through self.class.default_options' do
    self.class.default_options.should == root_default_options
  end

  context 'inside nested example group 1' do
    it 'defaults start as a copy of enclosing example group default_options' do
      self.class.default_options.should == root_default_options
    end

    it 'can be changed, thus diverging from example group default_options' do
      self.class.default_options[:example_key] = :example_value
      self.class.default_options.should have_key :example_key
      self.class.default_options.should_not == root_default_options
    end

    it 'changing example default_options has no effect on subsequent examples' do
      self.class.default_options.should == root_default_options
    end

    context 'inside deeply nested example group 1' do
      it 'example default_options starts as a copy of enclosing example group default_options' do
        default_options.should == root_default_options
      end

      it 'can be changed, thus diverging from example group default_options' do
        self.class.default_options[:example_key] = :example_value
        self.class.default_options.should have_key :example_key
        self.class.default_options.should_not == root_default_options
      end

      it 'changing example default_options has no effect on subsequent examples' do
        self.class.default_options.should_not have_key :example_key
        self.class.default_options.should == root_default_options
      end
    end
  end # inside nested example group 1

  context 'inside nested example group 2' do
    default_options[:nested_key] = :nested_value
    nested_default_options = default_options

    it 'changing default_options in nested group affects example group default_options' do
      default_options.should == nested_default_options
      default_options.should_not == root_default_options
    end

    it 'can be changed, thus diverging from example group default_options' do
      default_options[:example_key] = :example_value
      default_options.should have_key :example_key
      default_options.should_not == nested_default_options
      default_options.should_not == root_default_options
    end

    it 'changing example default_options has no effect on subsequent examples' do
      default_options.should == nested_default_options
    end

    context 'inside deeply nested example group 2' do
      default_options[:deeply_nested_key] = :deeply_nested_value
      deeply_nested_default_options = default_options

      it 'changing default_options in nested group affects example group default_options' do
        default_options.should == deeply_nested_default_options
        default_options.should_not == nested_default_options
        default_options.should_not == root_default_options
        default_options.should have_key :deeply_nested_key
      end

      it 'can be changed, thus diverging from example group default_options' do
        default_options[:example_key] = :example_value
        default_options.should have_key :example_key
        default_options.should_not == nested_default_options
        default_options.should_not == root_default_options
      end

      it 'changing example default_options has no effect on subsequent examples' do
        default_options.should == deeply_nested_default_options
      end
    end
  end # inside nested example group 2

end # describe AMQP, "default_options"
