# frozen_string_literal: true

module MyHealth
  module V1
    class TooltipsController < ApplicationController
      include Tooltips
      service_tag 'mhv-medications'
    end
  end
end
