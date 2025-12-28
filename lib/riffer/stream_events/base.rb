# frozen_string_literal: true

class Riffer::StreamEvents::Base
  attr_reader :role

  def initialize(role: "assistant")
    @role = role
  end

  def to_h
    raise NotImplementedError, "Subclasses must implement #to_h"
  end
end
