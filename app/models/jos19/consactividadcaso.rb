# frozen_string_literal: true

require "jos19/concerns/models/consactividadcaso"

module Jos19
  class Consactividadcaso < ActiveRecord::Base
    include Jos19::Concerns::Models::Consactividadcaso
  end
end
