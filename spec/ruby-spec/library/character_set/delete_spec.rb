require_relative '../../../spec_helper'
require 'set'

describe "CharacterSet#delete" do
  before :each do
    @set = CharacterSet["a", "b", "c"]
  end

  it "deletes the passed Object from self" do
    @set.delete("a")
    @set.should_not include("a")
  end

  it "returns self" do
    @set.delete("a").should equal(@set)
    @set.delete("x").should equal(@set)
  end
end

describe "CharacterSet#delete?" do
  before :each do
    @set = CharacterSet["a", "b", "c"]
  end

  it "deletes the passed Object from self" do
    @set.delete?("a")
    @set.should_not include("a")
  end

  it "returns self when the passed Object is in self" do
    @set.delete?("a").should equal(@set)
  end

  it "returns nil when the passed Object is not in self" do
    @set.delete?("x").should be_nil
  end
end