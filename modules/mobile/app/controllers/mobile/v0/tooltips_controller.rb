# frozen_string_literal: true

module Mobile
  module V0
    class TooltipsController < ApplicationController
      include Tooltips
      service_tag 'mobile-app'
    end
  end
end
