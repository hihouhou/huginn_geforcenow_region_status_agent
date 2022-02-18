require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::GeforcenowRegionStatusAgent do
  before(:each) do
    @valid_options = Agents::GeforcenowRegionStatusAgent.new.default_options
    @checker = Agents::GeforcenowRegionStatusAgent.new(:name => "GeforcenowRegionStatusAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
